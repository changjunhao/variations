package handlers

import (
	"log/slog"

	"github.com/gin-gonic/gin"

	"variations-serve-go/internal/auth"
	"variations-serve-go/internal/config"
	"variations-serve-go/internal/httpx"
	"variations-serve-go/internal/store"
)

// AccountHandler 账号端点：退出登录 / 注销账号 / 配额查询（均需 Bearer 会话上下文）
type AccountHandler struct {
	users  *store.UserRepo
	quotas *store.QuotaRepo
	tokens *auth.AppleTokenClient
	cfg    *config.Config
	logger *slog.Logger
}

func NewAccountHandler(users *store.UserRepo, quotas *store.QuotaRepo, tokens *auth.AppleTokenClient, cfg *config.Config, logger *slog.Logger) *AccountHandler {
	return &AccountHandler{users: users, quotas: quotas, tokens: tokens, cfg: cfg, logger: logger.With("scope", "account")}
}

// Logout POST /api/auth/logout —— 仅用户会话令牌有效；吊销当前令牌后降级为游客
func (h *AccountHandler) Logout(c *gin.Context) {
	if httpx.UserID(c) == "" {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "当前为游客会话，无需退出")
		return
	}
	if err := h.users.RevokeToken(c.Request.Context(), httpx.TokenHash(c)); err != nil {
		h.logger.Error("退出登录吊销失败", "error", err.Error())
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	c.JSON(200, gin.H{"ok": true})
}

// DeleteAccount POST /api/account/delete —— 账号注销（Guideline 5.1.1(v)）：
// 先撤销 Apple 授权（Apple 硬要求），再清除个人信息 + 吊销全部会话令牌。
// 撤销失败仅告警不阻断：用户的注销权利不能被 Apple 侧故障扣住。
func (h *AccountHandler) DeleteAccount(c *gin.Context) {
	userID := httpx.UserID(c)
	if userID == "" {
		httpx.RenderError(c, 400, httpx.CodeBadRequest, "游客身份无账号可注销")
		return
	}
	h.revokeAppleGrant(c, userID)
	if err := h.users.DeleteUser(c.Request.Context(), userID); err != nil {
		h.logger.Error("账号注销失败", "error", err.Error())
		httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
		return
	}
	h.logger.Info("account deleted", "userId", userID)
	c.JSON(200, gin.H{"ok": true})
}

// revokeAppleGrant 注销前撤销用户与本 App 的 Apple 授权；
// 未存 refresh_token（旧版登录或未配置密钥）与撤销失败均仅告警，便于服务端日志审计
func (h *AccountHandler) revokeAppleGrant(c *gin.Context, userID string) {
	refresh, err := h.users.AppleRefreshToken(c.Request.Context(), userID)
	if err != nil {
		h.logger.Error("读取 Apple refresh_token 失败", "userId", userID, "error", err.Error())
		return
	}
	if refresh == "" {
		h.logger.Warn("未持有 Apple refresh_token，本次注销未撤销 Apple 授权", "userId", userID)
		return
	}
	if err := h.tokens.Revoke(c.Request.Context(), refresh); err != nil {
		h.logger.Warn("撤销 Apple 授权失败（已继续本地注销）", "userId", userID, "error", err.Error())
		return
	}
	h.logger.Info("apple grant revoked", "userId", userID)
}

// Quota GET /api/quota —— 当前主体配额摘要（次数口径：trial/privilege/paid 三态）。
func (h *AccountHandler) Quota(c *gin.Context) {
	principal := httpx.Principal(c)
	if principal == "" {
		httpx.RenderError(c, 401, httpx.CodeUnauthorized, "鉴权失败：缺少或无效的 Bearer token")
		return
	}
	summary := store.BuildQuotaSummary(
		c.Request.Context(), h.quotas, h.users, principal, httpx.UserID(c), httpx.UserCreatedAt(c),
		h.cfg.GuestFreeTotal, h.cfg.NewUserPrivilegeDays, h.cfg.NewUserDaily, "",
		h.cfg.StaffUserIDs[httpx.UserID(c)])
	c.JSON(200, summary)
}
