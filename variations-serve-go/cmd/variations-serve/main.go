// variations-serve-go 引导层：装配 + 启动（设备身份令牌鉴权 + 双供应商编译/生图代理）
package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"variations-serve-go/internal/auth"
	"variations-serve-go/internal/config"
	"variations-serve-go/internal/domain/oss"
	"variations-serve-go/internal/domain/skill"
	"variations-serve-go/internal/handlers"
	"variations-serve-go/internal/server"
	"variations-serve-go/internal/store"
)

func main() {
	logger := config.NewLogger()
	cfg := config.Load(logger)

	// SQLite：鉴权硬依赖，打开/迁移失败即退出
	db, err := store.Open(cfg.DBPath)
	if err != nil {
		logger.Error("SQLite 初始化失败", "error", err.Error())
		os.Exit(1)
	}
	defer db.Close()
	authRepo := store.NewAuthRepo(db)
	userRepo := store.NewUserRepo(db)
	quotaRepo := store.NewQuotaRepo(db)

	// skills 资产：快照 + fsnotify 热重载（assets 目录缺失仅告警，/api/skills 将 503）
	assetsDir := resolveAssetsDir(cfg.AssetsDir)
	assetStore := skill.NewStore(assetsDir, logger)
	assetStore.StartWatch()
	defer assetStore.Close()

	// 混搭注册表引用到的供应商缺 key 时提前告警（对应 skill 相关接口将在调用时 502）
	for provider := range assetStore.ReferencedProviders() {
		missingKey := (provider == config.ProviderQwen && cfg.DashscopeAPIKey == "") ||
			(provider == config.ProviderArk && cfg.ArkAPIKey == "")
		if missingKey {
			envName := "DASHSCOPE_API_KEY"
			if provider == config.ProviderArk {
				envName = "ARK_API_KEY"
			}
			logger.Warn(fmt.Sprintf("混搭注册表引用了 %s，但未配置 %s，相关 skill 将不可用", provider, envName))
		}
	}

	// 装配 handlers
	gate := auth.NewHMACGate(cfg.RegisterSecret)
	registerHandler := auth.NewRegisterHandler(gate, authRepo, logger)
	appleVerifier := auth.NewAppleVerifier(cfg.AppleClientID)
	appleLoginHandler := auth.NewAppleLoginHandler(appleVerifier, userRepo, quotaRepo, cfg, logger)
	accountHandler := handlers.NewAccountHandler(userRepo, quotaRepo, cfg, logger)
	signer := oss.NewSigner(cfg.Oss)
	engine := server.BuildRoutes(cfg, logger, authRepo, quotaRepo, userRepo, server.Handlers{
		Register:       registerHandler.Handle,
		AppleLogin:     appleLoginHandler.Handle,
		Logout:         accountHandler.Logout,
		DeleteAccount:  accountHandler.DeleteAccount,
		Quota:          accountHandler.Quota,
		BillingConfirm: handlers.NewBillingHandler(userRepo, cfg, logger).Confirm,
		Skills:         handlers.NewSkillsHandler(cfg, assetStore).Handle,
		UploadTicket:   handlers.NewUploadTicketHandler(cfg, signer).Handle,
		FileURL:        handlers.NewFileURLHandler(cfg, signer).Handle,
		Compile:        handlers.NewCompileHandler(cfg, assetStore, logger).Handle,
		Image:          handlers.NewImageHandler(cfg, assetStore, logger).Handle,
	})

	// http.Server 超时策略：仅 ReadHeaderTimeout + IdleTimeout；
	// 不设全局 Read/WriteTimeout（避免误杀 5min 长响应），请求级时限由 per-request context 控制
	srv := &http.Server{
		Addr:              fmt.Sprintf("%s:%d", cfg.Host, cfg.Port),
		Handler:           engine,
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	// 优雅关停：SIGINT/SIGTERM → 等在途请求（30s）→ 关 DB/watcher（defer）
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	go func() {
		logger.Info("variations-serve-go listening", "url", "http://"+srv.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("服务启动失败", "error", err.Error())
			os.Exit(1)
		}
	}()
	<-ctx.Done()
	logger.Info("收到关停信号，等待在途请求完成（最多 30s）")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Warn("优雅关停超时，强制退出", "error", err.Error())
	}
	logger.Info("服务已停止")
}

// resolveAssetsDir 资产目录：显式 ASSETS_DIR 优先；否则探测 ./assets
// （资产随 Go 服务自包含，make dev 的 cwd 即本目录）；均不存在返回空（/api/skills 将 503）
func resolveAssetsDir(explicit string) string {
	if explicit != "" {
		if dirExists(explicit) {
			return explicit
		}
		return ""
	}
	candidate := "assets"
	if dirExists(candidate) {
		if abs, err := filepath.Abs(candidate); err == nil {
			return abs
		}
		return candidate
	}
	return ""
}

func dirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}
