package handlers

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"

	"variations-serve-go/internal/config"
	"variations-serve-go/internal/domain/skill"
	"variations-serve-go/internal/httpx"
)

// SkillCardDto GET /api/skills 的风格卡片 DTO（iOS DTOs.swift 的契约依据）。
// 可空字段用指针输出显式 null（禁 omitempty）
type SkillCardDto struct {
	ID                  string                    `json:"id"`
	Name                string                    `json:"name"`
	Description         string                    `json:"description"`
	DisplayName         string                    `json:"displayName"`
	ShortDescription    string                    `json:"shortDescription"`
	DefaultPrompt       string                    `json:"defaultPrompt"`
	SampleImageUrl      *string                   `json:"sampleImageUrl"`
	SampleImageAspect   *float64                  `json:"sampleImageAspect"`
	Size                *string                   `json:"size"`
	InstructionTemplate *[]skill.InstructionField `json:"instructionTemplate"`
}

// SkillsHandler GET /api/skills —— 模版元数据 + 样图 URL（绝不下发 SKILL.md body）。
// ETag = 序列化后响应内容的 SHA-256 前 16 hex（内容哈希，快照缓存下零额外成本）
type SkillsHandler struct {
	cfg   *config.Config
	store *skill.Store
}

func NewSkillsHandler(cfg *config.Config, store *skill.Store) *SkillsHandler {
	return &SkillsHandler{cfg: cfg, store: store}
}

func (h *SkillsHandler) Handle(c *gin.Context) {
	snap := h.store.Snapshot()
	if !snap.Available {
		httpx.RenderError(c, 503, httpx.CodeServiceUnavailable, "skills 资产目录未就位")
		return
	}

	cards := make([]SkillCardDto, 0, len(snap.Skills))
	for _, entry := range snap.Skills {
		resolved := snap.UI[entry.Name]
		var ui *skill.UiMeta
		if resolved.UI != nil {
			ui = resolved.UI
		}

		// 样图：manual 覆盖优先，否则公共读前缀默认路径；均未就位时 null（客户端优雅降级）
		var sampleURL *string
		if resolved.SampleOverride != nil {
			sampleURL = resolved.SampleOverride
		} else if h.cfg.OssPublicPrefix != "" {
			u := h.cfg.OssPublicPrefix + "/skills/" + entry.Name + "/assets/sample.jpg"
			sampleURL = &u
		}
		// 样图比例只对默认前缀路径下发（override 指向外部 URL，比例未知）
		var aspect *float64
		if resolved.SampleOverride == nil && h.cfg.OssPublicPrefix != "" {
			aspect = skill.ProbeAspect(h.store.SkillsDir, entry.Name)
		}

		card := SkillCardDto{
			ID:                entry.Name,
			Name:              entry.Meta.Name,
			Description:       entry.Meta.Description,
			SampleImageUrl:    sampleURL,
			SampleImageAspect: aspect,
		}
		if ui != nil {
			card.DisplayName = strOrEmpty(ui.DisplayName)
			card.ShortDescription = strOrEmpty(ui.ShortDescription)
			card.DefaultPrompt = strOrEmpty(ui.DefaultPrompt)
			card.Size = ui.Size
			if ui.InstructionTemplate != nil {
				tpl := ui.InstructionTemplate
				card.InstructionTemplate = &tpl
			}
		}
		cards = append(cards, card)
	}

	body, err := json.Marshal(cards)
	if err != nil {
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	sum := sha256.Sum256(body)
	etag := `W/"` + hex.EncodeToString(sum[:])[:16] + `"`
	c.Header("ETag", etag)
	if c.GetHeader("If-None-Match") == etag {
		c.Status(http.StatusNotModified)
		return
	}
	c.Data(http.StatusOK, "application/json; charset=utf-8", body)
}

func strOrEmpty(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}
