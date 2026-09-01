package handlers

import (
	"errors"
	"regexp"
	"time"

	"github.com/gin-gonic/gin"

	"variations-serve-go/internal/config"
	"variations-serve-go/internal/domain/oss"
	"variations-serve-go/internal/httpx"
)

// 扩展名白名单与对应 MIME（客户端压缩后通常为 JPEG，其余格式预留）
var extMime = map[string]string{
	"jpg":  "image/jpeg",
	"jpeg": "image/jpeg",
	"png":  "image/png",
	"webp": "image/webp",
	"bmp":  "image/bmp",
}

const (
	putExpires = 1 * time.Hour // 上传票据 1h
	// GET 签名 ≤2h（安全短时效）；对象本身 48h 生命周期内可凭哈希反复重签（/api/file-url）
	getExpires = 2 * time.Hour
)

// 内容寻址哈希：64 位小写十六进制（客户端上报的上传内容 SHA-256）
var hashRe = regexp.MustCompile(`^[0-9a-f]{64}$`)

// UploadTicketDto GET /api/upload-ticket 的票据 DTO
type UploadTicketDto struct {
	UploadURL string `json:"uploadUrl"`
	FileURL   string `json:"fileUrl"`
	// ContentType 客户端 PUT 必须携带的同值 Content-Type（已绑入签名）
	ContentType string `json:"contentType"`
	// ExpiresAt 上传签名失效时间（RFC 3339 UTC）
	ExpiresAt string `json:"expiresAt"`
}

// UploadTicketHandler GET /api/upload-ticket?ext=&hash= —— OSS 预签名票据（PUT 上传 / GET 喂模型）。
// ObjectKey 内容寻址：uploads/{sha256}.{ext}（同图去重、幂等覆盖）；
// 失败重试约定：客户端重取票据重传（票据接口轻量），无需分片续传。
type UploadTicketHandler struct {
	cfg    *config.Config
	signer *oss.Signer
}

func NewUploadTicketHandler(cfg *config.Config, signer *oss.Signer) *UploadTicketHandler {
	return &UploadTicketHandler{cfg: cfg, signer: signer}
}

func (h *UploadTicketHandler) Handle(c *gin.Context) {
	ext := toLower(c.Query("ext"))
	mime, ok := extMime[ext]
	if !ok {
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
	uploadURL, err := h.signer.SignPut(ctx, objectKey, mime, putExpires)
	if err != nil {
		if errors.Is(err, oss.ErrNotConfigured) {
			httpx.RenderError(c, 503, httpx.CodeServiceUnavailable, err.Error())
			return
		}
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	fileURL, err := h.signer.SignGet(ctx, objectKey, getExpires)
	if err != nil {
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	c.JSON(200, UploadTicketDto{
		UploadURL:   uploadURL,
		FileURL:     fileURL,
		ContentType: mime,
		ExpiresAt:   time.Now().Add(putExpires).UTC().Format(time.RFC3339),
	})
}

func toLower(s string) string {
	b := []byte(s)
	for i := range b {
		if b[i] >= 'A' && b[i] <= 'Z' {
			b[i] += 'a' - 'A'
		}
	}
	return string(b)
}
