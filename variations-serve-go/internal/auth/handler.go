package auth

import (
	"errors"
	"log/slog"
	"regexp"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"variations-serve-go/internal/httpx"
	"variations-serve-go/internal/store"
)

// deviceId 宽松格式：UUID 或 ≤64 字符的 [a-zA-Z0-9-_]
var deviceIDRe = regexp.MustCompile(`^[a-zA-Z0-9_-]{1,64}$`)

func validDeviceID(id string) bool {
	if id == "" || len(id) > 64 {
		return false
	}
	if _, err := uuid.Parse(id); err == nil {
		return true
	}
	return deviceIDRe.MatchString(id)
}

type registerPayload struct {
	DeviceID   string `json:"deviceId"`
	DeviceName string `json:"deviceName"`
	Proof      string `json:"proof"`
}

// RegisterHandler POST /api/auth/device —— 设备自助注册换取长期 token（明文仅返回一次）。
// 幂等：同 deviceId 再注册吊销旧 token 签发新 token。
type RegisterHandler struct {
	gate   RegisterGate
	repo   *store.AuthRepo
	logger *slog.Logger
}

func NewRegisterHandler(gate RegisterGate, repo *store.AuthRepo, logger *slog.Logger) *RegisterHandler {
	return &RegisterHandler{gate: gate, repo: repo, logger: logger.With("scope", "auth")}
}

func (h *RegisterHandler) Handle(c *gin.Context) {
	var p registerPayload
	if apiErr := httpx.DecodeJSON(c, &p); apiErr != nil {
		httpx.RenderError(c, apiErr.Status, apiErr.Code, apiErr.Message)
		return
	}
	if !validDeviceID(p.DeviceID) {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "非法 deviceId，须为 UUID 或不超过 64 位的 [a-zA-Z0-9-_]")
		return
	}
	if len(p.DeviceName) > 128 {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "deviceName 超过 128 字符限制")
		return
	}

	if err := h.gate.Verify(RegisterRequest{DeviceID: p.DeviceID, DeviceName: p.DeviceName, Proof: p.Proof}); err != nil {
		switch {
		case errors.Is(err, ErrGateNotConfigured):
			httpx.RenderError(c, 503, httpx.CodeServiceUnavailable, "注册服务未启用")
		case errors.Is(err, ErrProofInvalid):
			httpx.RenderError(c, 401, httpx.CodeRegisterDenied, "设备注册凭证校验失败")
		default:
			httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		}
		return
	}

	token, err := GenerateToken()
	if err != nil {
		h.logger.Error("生成 token 失败", "error", err.Error())
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	if err := h.repo.RegisterDevice(c.Request.Context(), p.DeviceID, p.DeviceName, HashToken(token)); err != nil {
		h.logger.Error("设备注册落库失败", "error", err.Error())
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	h.logger.Info("device registered", "deviceId", p.DeviceID)
	c.JSON(200, gin.H{"token": token, "deviceId": p.DeviceID})
}
