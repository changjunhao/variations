package model

import (
	"net/url"
	"strings"
	"unicode/utf8"

	"variations-serve-go/internal/config"
)

// 校验上限（Go 惯例：字符串长度按 rune/Unicode 码点计；字节上限用 len）
const (
	MaxInstructionRunes = 2000
	MaxPromptRunes      = 16000
	MaxInlineBodyBytes  = 100 * 1024
	MaxInlineFilesBytes = 200 * 1024
)

// inlineSkill.files 仅允许文本类型（与 skill 辅助文件注入口径一致）
var inlineTextExts = map[string]bool{".md": true, ".txt": true, ".csv": true}

// AssertBucketURL imageUrl 必须是本 bucket 域名下的签名 URL（防开放代理，compile/image 共用）
func AssertBucketURL(cfg *config.Config, rawURL string) error {
	bucket, region := cfg.Oss.Bucket, cfg.Oss.Region
	if bucket == "" || region == "" {
		return newValidationError("OSS 未配置，无法校验图片 URL")
	}
	parsed, err := url.Parse(rawURL)
	if err != nil || parsed.Scheme == "" || parsed.Host == "" {
		return newValidationError("imageUrl 不是合法 URL")
	}
	if parsed.Scheme != "https" {
		return newValidationError("imageUrl 必须为 HTTPS")
	}
	host := bucket + ".oss-" + region + ".aliyuncs.com"
	if parsed.Hostname() != host {
		return newValidationError("imageUrl 必须位于本 bucket 域名下（" + host + "）")
	}
	return nil
}

// AssertInstruction 附加指令长度校验（rune 口径）
func AssertInstruction(instruction string) error {
	if utf8.RuneCountInString(instruction) > MaxInstructionRunes {
		return newValidationError("instruction 超过 2000 字符限制")
	}
	return nil
}

// AssertPrompt 生图提示词长度校验（rune 口径）
func AssertPrompt(prompt string) error {
	if utf8.RuneCountInString(prompt) > MaxPromptRunes {
		return newValidationError("prompt 超过 16000 字符限制")
	}
	return nil
}

// ValidateInlineSkill 校验用户自建模版：body 非空且 ≤100KB 字节；files 仅文本类型且总量 ≤200KB 字节
func ValidateInlineSkill(body string, files map[string]string) error {
	if strings.TrimSpace(body) == "" {
		return newValidationError("inlineSkill.body 必填且必须是非空文本")
	}
	if len(body) > MaxInlineBodyBytes {
		return newValidationError("inlineSkill.body 超过 100KB 限制")
	}
	total := 0
	for rel, content := range files {
		dot := strings.LastIndex(rel, ".")
		ext := ""
		if dot >= 0 {
			ext = strings.ToLower(rel[dot:])
		}
		if !inlineTextExts[ext] {
			return newValidationError("inlineSkill.files[" + rel + "] 仅支持文本类型（.md/.txt/.csv）")
		}
		total += len(content)
		if total > MaxInlineFilesBytes {
			return newValidationError("inlineSkill.files 总量超过 200KB 限制")
		}
	}
	return nil
}
