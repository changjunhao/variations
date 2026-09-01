package handlers

import (
	"errors"
	"log/slog"

	"github.com/gin-gonic/gin"

	"variations-serve-go/internal/auth"
	"variations-serve-go/internal/config"
	"variations-serve-go/internal/httpx"
	"variations-serve-go/internal/store"
)

// BillingHandler IAP 落账：StoreKit 2 消耗型票据 JWS 验签 → 幂等加购买余额
type BillingHandler struct {
	users    *store.UserRepo
	cfg      *config.Config
	verifier *auth.JWSVerifier
	logger   *slog.Logger
}

func NewBillingHandler(users *store.UserRepo, cfg *config.Config, logger *slog.Logger) *BillingHandler {
	return &BillingHandler{users: users, cfg: cfg, verifier: auth.NewAppleJWSVerifier(), logger: logger.With("scope", "billing")}
}

// Confirm POST /api/billing/confirm —— body {jws}；仅登录用户。
// 幂等：transactionId 主键冲突不重复落账，直接返回当前余额。
func (h *BillingHandler) Confirm(c *gin.Context) {
	userID := httpx.UserID(c)
	if userID == "" {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "游客身份不可购买，请先登录")
		return
	}
	if len(h.cfg.IAPProducts) == 0 {
		httpx.RenderError(c, 503, httpx.CodeServiceUnavailable, "购买服务未启用")
		return
	}
	var p struct {
		JWS string `json:"jws"`
	}
	if apiErr := httpx.DecodeJSON(c, &p); apiErr != nil {
		httpx.RenderError(c, apiErr.Status, apiErr.Code, apiErr.Message)
		return
	}
	if p.JWS == "" {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "jws 必填")
		return
	}

	info, err := h.verifier.Verify(p.JWS, h.cfg.AppleClientID, h.cfg.IAPEnvironment)
	if err != nil {
		// 开发期完整记录验签失败原因与票据，便于定位链/签名/claims 问题
		h.logger.Warn("票据验签失败", "error", err.Error(), "jws", p.JWS)
		if errors.Is(err, auth.ErrJWSInvalid) {
			httpx.RenderError(c, 401, httpx.CodeBillingInvalid, "购买票据校验失败")
			return
		}
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	count, ok := h.cfg.IAPProducts[info.ProductID]
	if !ok {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "未知商品")
		return
	}
	quantity := count
	if info.Quantity > 1 {
		quantity = count * info.Quantity
	}

	remaining, already, err := h.users.CreditPurchase(c.Request.Context(), info.TransactionID, userID, info.ProductID, quantity)
	if err != nil {
		h.logger.Error("落账失败", "error", err.Error())
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	h.logger.Info("purchase confirmed", "userId", userID, "product", info.ProductID, "count", quantity, "replayed", already)
	c.JSON(200, gin.H{"remaining": remaining, "applied": !already})
}
