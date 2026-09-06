package auth

import (
	"crypto/hmac"
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
	// AuthorizationCode 一次性授权码（5 分钟内有效）：换 refresh_token 存库，
	// 供注销时撤销 Apple 授权（Guideline 5.1.1(v)）
	AuthorizationCode string `json:"authorizationCode"`
	// Nonce 客户端生成的 raw nonce；其 SHA-256 摘要已置入 request.nonce，
	// 服务端重算并与 token 的 nonce claim 比对（防重放）
	Nonce string `json:"nonce"`
}

// AppleLoginHandler POST /api/auth/apple —— SIWA identityToken 验签 → upsert 用户 →
// 签发 var_u_ 会话令牌（30 天，多设备并存）。已注销账号以同一 Apple ID 登录即复活。
type AppleLoginHandler struct {
	verifier *AppleVerifier
	tokens   *AppleTokenClient
	users    *store.UserRepo
	quotas   *store.QuotaRepo
	cfg      *config.Config
	logger   *slog.Logger
}

func NewAppleLoginHandler(verifier *AppleVerifier, tokens *AppleTokenClient, users *store.UserRepo, quotas *store.QuotaRepo, cfg *config.Config, logger *slog.Logger) *AppleLoginHandler {
	return &AppleLoginHandler{verifier: verifier, tokens: tokens, users: users, quotas: quotas, cfg: cfg, logger: logger.With("scope", "auth")}
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

	// 防重放：token 带 nonce claim 时必须验证——否则攻击者只要不传 raw nonce 即可绕过。
	// token 不带 nonce claim 则放行：旧版客户端（未设 request.nonce）的过渡兼容，
	// 待带 nonce 的版本覆盖存量安装后可改为硬要求。
	if identity.Nonce != "" && !hmac.Equal([]byte(identity.Nonce), []byte(NonceDigest(p.Nonce))) {
		h.logger.Warn("SIWA nonce 不匹配（可能为重放）", "sub", identity.Sub)
		httpx.RenderError(c, 401, httpx.CodeAppleTokenInvalid, "Apple 登录凭证校验失败")
		return
	}

	user, err := h.users.UpsertUser(c.Request.Context(), identity.Sub, identity.Email, identity.IsPrivateEmail, p.FullName)
	if err != nil {
		h.logger.Error("用户落库失败", "error", err.Error())
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}

	// 换取并刷新 refresh_token（注销时撤销授权的唯一凭据）：
	// 失败不阻断登录，仅告警——否则 Apple 授权服务抖动会直接堵死登录入口
	if p.AuthorizationCode != "" {
		if refresh, rerr := h.tokens.ExchangeCode(c.Request.Context(), p.AuthorizationCode); rerr != nil {
			h.logger.Warn("换取 Apple refresh_token 失败（注销时将无法撤销授权）", "userId", user.ID, "error", rerr.Error())
		} else if serr := h.users.StoreAppleRefreshToken(c.Request.Context(), user.ID, refresh); serr != nil {
			h.logger.Error("Apple refresh_token 落库失败", "userId", user.ID, "error", serr.Error())
		}
	}

	token, err := GenerateUserToken()
	if err != nil {
		h.logger.Error("生成会话令牌失败", "error", err.Error())
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	// 不吊销该用户的其他会话令牌：多设备（iPhone + iPad）需同时在线。
	// 配额按 user 主体计，与令牌数量无关；退出登录只吊销当前令牌，注销账号才吊销全部。
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
			h.cfg.GuestFreeTotal, h.cfg.NewUserPrivilegeDays, h.cfg.NewUserDaily, "",
			h.cfg.StaffUserIDs[user.ID]),
	})
}
