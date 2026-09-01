package model

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"sort"
	"strings"
	"time"

	"variations-serve-go/internal/config"
	"variations-serve-go/internal/upstream"
)

const (
	markStart = "<FINAL_PROMPT>"
	markEnd   = "</FINAL_PROMPT>"
	// 辅助文件注入上限（字符数），超出部分跳过并告警，避免撑爆上下文
	maxAuxChars = 120_000
)

// CompileInput 编译入参：skill 正文 + 辅助文件（官方模版与 inlineSkill 共用）
type CompileInput struct {
	Body        string
	Files       map[string]string
	ImageURL    string
	Instruction string
}

// compileSystemInstruction 系统指令（skill 说明书 + 辅助文件注入 + 输出约束）
func compileSystemInstruction(input CompileInput, logger *slog.Logger) string {
	var b strings.Builder
	b.WriteString("你是一个图像生成提示词编译器。下面是一份 skill 说明书，定义了完整的创作流程：\n\n")
	b.WriteString(input.Body)

	// 注入辅助文件（按键序确定性注入），预算上限 maxAuxChars
	budget := maxAuxChars
	for _, rel := range sortedKeys(input.Files) {
		content := input.Files[rel]
		if len(content) > budget {
			logger.Warn(fmt.Sprintf("skill 辅助文件过大已跳过: %s (%d 字符)", rel, len(content)))
			continue
		}
		budget -= len(content)
		b.WriteString("\n\n=== skill 辅助文件: ")
		b.WriteString(rel)
		b.WriteString(" ===\n")
		b.WriteString(content)
	}

	b.WriteString("\n\n请严格按该 skill 的流程处理用户提供的照片（构建分析卡片、做出构图/色彩/边缘/文字等决策），\n")
	b.WriteString("编译出最终用于图像生成模型的提示词。要求：\n")
	b.WriteString("- 只输出最终提示词本体，用 " + markStart + " 与 " + markEnd + " 两个标记包裹；\n")
	b.WriteString("- 提示词中不要包含设计理论解释、分析过程、文件路径或元数据；\n")
	b.WriteString("- 不要输出创作思路、标注声明等任何其他内容；\n")
	b.WriteString("- 用户的附加指令可能以「【标签】：内容」的格式逐行给出；标签是控制维度的名称，仅用于理解意图，不要把标签名本身（含【】符号）写进提示词；\n")
	b.WriteString("- 提示词控制在 4500 token 以内。")
	return b.String()
}

func sortedKeys(m map[string]string) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

// extractFinalPrompt 提取 FINAL_PROMPT 标记包裹的内容；无标记时取全文
func extractFinalPrompt(text string) string {
	s := strings.Index(text, markStart)
	e := strings.Index(text, markEnd)
	if s >= 0 && e > s {
		return strings.TrimSpace(text[s+len(markStart) : e])
	}
	return strings.TrimSpace(text)
}

// responsesResponse 双供应商共用：优先顶层 output_text，缺失时遍历 output 中 message 项兜底；
// 百炼错误响应为扁平 { code, message } 结构（无 error 字段）
type responsesResponse struct {
	OutputText *string `json:"output_text"`
	Output     []struct {
		Type    string `json:"type"`
		Content []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
	} `json:"output"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error"`
	Code    *string `json:"code"`
	Message *string `json:"message"`
}

func extractOutputText(data *responsesResponse) string {
	if data.OutputText != nil && *data.OutputText != "" {
		return *data.OutputText
	}
	var b strings.Builder
	for _, item := range data.Output {
		if item.Type != "message" {
			continue
		}
		for _, part := range item.Content {
			if part.Type == "output_text" {
				b.WriteString(part.Text)
			}
		}
	}
	return b.String()
}

// Compile VL 编译：双供应商统一走 OpenAI 兼容 Responses API（provider 由调用方解析）。
// 图片传 OSS 签名 URL（input_image.image_url），系统指令放 instructions。
func Compile(ctx context.Context, cfg *config.Config, input CompileInput, provider config.ModelProvider, logger *slog.Logger) (string, error) {
	var endpoint, apiKey, model string
	var fail func(string) error
	switch provider {
	case config.ProviderArk:
		if cfg.ArkAPIKey == "" {
			return "", newArkError("缺少环境变量 ARK_API_KEY")
		}
		endpoint = cfg.ArkBaseURL + "/responses"
		apiKey, model = cfg.ArkAPIKey, cfg.ArkVLModel
		fail = newArkError
	default:
		if cfg.DashscopeAPIKey == "" {
			return "", newDashScopeError("缺少环境变量 DASHSCOPE_API_KEY")
		}
		endpoint = cfg.DashscopeBaseURL + "/compatible-mode/v1/responses"
		apiKey, model = cfg.DashscopeAPIKey, cfg.QwenVLModel
		fail = newDashScopeError
	}

	instruction := input.Instruction
	if instruction == "" {
		instruction = "请按照 skill 的默认流程处理这张照片，编译最终生图提示词。"
	}
	payload := map[string]any{
		"model":        model,
		"instructions": compileSystemInstruction(input, logger),
		"input": []map[string]any{
			{
				"role": "user",
				"content": []map[string]string{
					{"type": "input_image", "image_url": input.ImageURL},
					{"type": "input_text", "text": instruction},
				},
			},
		},
	}
	// 关闭思考模式：百炼 Responses API 以 reasoning.effort=none 直接出答（编译场景无需推理链，省时省 token）；
	// ark 的 doubao seed 系列本身无思考模式，不下发该参数
	if provider != config.ProviderArk {
		payload["reasoning"] = map[string]any{"effort": "none"}
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return "", fail("VL 编译请求构建失败: " + err.Error())
	}

	callCtx, cancel := context.WithTimeout(ctx, upstream.CallTimeout(cfg.RequestTimeout))
	defer cancel()
	req, err := http.NewRequestWithContext(callCtx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return "", fail("VL 编译请求构建失败: " + err.Error())
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)

	start := time.Now()
	res, err := upstream.Client().Do(req)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			return "", fail(fmt.Sprintf("VL 编译超时（>%ds）", int(cfg.RequestTimeout.Seconds())))
		}
		return "", fail("VL 编译调用失败: " + err.Error())
	}
	defer res.Body.Close()
	raw, _ := io.ReadAll(res.Body)

	var data responsesResponse
	_ = json.Unmarshal(raw, &data)
	if res.StatusCode < 200 || res.StatusCode >= 300 || data.Error != nil {
		msg := fmt.Sprintf("%d %s", res.StatusCode, res.Status)
		if data.Error != nil && data.Error.Message != "" {
			msg = data.Error.Message
		} else if data.Message != nil && *data.Message != "" {
			msg = *data.Message
		}
		return "", fail("VL 编译调用失败: " + msg)
	}
	prompt := extractFinalPrompt(extractOutputText(&data))
	if prompt == "" {
		return "", fail("VL 模型未返回可用的生图提示词")
	}
	logger.Info("prompt compiled",
		"provider", string(provider), "model", model,
		"ms", time.Since(start).Milliseconds(), "promptChars", len(prompt))
	return prompt, nil
}
