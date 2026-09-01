package handlers

import (
	"log/slog"

	"github.com/gin-gonic/gin"

	"variations-serve-go/internal/config"
	"variations-serve-go/internal/domain/model"
	"variations-serve-go/internal/domain/pipeline"
	"variations-serve-go/internal/domain/skill"
	"variations-serve-go/internal/httpx"
)

const maxRefImages = 3

// imagePayload POST /api/image —— 严格类型化：seed 仅 number、prompt/instruction 仅 string
type imagePayload struct {
	Prompt         string   `json:"prompt"`
	ImageURLs      []string `json:"imageUrls"`
	Size           string   `json:"size"`
	Seed           *int     `json:"seed"`
	NegativePrompt string   `json:"negativePrompt"`
	// SkillID 官方模版 id（可选）：仅用于按混搭注册表选择生图供应商；缺失/未知回退全局默认
	SkillID string `json:"skillId"`
}

// ImageHandler POST /api/image —— prompt + 参考图 → 生成图 URL
type ImageHandler struct {
	cfg    *config.Config
	store  *skill.Store
	logger *slog.Logger
}

func NewImageHandler(cfg *config.Config, store *skill.Store, logger *slog.Logger) *ImageHandler {
	return &ImageHandler{cfg: cfg, store: store, logger: logger.With("scope", "image")}
}

func (h *ImageHandler) Handle(c *gin.Context) {
	var p imagePayload
	if apiErr := httpx.DecodeJSON(c, &p); apiErr != nil {
		httpx.RenderError(c, apiErr.Status, apiErr.Code, apiErr.Message)
		return
	}

	if p.Prompt == "" {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "prompt 必填")
		return
	}
	if err := model.AssertPrompt(p.Prompt); err != nil {
		renderValidation(c, err)
		return
	}
	if len(p.ImageURLs) > maxRefImages {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "imageUrls 必须是数组且不超过 3 张")
		return
	}
	for _, u := range p.ImageURLs {
		if err := model.AssertBucketURL(h.cfg, u); err != nil {
			renderValidation(c, err)
			return
		}
	}

	// skillId 是供应商选择的提示性字段：宽松处理，缺失/未知均回退全局默认，不影响生图本身
	imageProvider, _ := pipeline.Resolve(h.store.Snapshot().Overrides, h.cfg.ImageProvider, p.SkillID)

	input := model.GenerateImageInput{
		Prompt:         p.Prompt,
		ImageURLs:      p.ImageURLs,
		Size:           p.Size,
		Seed:           p.Seed,
		NegativePrompt: p.NegativePrompt,
	}
	urls, err := model.GenerateImage(c.Request.Context(), h.cfg, input, imageProvider, h.logger)
	if err != nil {
		renderUpstreamError(c, err)
		return
	}
	c.JSON(200, gin.H{"urls": urls})
}
