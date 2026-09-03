package server

import (
	"errors"
	"log/slog"
	"strings"

	"github.com/gin-gonic/gin"

	"variations-serve-go/internal/config"
	"variations-serve-go/internal/httpx"
	"variations-serve-go/internal/store"
)

// quotaSource 扣减来源（退还按原路返回）
type quotaSource string

const (
	sourceTrial     quotaSource = "trial"     // 游客终身体验
	sourcePrivilege quotaSource = "privilege" // 新用户特权每日额度
	sourcePaid      quotaSource = "paid"      // 已购次数
)

// ImageQuotaGuard 生图配额阶梯守卫：游客→终身 1 次；用户→特权每日额度优先、已购余额兜底。
// 先扣后行；4xx/5xx 按来源原路退还（客户端断连视为已消耗防刷退）。
func ImageQuotaGuard(cfg *config.Config, quota *store.QuotaRepo, users *store.UserRepo, logger *slog.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		base := httpx.Principal(c)
		if base == "" || base == "admin" {
			c.Next()
			return
		}
		ctx := c.Request.Context()
		var (
			src    quotaSource
			bucket string
			err    error
		)
		if strings.HasPrefix(base, "device:") {
			src, bucket = sourceTrial, store.LifetimeBucket
			err = quota.Deduct(ctx, base, bucket, cfg.GuestFreeTotal)
		} else {
			userID := httpx.UserID(c)
			// Staff 白名单：开发者自用不扣减（服务端生效，客户端无感知）
			if cfg.StaffUserIDs[userID] {
				c.Next()
				return
			}
			if active, _ := store.PrivilegeWindow(quota, httpx.UserCreatedAt(c), cfg.NewUserPrivilegeDays); active {
				bucket = quota.TodayBucket()
				switch derr := quota.Deduct(ctx, base, bucket, cfg.NewUserDaily); {
				case derr == nil:
					src = sourcePrivilege
				case errors.Is(derr, store.ErrQuotaExceeded):
					// 特权当日满 → 落已购余额
				default:
					logger.Warn("特权配额扣减异常", "error", derr.Error())
					httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
					return
				}
			}
			if src == "" {
				src = sourcePaid
				err = users.DeductPaid(ctx, userID)
			}
		}
		if err != nil {
			if errors.Is(err, store.ErrQuotaExceeded) {
				renderQuotaExceeded(c, cfg, quota, users, base, src)
				return
			}
			logger.Warn("配额扣减异常", "error", err.Error())
			httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
			return
		}
		c.Next()
		// 4xx（参数校验失败等）与 5xx（上游失败）均退还：次数只消耗在成功生成上
		if c.Writer.Status() >= 400 {
			if src == sourcePaid {
				if rerr := users.RefundPaid(ctx, httpx.UserID(c)); rerr != nil {
					logger.Warn("购买余额退还失败", "error", rerr.Error())
				}
			} else if rerr := quota.Refund(ctx, base, bucket); rerr != nil {
				logger.Warn("配额退还失败", "error", rerr.Error())
			}
		}
	}
}

// QuotaGuardDaily 每日防刷守卫（compile 用）：principalFor 映射计数键，limitFor 按主体分档
func QuotaGuardDaily(quota *store.QuotaRepo, principalFor func(principal string) string, limitFor func(principal string) int, logger *slog.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		base := httpx.Principal(c)
		if base == "" || base == "admin" {
			c.Next()
			return
		}
		principal := principalFor(base)
		bucket := quota.TodayBucket()
		if err := quota.Deduct(c.Request.Context(), principal, bucket, limitFor(base)); err != nil {
			if errors.Is(err, store.ErrQuotaExceeded) {
				httpx.RenderError(c, 429, httpx.CodeQuotaExceeded, "今日请求过于频繁，请稍后再试")
				return
			}
			logger.Warn("防刷扣减异常", "error", err.Error())
			httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
			return
		}
		c.Next()
		if c.Writer.Status() >= 400 {
			if rerr := quota.Refund(c.Request.Context(), principal, bucket); rerr != nil {
				logger.Warn("防刷退还失败", "error", rerr.Error())
			}
		}
	}
}

// renderQuotaExceeded 429 + 配额摘要（含特权/已购明细供客户端选 CTA）
func renderQuotaExceeded(c *gin.Context, cfg *config.Config, quota *store.QuotaRepo, users *store.UserRepo, base string, src quotaSource) {
	summary := store.BuildQuotaSummary(
		c.Request.Context(), quota, users, base, httpx.UserID(c), httpx.UserCreatedAt(c),
		cfg.GuestFreeTotal, cfg.NewUserPrivilegeDays, cfg.NewUserDaily, string(src),
		cfg.StaffUserIDs[httpx.UserID(c)])
	c.AbortWithStatusJSON(429, gin.H{
		"code":    httpx.CodeQuotaExceeded,
		"message": "今日次数已用完",
		"quota":   summary,
	})
}
