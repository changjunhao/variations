package handlers

import (
	"errors"
	"time"

	"github.com/gin-gonic/gin"

	"variations-serve-go/internal/config"
	"variations-serve-go/internal/domain/oss"
	"variations-serve-go/internal/httpx"
)

// FileURLDto GET /api/file-url 的票据 DTO（对象存在时重签的新 GET 票据）
type FileURLDto struct {
	FileURL string `json:"fileUrl"`
	// ExpiresAt GET 签名失效时间（RFC 3339 UTC，≤2h）
	ExpiresAt string `json:"expiresAt"`
}

// FileURLHandler GET /api/file-url?ext=&hash= —— 再次变奏重签：
// 先 HeadObject 探测对象存在性（对象 48h 后由 bucket 生命周期清理）；
// 存在 → 重签短时效（≤2h）GET 票据；已清理 → 410 SOURCE_FILE_GONE（客户端提示「不可变奏」，不降级文生图）。
// 签名一律现签现用，绝不下发与 48h 生命周期等长的长效签名。
type FileURLHandler struct {
	cfg    *config.Config
	signer *oss.Signer
}

func NewFileURLHandler(cfg *config.Config, signer *oss.Signer) *FileURLHandler {
	return &FileURLHandler{cfg: cfg, signer: signer}
}

func (h *FileURLHandler) Handle(c *gin.Context) {
	ext := toLower(c.Query("ext"))
	if _, ok := extMime[ext]; !ok {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "非法 ext，允许值：jpg/jpeg/png/webp/bmp")
		return
	}
	hash := c.Query("hash")
	if !hashRe.MatchString(hash) {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "非法 hash，必须为 64 位小写十六进制")
		return
	}

	objectKey := "uploads/" + hash + "." + ext
	ctx := c.Request.Context()
	exists, err := h.signer.ObjectExists(ctx, objectKey)
	if err != nil {
		if errors.Is(err, oss.ErrNotConfigured) {
			httpx.RenderError(c, 503, httpx.CodeServiceUnavailable, err.Error())
			return
		}
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	if !exists {
		httpx.RenderError(c, 410, httpx.CodeSourceFileGone, "源图已超过 48 小时保留期被清理")
		return
	}
	fileURL, err := h.signer.SignGet(ctx, objectKey, getExpires)
	if err != nil {
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	c.JSON(200, FileURLDto{
		FileURL:   fileURL,
		ExpiresAt: time.Now().Add(getExpires).UTC().Format(time.RFC3339),
	})
}
