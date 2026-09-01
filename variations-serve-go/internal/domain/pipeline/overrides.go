// Package pipeline 按 skill 的管线混搭注册表（assets/pipeline-overrides.json，server-only 运营配置）。
// 声明某个官方模版的编译/生图供应商覆盖；未声明字段或未收录 skill 回退管线默认。
// 文件缺失/解析失败 → 空注册表（fail-safe）；单条非法 → 告警并跳过该条。
package pipeline

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"os"

	"variations-serve-go/internal/config"
)

// Override 单个 skill 的供应商覆盖（零值 = 未声明，回退管线默认）
type Override struct {
	Compile config.ModelProvider
	Image   config.ModelProvider
}

type rawEntry struct {
	Compile *string `json:"compile"`
	Image   *string `json:"image"`
}

func parseProvider(v *string) config.ModelProvider {
	if v == nil {
		return ""
	}
	if *v == string(config.ProviderQwen) || *v == string(config.ProviderArk) {
		return config.ModelProvider(*v)
	}
	return ""
}

// LoadFile 解析注册表（每次快照重建时调用；文件极小，支持运营热更新）
func LoadFile(path string, logger *slog.Logger) map[string]Override {
	result := make(map[string]Override)
	if path == "" {
		return result
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return result
	}
	var entries map[string]rawEntry
	if err := json.Unmarshal(raw, &entries); err != nil {
		if logger != nil {
			logger.Warn("pipeline-overrides.json 解析失败，按空注册表处理", "error", err.Error())
		}
		return make(map[string]Override)
	}
	for skillID, entry := range entries {
		var o Override
		if entry.Compile != nil {
			o.Compile = parseProvider(entry.Compile)
			if o.Compile == "" && logger != nil {
				logger.Warn(fmt.Sprintf("pipeline-overrides.json「%s」compile 取值非法已忽略: %s", skillID, *entry.Compile))
			}
		}
		if entry.Image != nil {
			o.Image = parseProvider(entry.Image)
			if o.Image == "" && logger != nil {
				logger.Warn(fmt.Sprintf("pipeline-overrides.json「%s」image 取值非法已忽略: %s", skillID, *entry.Image))
			}
		}
		if o.Compile != "" || o.Image != "" {
			result[skillID] = o
		}
	}
	return result
}

// Resolve 解析 skill 的管线供应商：注册表覆盖 > 全局默认；skillId 为空（inlineSkill/直接输入）走全局默认
func Resolve(overrides map[string]Override, defaultProvider config.ModelProvider, skillID string) (compile, image config.ModelProvider) {
	compile, image = defaultProvider, defaultProvider
	if skillID == "" {
		return
	}
	if o, ok := overrides[skillID]; ok {
		if o.Compile != "" {
			compile = o.Compile
		}
		if o.Image != "" {
			image = o.Image
		}
	}
	return
}

// ReferencedProviders 注册表引用到的供应商集合（启动期 key 缺失预检用）
func ReferencedProviders(overrides map[string]Override) map[config.ModelProvider]bool {
	set := make(map[config.ModelProvider]bool)
	for _, o := range overrides {
		if o.Compile != "" {
			set[o.Compile] = true
		}
		if o.Image != "" {
			set[o.Image] = true
		}
	}
	return set
}
