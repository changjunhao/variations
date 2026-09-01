package skill

import (
	"encoding/json"
	"log/slog"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// InstructionField 附加指令模板字段：options 为枚举值域（客户端单选胶囊），placeholder 为自由文本提示
type InstructionField struct {
	Label       string   `json:"label"`
	Options     []string `json:"options,omitempty"`
	Placeholder string   `json:"placeholder,omitempty"`
}

// UiMeta 风格卡片 UI 元数据（指针字段：缺失序列化为显式 null）
type UiMeta struct {
	DisplayName         *string            `json:"displayName"`
	ShortDescription    *string            `json:"shortDescription"`
	DefaultPrompt       *string            `json:"defaultPrompt"`
	Size                *string            `json:"size"`
	InstructionTemplate []InstructionField `json:"instructionTemplate"`
}

// ResolvedUi resolveUi 的返回值
type ResolvedUi struct {
	UI *UiMeta
	// skills-ui.json manual 中的 sampleImageUrl 覆盖，无则 nil
	SampleOverride *string
}

type uiManual struct {
	UiMeta
	SampleImageUrl *string `json:"sampleImageUrl"`
}

type uiEntry struct {
	Manual    *uiManual `json:"manual"`
	Generated *UiMeta   `json:"generated"`
}

// LoadUiStore 解析 skills-ui.json；文件缺失/解析失败按空处理（fail-safe）
func LoadUiStore(path string, logger *slog.Logger) map[string]uiEntry {
	store := make(map[string]uiEntry)
	if path == "" {
		return store
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return store
	}
	if err := json.Unmarshal(raw, &store); err != nil {
		if logger != nil {
			logger.Warn("skills-ui.json 解析失败，按空处理", "error", err.Error())
		}
		return make(map[string]uiEntry)
	}
	return store
}

// agentInterface agents/openai.yaml 的界面元数据（yaml.v3 正规解析，UI 元数据最后兜底）
type agentInterface struct {
	Interface struct {
		DisplayName      string `yaml:"display_name"`
		ShortDescription string `yaml:"short_description"`
		DefaultPrompt    string `yaml:"default_prompt"`
	} `yaml:"interface"`
}

func loadAgentInterface(skillsDir, dirName string) *UiMeta {
	if skillsDir == "" {
		return nil
	}
	raw, err := os.ReadFile(filepath.Join(skillsDir, dirName, "agents", "openai.yaml"))
	if err != nil {
		return nil
	}
	var ai agentInterface
	if err := yaml.Unmarshal(raw, &ai); err != nil {
		return nil
	}
	ui := &UiMeta{}
	if ai.Interface.DisplayName != "" {
		v := ai.Interface.DisplayName
		ui.DisplayName = &v
	}
	if ai.Interface.ShortDescription != "" {
		v := ai.Interface.ShortDescription
		ui.ShortDescription = &v
	}
	if ai.Interface.DefaultPrompt != "" {
		v := ai.Interface.DefaultPrompt
		ui.DefaultPrompt = &v
	}
	return ui
}

// ResolveUi 优先级：skills-ui.json manual > generated > agents/openai.yaml
func ResolveUi(skillsDir string, uiStore map[string]uiEntry, dirName string) ResolvedUi {
	entry := uiStore[dirName]
	switch {
	case entry.Manual != nil:
		ui := entry.Manual.UiMeta
		return ResolvedUi{UI: &ui, SampleOverride: entry.Manual.SampleImageUrl}
	case entry.Generated != nil:
		return ResolvedUi{UI: entry.Generated}
	default:
		return ResolvedUi{UI: loadAgentInterface(skillsDir, dirName)}
	}
}
