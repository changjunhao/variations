package model

import (
	"strings"
	"testing"

	"variations-serve-go/internal/config"
)

func testCfg() *config.Config {
	return &config.Config{
		Oss: config.OssConfig{Region: "cn-hangzhou", Bucket: "my-bucket"},
	}
}

func TestAssertBucketURL(t *testing.T) {
	cfg := testCfg()
	ok := "https://my-bucket.oss-cn-hangzhou.aliyuncs.com/uploads/abc.jpg?x=1"
	if err := AssertBucketURL(cfg, ok); err != nil {
		t.Fatalf("合法 URL 被拒: %v", err)
	}
	cases := map[string]string{
		"非 https": "http://my-bucket.oss-cn-hangzhou.aliyuncs.com/a.jpg",
		"其他域名":    "https://evil.com/a.jpg",
		"非合法 URL": "not a url",
		"子域名绕过":   "https://my-bucket.oss-cn-hangzhou.aliyuncs.com.evil.com/a.jpg",
	}
	for name, u := range cases {
		if err := AssertBucketURL(cfg, u); err == nil {
			t.Fatalf("%s: 期望拒绝 %q", name, u)
		}
	}
	// OSS 未配置 → ValidationError
	if err := AssertBucketURL(&config.Config{}, ok); err == nil {
		t.Fatal("OSS 未配置应报错")
	}
}

// rune 计长：emoji 为 1 个码点
func TestAssertPromptRuneLength(t *testing.T) {
	emoji := strings.Repeat("😀", MaxPromptRunes) // 16000 个码点，UTF-16 下是 32000
	if err := AssertPrompt(emoji); err != nil {
		t.Fatalf("16000 码点应放行: %v", err)
	}
	if err := AssertPrompt(emoji + "x"); err == nil {
		t.Fatal("16001 码点应拒绝")
	}
	if err := AssertInstruction(strings.Repeat("字", MaxInstructionRunes)); err != nil {
		t.Fatalf("2000 码点应放行: %v", err)
	}
	if err := AssertInstruction(strings.Repeat("字", MaxInstructionRunes+1)); err == nil {
		t.Fatal("2001 码点应拒绝")
	}
}

func TestValidateInlineSkill(t *testing.T) {
	if err := ValidateInlineSkill("正文", nil); err != nil {
		t.Fatalf("合法 body 被拒: %v", err)
	}
	if err := ValidateInlineSkill("  ", nil); err == nil {
		t.Fatal("空白 body 应拒绝")
	}
	if err := ValidateInlineSkill(strings.Repeat("a", MaxInlineBodyBytes+1), nil); err == nil {
		t.Fatal("超 100KB body 应拒绝")
	}
	if err := ValidateInlineSkill("b", map[string]string{"a.png": "x"}); err == nil {
		t.Fatal("非文本扩展名应拒绝")
	}
	if err := ValidateInlineSkill("b", map[string]string{"a.md": strings.Repeat("x", MaxInlineFilesBytes+1)}); err == nil {
		t.Fatal("files 超 200KB 应拒绝")
	}
	if err := ValidateInlineSkill("b", map[string]string{"ref/a.MD": "x"}); err != nil {
		t.Fatalf("大写扩展名应放行: %v", err)
	}
}
