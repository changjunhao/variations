package server

import (
	"errors"
	"net"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"

	"variations-serve-go/internal/auth"
	"variations-serve-go/internal/config"
	"variations-serve-go/internal/httpx"
	"variations-serve-go/internal/store"
)

// ctxKey 兼容别名：上下文键与读取器统一在 httpx（handlers 同读，防循环依赖）
type ctxKey = httpx.CtxKey

const CtxDeviceID = httpx.CtxDeviceID

// DeviceID 从上下文取鉴权通过的设备 id（未鉴权路径返回空）
func DeviceID(c *gin.Context) string { return httpx.DeviceID(c) }

// ============================== Bearer 鉴权 ==============================

// BearerAuth 身份令牌鉴权：Authorization: Bearer <token> → sha256 → 查 auth_tokens。
// 设备令牌 → principal=device:{id}；用户会话令牌 → principal=user:{id}。
// ADMIN_TOKEN 配置时提供恒定时间比对的运维旁路（principal=admin，不扣配额）。
func BearerAuth(cfg *config.Config, repo *store.AuthRepo, logger interface{ Warn(string, ...any) }) gin.HandlerFunc {
	return func(c *gin.Context) {
		const prefix = "Bearer "
		h := c.GetHeader("Authorization")
		if !strings.HasPrefix(h, prefix) || strings.TrimSpace(strings.TrimPrefix(h, prefix)) == "" {
			httpx.RenderError(c, 401, httpx.CodeUnauthorized, "鉴权失败：缺少或无效的 Bearer token")
			return
		}
		token := strings.TrimSpace(strings.TrimPrefix(h, prefix))

		// 运维旁路（可选，smoke/调试用）
		if cfg.AdminToken != "" && subtleEqual(token, cfg.AdminToken) {
			c.Set(string(httpx.CtxDeviceID), "admin")
			c.Set(string(httpx.CtxPrincipal), "admin")
			c.Next()
			return
		}

		info, err := repo.ValidateToken(c.Request.Context(), auth.HashToken(token))
		if err != nil {
			if errors.Is(err, store.ErrTokenInvalid) {
				httpx.RenderError(c, 401, httpx.CodeUnauthorized, "鉴权失败：缺少或无效的 Bearer token")
				return
			}
			logger.Warn("token 校验异常", "error", err.Error())
			httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
			return
		}
		c.Set(string(httpx.CtxTokenHash), auth.HashToken(token))
		switch info.Kind {
		case store.KindUser:
			c.Set(string(httpx.CtxUserID), info.UserID)
			c.Set(string(httpx.CtxPrincipal), store.UserPrincipal(info.UserID))
			c.Set(string(httpx.CtxUserCreatedAt), info.UserCreatedAt)
		default:
			repo.TouchLastSeen(c.Request.Context(), info.DeviceID)
			c.Set(string(httpx.CtxDeviceID), info.DeviceID)
			c.Set(string(httpx.CtxPrincipal), store.DevicePrincipal(info.DeviceID))
		}
		c.Next()
	}
}

// ============================== 限频（固定分钟窗口） ==============================

// MinuteLimiter 固定分钟窗口计数：key → (minute, count)。
// 复刻边界语义：先自增后比较（恰好放行 max 次）；新分钟首请求免检；桶 >1024 顺带清理过期项。
type MinuteLimiter struct {
	max     int
	mu      sync.Mutex
	buckets map[string]bucket
}

type bucket struct {
	minute int64
	count  int
}

func NewMinuteLimiter(maxPerMin int) *MinuteLimiter {
	return &MinuteLimiter{max: maxPerMin, buckets: make(map[string]bucket)}
}

// Allow 返回是否放行
func (l *MinuteLimiter) Allow(key string) bool {
	minute := time.Now().UnixMilli() / 60_000
	l.mu.Lock()
	defer l.mu.Unlock()
	b, ok := l.buckets[key]
	if !ok || b.minute != minute {
		l.buckets[key] = bucket{minute: minute, count: 1}
		return true
	}
	b.count++
	l.buckets[key] = b
	if b.count > l.max {
		return false
	}
	if len(l.buckets) > 1024 {
		for k, v := range l.buckets {
			if v.minute != minute {
				delete(l.buckets, k)
			}
		}
	}
	return true
}

// RateLimitByKey 按 keyFunc 限频中间件（超限 429 RATE_LIMITED）
func RateLimitByKey(limiter *MinuteLimiter, keyFunc func(*gin.Context) string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !limiter.Allow(keyFunc(c)) {
			httpx.RenderError(c, 429, httpx.CodeRateLimited, "请求过于频繁，请稍后再试")
			return
		}
		c.Next()
	}
}

// ClientIP 取 TCP 对端 IP（不解析 X-Forwarded-For，与鉴权/限频口径一致）
func ClientIP(c *gin.Context) string {
	host, _, err := net.SplitHostPort(c.Request.RemoteAddr)
	if err != nil {
		return c.Request.RemoteAddr
	}
	return host
}

// ============================== 请求日志 ==============================

// RequestLog access log：method/path/status/耗时，/healthz 打 debug、4xx warn、5xx error
func RequestLog(logger interface {
	Debug(string, ...any)
	Info(string, ...any)
	Warn(string, ...any)
	Error(string, ...any)
}) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		status := c.Writer.Status()
		ms := time.Since(start).Milliseconds()
		path := c.Request.URL.Path
		fields := []any{"method", c.Request.Method, "path", path, "status", status, "ms", ms}
		switch {
		case path == "/healthz":
			logger.Debug("request", fields...)
		case status >= 500:
			logger.Error("request", fields...)
		case status >= 400:
			logger.Warn("request", fields...)
		default:
			logger.Info("request", fields...)
		}
	}
}

// ============================== panic 恢复与错误映射 ==============================

// Recovery panic → ApiError 按 status/code 映射；其余兜底 500（错误日志由 RequestLog 按最终 status 记录）
func Recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if r := recover(); r != nil {
				if apiErr, ok := r.(*httpx.ApiError); ok {
					httpx.RenderError(c, apiErr.Status, apiErr.Code, apiErr.Message)
					return
				}
				httpx.RenderError(c, 500, httpx.CodeInternalError, "服务器内部错误")
			}
		}()
		c.Next()
	}
}

// ============================== 工具 ==============================

// subtleEqual 恒定时间字符串比较（长度不等先否）
func subtleEqual(a, b string) bool {
	ab, bb := []byte(a), []byte(b)
	if len(ab) != len(bb) {
		return false
	}
	var diff byte
	for i := range ab {
		diff |= ab[i] ^ bb[i]
	}
	return diff == 0
}
