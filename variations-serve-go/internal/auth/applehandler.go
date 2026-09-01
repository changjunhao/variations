package auth

import (
	"errors"
	"log/slog"
	"time"

	"github.com/gin-gonic/gin"

	"variations-serve-go/internal/config"
	"variations-serve-go/internal/httpx"
	"variations-serve-go/internal/store"
)

// sessionTTL 用户会话令牌有效期 30 天
const sessionTTL = 30 * 24 * time.Hour

type appleLoginPayload struct {
	IdentityToken string `json:"identityToken"`
	// FullName 仅首次授权可得（客户端拼装 "given family"），空值不覆盖
	FullName string `json:"fullName"`
}

// AppleLoginHandler POST /api/auth/apple —— SIWA identityToken 验签 → upsert 用户 →
// 吊销旧会话令牌 → 签发 var_u_ 新令牌（30 天）。已注销账号 403 ACCOUNT_DELETED。
type AppleLoginHandler struct {
	verifier *AppleVerifier
	users    *store.UserRepo
	quotas   *store.QuotaRepo
	cfg      *config.Config
	logger   *slog.Logger
}

func NewAppleLoginHandler(verifier *AppleVerifier, users *store.UserRepo, quotas *store.QuotaRepo, cfg *config.Config, logger *slog.Logger) *AppleLoginHandler {
	return &AppleLoginHandler{verifier: verifier, users: users, quotas: quotas, cfg: cfg, logger: logger.With("scope", "auth")}
}

func (h *AppleLoginHandler) Handle(c *gin.Context) {
	if h.cfg.AppleClientID == "" {
		httpx.RenderError(c, 503, httpx.CodeServiceUnavailable, "登录服务未启用")
		return
	}
	var p appleLoginPayload
	if apiErr := httpx.DecodeJSON(c, &p); apiErr != nil {
		httpx.RenderError(c, apiErr.Status, apiErr.Code, apiErr.Message)
		return
	}
	if p.IdentityToken == "" {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "identityToken 必填")
		return
	}

	identity, err := h.verifier.Verify(c.Request.Context(), p.IdentityToken)
	if err != nil {
		if errors.Is(err, ErrAppleTokenInvalid) {
			httpx.RenderError(c, 401, httpx.CodeAppleTokenInvalid, "Apple 登录凭证校验失败")
			return
		}
		h.logger.Warn("JWKS 不可用", "error", err.Error())
		httpx.RenderError(c, 503, httpx.CodeServiceUnavailable, "登录服务暂不可用")
		return
	}

	user, err := h.users.UpsertUser(c.Request.Context(), identity.Sub, identity.Email, identity.IsPrivateEmail, p.FullName)
	if err != nil {
		if errors.Is(err, store.ErrUserDeleted) {
			httpx.RenderError(c, 403, httpx.CodeAccountDeleted, "该账号已注销")
			return
		}
		h.logger.Error("用户落库失败", "error", err.Error())
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}

	token, err := GenerateUserToken()
	if err != nil {
		h.logger.Error("生成会话令牌失败", "error", err.Error())
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	// 换发：先吊销旧会话令牌再签发新令牌（同设备多端收敛为单会话）
	if err := h.users.RevokeUserTokens(c.Request.Context(), user.ID); err != nil {
		h.logger.Error("吊销旧会话令牌失败", "error", err.Error())
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	expiresAt := time.Now().Add(sessionTTL).UTC().Format(time.RFC3339)
	if err := h.users.IssueSessionToken(c.Request.Context(), HashToken(token), user.ID, expiresAt); err != nil {
		h.logger.Error("会话令牌落库失败", "error", err.Error())
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}

	h.logger.Info("user signed in", "userId", user.ID)
	principal := store.UserPrincipal(user.ID)
	createdAt, _ := h.users.CreatedAt(c.Request.Context(), user.ID)
	createdAtRaw := ""
	if !createdAt.IsZero() {
		createdAtRaw = createdAt.Format(time.RFC3339)
	}
	c.JSON(200, gin.H{
		"token": token,
		"user": gin.H{
			"name":           user.FullName,
			"email":          user.Email,
			"isPrivateEmail": user.IsPrivateEmail,
		},
		"quota": store.BuildQuotaSummary(
			c.Request.Context(), h.quotas, h.users, principal, user.ID, createdAtRaw,
			h.cfg.GuestFreeTotal, h.cfg.NewUserPrivilegeDays, h.cfg.NewUserDaily, ""),
	})
}
