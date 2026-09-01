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
	"time"

	"variations-serve-go/internal/config"
	"variations-serve-go/internal/upstream"
)

// GenerateImageInput 生图入参
type GenerateImageInput struct {
	Prompt string
	// ImageURLs 参考图（本 bucket 签名 URL），0-3 张；不传则纯文生图
	ImageURLs []string
	// Size 输出分辨率 "宽*高"（客户端契约，星号分隔）；空串 = 不传，由模型默认画幅
	Size           string
	Seed           *int
	NegativePrompt string
}

// GenerateImage 生成图片，返回 URL 列表（客户端需及时下载）；provider 由调用方解析。
// qwen：DashScope multimodal-generation，size 像素串原样透传；
// ark：seedream OpenAI 兼容 /images/generations，size 经 ToArkSize 钳制。
func GenerateImage(ctx context.Context, cfg *config.Config, input GenerateImageInput, provider config.ModelProvider, logger *slog.Logger) ([]string, error) {
	if provider == config.ProviderArk {
		return generateWithArk(ctx, cfg, input, logger)
	}
	return generateWithQwen(ctx, cfg, input, logger)
}

// ============================== qwen（qwen-image） ==============================

type qwenGenerationResponse struct {
	Code    *string `json:"code"`
	Message *string `json:"message"`
	Output  *struct {
		Choices []struct {
			Message *struct {
				Content []struct {
					Image *string `json:"image"`
				} `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	} `json:"output"`
}

func generateWithQwen(ctx context.Context, cfg *config.Config, input GenerateImageInput, logger *slog.Logger) ([]string, error) {
	if cfg.DashscopeAPIKey == "" {
		return nil, newDashScopeError("缺少环境变量 DASHSCOPE_API_KEY")
	}

	// content：image 项在前、text 在后，均为单键对象
	content := make([]map[string]string, 0, len(input.ImageURLs)+1)
	for _, u := range input.ImageURLs {
		content = append(content, map[string]string{"image": u})
	}
	content = append(content, map[string]string{"text": input.Prompt})

	parameters := map[string]any{"prompt_extend": false} // skill 编译出的提示词已很详细，不再改写
	if input.Size != "" {
		parameters["size"] = input.Size
	}
	if input.NegativePrompt != "" {
		parameters["negative_prompt"] = input.NegativePrompt
	}
	if input.Seed != nil {
		parameters["seed"] = *input.Seed
	}
	payload := map[string]any{
		"model": cfg.QwenImageModel,
		"input": map[string]any{
			"messages": []map[string]any{
				{"role": "user", "content": content},
			},
		},
		"parameters": parameters,
	}

	raw, status, err := doUpstream(ctx, cfg.RequestTimeout,
		cfg.DashscopeBaseURL+"/api/v1/services/aigc/multimodal-generation/generation",
		cfg.DashscopeAPIKey, payload)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			return nil, newDashScopeError("生图超时（>" + fmt.Sprint(int(cfg.RequestTimeout.Seconds())) + "s）")
		}
		return nil, newDashScopeError("qwen-image 调用失败: " + err.Error())
	}
	var data qwenGenerationResponse
	_ = json.Unmarshal(raw, &data)
	if status < 200 || status >= 300 || data.Code != nil {
		code, msg := fmt.Sprint(status), ""
		if data.Code != nil {
			code = *data.Code
		}
		if data.Message != nil {
			msg = *data.Message
		}
		return nil, newDashScopeError(fmt.Sprintf("qwen-image 调用失败: %s - %s", code, msg))
	}
	var urls []string
	if data.Output != nil {
		for _, choice := range data.Output.Choices {
			if choice.Message == nil {
				continue
			}
			for _, item := range choice.Message.Content {
				if item.Image != nil && *item.Image != "" {
					urls = append(urls, *item.Image)
				}
			}
		}
	}
	if len(urls) == 0 {
		return nil, newDashScopeError("qwen-image 未返回生成的图片")
	}
	logger.Info("image generated", "provider", "qwen", "model", cfg.QwenImageModel,
		"refs", len(input.ImageURLs), "size", sizeOrAuto(input.Size), "count", len(urls))
	return urls, nil
}

// ============================== ark（seedream） ==============================

type arkGenerationResponse struct {
	Data []struct {
		URL *string `json:"url"`
	} `json:"data"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error"`
}

func generateWithArk(ctx context.Context, cfg *config.Config, input GenerateImageInput, logger *slog.Logger) ([]string, error) {
	if cfg.ArkAPIKey == "" {
		return nil, newArkError("缺少环境变量 ARK_API_KEY")
	}
	// seedream 无 seed / negative_prompt 参数：入参契约保留接收，但不转发上游
	if input.NegativePrompt != "" {
		logger.Debug("negativePrompt 不被 seedream 支持，已忽略")
	}

	payload := map[string]any{
		"model":           cfg.ArkImageModel,
		"prompt":          input.Prompt,
		"response_format": "url",
		"watermark":       false, // 默认 true 会加「AI 生成」水印，显式关闭
	}
	// image 字段官方规格为 string | string[]：单张传字符串、多张传数组
	if len(input.ImageURLs) == 1 {
		payload["image"] = input.ImageURLs[0]
	} else if len(input.ImageURLs) > 1 {
		payload["image"] = input.ImageURLs
	}
	if arkSize := ToArkSize(input.Size); arkSize != "" {
		payload["size"] = arkSize
	}

	raw, status, err := doUpstream(ctx, cfg.RequestTimeout,
		cfg.ArkBaseURL+"/images/generations", cfg.ArkAPIKey, payload)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			return nil, newArkError("生图超时（>" + fmt.Sprint(int(cfg.RequestTimeout.Seconds())) + "s）")
		}
		return nil, newArkError("seedream 调用失败: " + err.Error())
	}
	var data arkGenerationResponse
	_ = json.Unmarshal(raw, &data)
	if status < 200 || status >= 300 || data.Error != nil {
		msg := fmt.Sprintf("%d", status)
		if data.Error != nil && data.Error.Message != "" {
			msg = data.Error.Message
		}
		return nil, newArkError("seedream 调用失败: " + msg)
	}
	var urls []string
	for _, item := range data.Data {
		if item.URL != nil && *item.URL != "" {
			urls = append(urls, *item.URL)
		}
	}
	if len(urls) == 0 {
		return nil, newArkError("seedream 未返回生成的图片")
	}
	logger.Info("image generated", "provider", "ark", "model", cfg.ArkImageModel,
		"refs", len(input.ImageURLs), "count", len(urls))
	return urls, nil
}

// ============================== 共用 ==============================

func doUpstream(ctx context.Context, requestTimeout time.Duration, endpoint, apiKey string, payload any) ([]byte, int, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, 0, err
	}
	callCtx, cancel := context.WithTimeout(ctx, upstream.CallTimeout(requestTimeout))
	defer cancel()
	req, err := http.NewRequestWithContext(callCtx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)
	res, err := upstream.Client().Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer res.Body.Close()
	raw, _ := io.ReadAll(res.Body)
	return raw, res.StatusCode, nil
}

func sizeOrAuto(size string) string {
	if size == "" {
		return "auto"
	}
	return size
}
