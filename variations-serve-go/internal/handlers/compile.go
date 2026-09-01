package handlers

import (
	"context"
	"errors"
	"log/slog"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"

	"variations-serve-go/internal/config"
	"variations-serve-go/internal/domain/model"
	"variations-serve-go/internal/domain/pipeline"
	"variations-serve-go/internal/domain/skill"
	"variations-serve-go/internal/httpx"
)

// compilePayload POST /api/compile 请求体（严格类型化）
type compilePayload struct {
	SkillID     string `json:"skillId"`
	InlineSkill *struct {
		Body  string            `json:"body"`
		Files map[string]string `json:"files"`
	} `json:"inlineSkill"`
	ImageURL    string `json:"imageUrl"`
	Instruction string `json:"instruction"`
}

// CompileHandler POST /api/compile —— skillId（官方模版）| inlineSkill（用户模版）→ prompt
type CompileHandler struct {
	cfg    *config.Config
	store  *skill.Store
	logger *slog.Logger
}

func NewCompileHandler(cfg *config.Config, store *skill.Store, logger *slog.Logger) *CompileHandler {
	return &CompileHandler{cfg: cfg, store: store, logger: logger.With("scope", "compiler")}
}

func (h *CompileHandler) Handle(c *gin.Context) {
	var p compilePayload
	if apiErr := httpx.DecodeJSON(c, &p); apiErr != nil {
		httpx.RenderError(c, apiErr.Status, apiErr.Code, apiErr.Message)
		return
	}

	// skillId 与 inlineSkill 二选一（互斥校验）
	hasSkillID := p.SkillID != ""
	hasInline := p.InlineSkill != nil
	if hasSkillID == hasInline {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "skillId 与 inlineSkill 必须且只能提供一个")
		return
	}
	if p.ImageURL == "" {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "imageUrl 必填")
		return
	}
	if err := model.AssertBucketURL(h.cfg, p.ImageURL); err != nil {
		renderValidation(c, err)
		return
	}
	if err := model.AssertInstruction(p.Instruction); err != nil {
		renderValidation(c, err)
		return
	}

	// 组装编译入参：官方模版按混搭注册表解析编译供应商；inlineSkill 走全局默认
	var input model.CompileInput
	var skillID string
	if hasSkillID {
		skillID = p.SkillID
		loaded, err := h.store.LoadSkill(p.SkillID)
		if err != nil {
			renderSkillError(c, err)
			return
		}
		input = model.CompileInput{Body: loaded.Body, Files: loaded.Files}
	} else {
		if err := model.ValidateInlineSkill(p.InlineSkill.Body, p.InlineSkill.Files); err != nil {
			renderValidation(c, err)
			return
		}
		input = model.CompileInput{Body: p.InlineSkill.Body, Files: p.InlineSkill.Files}
	}
	input.ImageURL = p.ImageURL
	input.Instruction = p.Instruction

	// 权威朝向注入：源图像素尺寸由服务端探测文件头测定（fail-soft），
	// 「画幅跟随原图朝向」类 skill 的编译器以此为准，不再自行目测（方图按竖版，与客户端换算同口径）
	if w, h, ok := probeSourceSize(c, p.ImageURL); ok {
		orientation := "横版（landscape）"
		if w <= h {
			orientation = "竖版（portrait，方图同此）"
		}
		note := "\n【服务端测定】源图像素 " + strconv.Itoa(w) + "x" + strconv.Itoa(h) +
			"，朝向：" + orientation + "。skill 需要按源图朝向决定画幅时，必须采用本测定，不得自行判断。"
		input.Instruction += note
	}

	compileProvider, _ := pipeline.Resolve(h.store.Snapshot().Overrides, h.cfg.CompileProvider, skillID)
	prompt, err := model.Compile(c.Request.Context(), h.cfg, input, compileProvider, h.logger)
	if err != nil {
		renderUpstreamError(c, err)
		return
	}
	c.JSON(200, gin.H{"prompt": prompt})
}

// probeSourceSize 探测源图像素尺寸（5s 上限，超时/失败返回 false，编译照常进行只是不注入朝向）
func probeSourceSize(c *gin.Context, url string) (int, int, bool) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()
	return model.ProbeRemoteImageSize(ctx, url)
}

// renderValidation ValidationError → 400
func renderValidation(c *gin.Context, err error) {
	if v, ok := model.AsValidation(err); ok {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, v.Message)
		return
	}
	httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
}

// renderSkillError skill 领域错误映射：NotFound→404、Unavailable→503
func renderSkillError(c *gin.Context, err error) {
	var nf *skill.NotFoundError
	if errors.As(err, &nf) {
		httpx.RenderError(c, 404, httpx.CodeNotFound, nf.Message)
		return
	}
	if errors.Is(err, skill.ErrUnavailable) {
		httpx.RenderError(c, 503, httpx.CodeServiceUnavailable, err.Error())
		return
	}
	httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
}

// renderUpstreamError 上游错误映射 502（DASHSCOPE_ERROR/ARK_ERROR）
func renderUpstreamError(c *gin.Context, err error) {
	var de *model.DashScopeError
	if errors.As(err, &de) {
		httpx.RenderError(c, 502, httpx.CodeDashscopeError, de.Message)
		return
	}
	var ae *model.ArkError
	if errors.As(err, &ae) {
		httpx.RenderError(c, 502, httpx.CodeArkError, ae.Message)
		return
	}
	if v, ok := model.AsValidation(err); ok {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, v.Message)
		return
	}
	httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
}
