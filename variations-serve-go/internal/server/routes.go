package server

import (
	"fmt"
	"log/slog"
	"strings"

	"github.com/gin-gonic/gin"

	"variations-serve-go/internal/config"
	"variations-serve-go/internal/httpx"
	"variations-serve-go/internal/store"
)

// maxBodyBytes 请求体上限 1MB（各接口均为小 JSON）
const maxBodyBytes = 1024 * 1024

// Handlers 业务 handler 注入集（main 装配后传入，server 包不依赖 handlers 包防循环）
type Handlers struct {
	Register       gin.HandlerFunc // POST /api/auth/device（公开 + IP 限频）
	AppleLogin     gin.HandlerFunc // POST /api/auth/apple（公开 + IP 限频）
	Logout         gin.HandlerFunc // POST /api/auth/logout（Bearer）
	DeleteAccount  gin.HandlerFunc // POST /api/account/delete（Bearer）
	Quota          gin.HandlerFunc // GET /api/quota（Bearer）
	BillingConfirm gin.HandlerFunc // POST /api/billing/confirm（Bearer 用户）
	Skills         gin.HandlerFunc // GET /api/skills
	UploadTicket   gin.HandlerFunc // GET /api/upload-ticket
	FileURL        gin.HandlerFunc // GET /api/file-url（再次变奏重签）
	Compile        gin.HandlerFunc // POST /api/compile（编译防刷上限）
	Image          gin.HandlerFunc // POST /api/image（配额阶梯扣减点）
}

// BuildRoutes URL → Handler 的唯一注册点。
// 中间件顺序：requestLog → recovery → healthz（无鉴权）→ /api（auth → bodyLimit）。
// Gin 对方法不匹配默认走 NoRoute（404），恰与既有客户端契约一致。
func BuildRoutes(cfg *config.Config, logger *slog.Logger, authRepo *store.AuthRepo, quotaRepo *store.QuotaRepo, userRepo *store.UserRepo, h Handlers) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	engine := gin.New()

	engine.Use(RequestLog(logger.With("scope", "http")))
	engine.Use(Recovery())

	// 健康检查（供部署探活，不走鉴权）
	engine.GET("/healthz", func(c *gin.Context) {
		c.JSON(200, gin.H{"ok": true, "service": "variations-serve-go"})
	})

	// 统一 404：未知路由（含方法不匹配）
	engine.NoRoute(func(c *gin.Context) {
		httpx.RenderError(c, 404, httpx.CodeNotFound,
			fmt.Sprintf("未知路由：%s %s", c.Request.Method, c.Request.URL.Path))
	})

	api := engine.Group("/api")
	api.Use(BearerAuth(cfg, authRepo, logger.With("scope", "auth")))
	api.Use(httpx.BodyLimit(maxBodyBytes))

	// 公开注册端点：挂在鉴权组外——单独建组按 IP 限频
	// 注意：engine.Group 与 api 平级，显式不走 BearerAuth
	registerGroup := engine.Group("/api")
	registerGroup.Use(httpx.BodyLimit(maxBodyBytes))
	registerGroup.Use(RateLimitByKey(NewMinuteLimiter(cfg.AuthRegisterPerMin), ClientIP))
	registerGroup.POST("/auth/device", h.Register)

	appleGroup := engine.Group("/api")
	appleGroup.Use(httpx.BodyLimit(maxBodyBytes))
	appleGroup.Use(RateLimitByKey(NewMinuteLimiter(cfg.AuthApplePerMin), ClientIP))
	appleGroup.POST("/auth/apple", h.AppleLogin)

	// 账号端点（Bearer 鉴权组内）
	api.POST("/auth/logout", h.Logout)
	api.POST("/account/delete", h.DeleteAccount)
	api.GET("/quota", h.Quota)
	api.POST("/billing/confirm", h.BillingConfirm)

	api.GET("/skills", h.Skills)
	// 限频口径：principal 优先（会话令牌下按用户），游客回退设备 id
	ticketLimit := RateLimitByKey(NewMinuteLimiter(cfg.RateLimitPerMin), func(c *gin.Context) string {
		if p := httpx.Principal(c); p != "" && p != "admin" {
			return p
		}
		if id := DeviceID(c); id != "" {
			return id
		}
		return ClientIP(c)
	})
	api.GET("/upload-ticket", ticketLimit, h.UploadTicket)
	api.GET("/file-url", ticketLimit, h.FileURL)

	// 编译防刷上限（不扣次数，独立计数）：游客/用户分档
	api.POST("/compile", QuotaGuardDaily(quotaRepo, store.CompilePrincipal, func(p string) int {
		if strings.HasPrefix(p, "user:") {
			return cfg.UserDailyCompileCap
		}
		return cfg.GuestDailyCompileCap
	}, logger.With("scope", "quota")), h.Compile)
	// 生图唯一扣减点：游客终身 1 次 → 用户特权每日 10 次 → 已购余额；4xx/5xx 原路退还
	api.POST("/image", ImageQuotaGuard(cfg, quotaRepo, userRepo, logger.With("scope", "quota")), h.Image)

	return engine
}
