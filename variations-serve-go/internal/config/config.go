// Package config 环境变量集中解析：Go 12-factor 惯例，程序只读 os.Getenv，
// env 文件的加载交给运行环境（systemd EnvironmentFile / make dev）。
// 供应商三级回退、条件必填等特殊语义手写解析（通用配置库覆盖不了）。
package config

import (
	"fmt"
	"log/slog"
	"os"
	"strconv"
	"strings"
	"time"
)

// ModelProvider 模型供应商：qwen（阿里百炼，默认）| ark（火山方舟 doubao 系列）
type ModelProvider string

const (
	ProviderQwen ModelProvider = "qwen"
	ProviderArk  ModelProvider = "ark"
)

// Config 全量服务配置
type Config struct {
	Port int
	Host string

	// 编译/生图管线供应商默认（COMPILE_PROVIDER > MODEL_PROVIDER > qwen）；
	// 单个 skill 可经 assets/pipeline-overrides.json 再覆盖
	CompileProvider ModelProvider
	ImageProvider   ModelProvider

	// 阿里百炼（qwen VL 编译 + qwen-image 生图）
	DashscopeAPIKey  string
	DashscopeBaseURL string
	QwenVLModel      string
	QwenImageModel   string

	// 火山方舟（doubao VL 编译 + seedream 生图）
	ArkAPIKey     string
	ArkBaseURL    string
	ArkVLModel    string
	ArkImageModel string

	// 请求超时：上游模型调用共用（请求级 context = 超时-5s 留回写余量）
	RequestTimeout time.Duration

	// 样图公共读前缀 URL（如 https://<bucket>.<endpoint>/public），可选
	OssPublicPrefix string

	// upload-ticket 每设备每分钟限频
	RateLimitPerMin int
	// 设备注册每 IP 每分钟限频
	AuthRegisterPerMin int

	// 设备注册门槛（App Secret）：未配置时注册端点 503，不允许裸开放
	RegisterSecret string
	// 运维旁路 Bearer token（可选，smoke/调试用）
	AdminToken string

	// SIWA：iOS Bundle ID（aud 校验）；未配置时 /api/auth/apple 503
	AppleClientID string
	// SIWA 登录每 IP 每分钟限频
	AuthApplePerMin int

	// 配额（次数口径）：游客终身体验次数；新用户特权天数与每日次数
	GuestFreeTotal       int
	NewUserPrivilegeDays int
	NewUserDaily         int
	// 编译防刷每日上限（游客/用户分档）
	GuestDailyCompileCap int
	UserDailyCompileCap  int

	// IAP：productID → 落账次数；IAPEnvironment 校验票据环境（Production|Sandbox）
	IAPProducts    map[string]int
	IAPEnvironment string

	// Staff 白名单：Apple sub 列表，命中者生图不扣减（开发者自用，仅服务端生效）
	StaffUserIDs map[string]bool

	Oss OssConfig

	// skills 资产目录（含 skills/、skills-ui.json、pipeline-overrides.json）
	AssetsDir string
	// SQLite 数据库文件路径
	DBPath string
}

type OssConfig struct {
	// Region 规范 region ID（如 cn-beijing）：签名 SDK 自拼 oss-{region}.aliyuncs.com，
	// 域名校验同口径拼装；加载时经 normalizeOssRegion 兼容 oss- 前缀旧写法
	Region          string
	Bucket          string
	AccessKeyID     string
	AccessKeySecret string
}

// normalizeOssRegion 兼容两种 env 写法：规范 region ID（cn-beijing）与
// 端点前缀式（oss-cn-beijing）；OssConfig.Region 统一存规范 ID
func normalizeOssRegion(s string) string {
	return strings.TrimPrefix(s, "oss-")
}

// parseProviderEnv 解析供应商环境变量：未设置取 fallback；取值非法告警并回退 fallback（不崩溃）
func parseProviderEnv(logger *slog.Logger, name string, fallback ModelProvider) ModelProvider {
	raw := strings.ToLower(strings.TrimSpace(os.Getenv(name)))
	if raw == "" {
		return fallback
	}
	if raw == string(ProviderQwen) || raw == string(ProviderArk) {
		return ModelProvider(raw)
	}
	logger.Warn(fmt.Sprintf("%s 取值非法（%s），已回退 %s", name, raw, fallback))
	return fallback
}

func envInt(name string, fallback int) int {
	raw := os.Getenv(name)
	if raw == "" {
		return fallback
	}
	v, err := strconv.Atoi(strings.TrimSpace(raw))
	if err != nil {
		return fallback
	}
	return v
}

// Load 解析全部环境变量；missing 返回缺失的必填变量名（调用方告警，不崩溃——
// 对应管线实际调用时才抛错）
func Load(logger *slog.Logger) *Config {
	baseProvider := parseProviderEnv(logger, "MODEL_PROVIDER", ProviderQwen)
	compileProvider := parseProviderEnv(logger, "COMPILE_PROVIDER", baseProvider)
	imageProvider := parseProviderEnv(logger, "IMAGE_PROVIDER", baseProvider)
	needsQwen := compileProvider == ProviderQwen || imageProvider == ProviderQwen
	needsArk := compileProvider == ProviderArk || imageProvider == ProviderArk

	var missing []string
	required := func(name string) string {
		v := os.Getenv(name)
		if v == "" {
			missing = append(missing, name)
		}
		return v
	}

	cfg := &Config{
		Port:                 envInt("PORT", 8787),
		Host:                 envOr("HOST", "0.0.0.0"),
		CompileProvider:      compileProvider,
		ImageProvider:        imageProvider,
		DashscopeBaseURL:     strings.TrimRight(envOr("DASHSCOPE_BASE_URL", "https://dashscope.aliyuncs.com"), "/"),
		QwenVLModel:          envOr("QWEN_VL_MODEL", "qwen3.7-plus"),
		QwenImageModel:       envOr("QWEN_IMAGE_MODEL", "qwen-image-3.0"),
		ArkBaseURL:           strings.TrimRight(envOr("ARK_BASE_URL", "https://ark.cn-beijing.volces.com/api/v3"), "/"),
		ArkVLModel:           envOr("ARK_VL_MODEL", "doubao-seed-2-0-lite-260428"),
		ArkImageModel:        envOr("ARK_IMAGE_MODEL", "doubao-seedream-5-0-260128"),
		RequestTimeout:       time.Duration(envInt("REQUEST_TIMEOUT_MS", 300000)) * time.Millisecond,
		OssPublicPrefix:      strings.TrimRight(os.Getenv("OSS_PUBLIC_PREFIX"), "/"),
		RateLimitPerMin:      envInt("RATE_LIMIT_PER_MIN", 60),
		AuthRegisterPerMin:   envInt("AUTH_REGISTER_PER_MIN", 10),
		RegisterSecret:       os.Getenv("REGISTER_SECRET"),
		AdminToken:           os.Getenv("ADMIN_TOKEN"),
		AppleClientID:        os.Getenv("APPLE_CLIENT_ID"),
		AuthApplePerMin:      envInt("AUTH_APPLE_PER_MIN", 10),
		GuestFreeTotal:       envInt("GUEST_FREE_TOTAL", 1),
		NewUserPrivilegeDays: envInt("NEW_USER_PRIVILEGE_DAYS", 7),
		NewUserDaily:         envInt("NEW_USER_DAILY", 10),
		GuestDailyCompileCap: envInt("GUEST_DAILY_COMPILE_CAP", 20),
		UserDailyCompileCap:  envInt("USER_DAILY_COMPILE_CAP", 100),
		IAPProducts:          parseIAPProductMap(os.Getenv("IAP_PRODUCT_MAP")),
		IAPEnvironment:       envOr("IAP_ENVIRONMENT", "Production"),
		StaffUserIDs:         parseList(os.Getenv("STAFF_USER_IDS")),
		AssetsDir:            os.Getenv("ASSETS_DIR"),
		DBPath:               envOr("DB_PATH", "./data/variations.db"),
		Oss: OssConfig{
			Region:          normalizeOssRegion(os.Getenv("OSS_REGION")),
			Bucket:          os.Getenv("OSS_BUCKET"),
			AccessKeyID:     os.Getenv("OSS_ACCESS_KEY_ID"),
			AccessKeySecret: os.Getenv("OSS_ACCESS_KEY_SECRET"),
		},
	}

	if needsQwen {
		cfg.DashscopeAPIKey = required("DASHSCOPE_API_KEY")
	} else {
		cfg.DashscopeAPIKey = os.Getenv("DASHSCOPE_API_KEY")
	}
	if needsArk {
		cfg.ArkAPIKey = required("ARK_API_KEY")
	} else {
		cfg.ArkAPIKey = os.Getenv("ARK_API_KEY")
	}

	// 历史变量更名提示：VL_MODEL → QWEN_VL_MODEL
	if os.Getenv("VL_MODEL") != "" && os.Getenv("QWEN_VL_MODEL") == "" {
		logger.Warn("检测到已更名的环境变量 VL_MODEL，请改用 QWEN_VL_MODEL（当前已忽略）")
	}
	if os.Getenv("API_TOKEN") != "" {
		logger.Warn("检测到已废弃的环境变量 API_TOKEN（已改为设备身份令牌鉴权，当前已忽略）")
	}

	if len(missing) > 0 {
		logger.Warn(fmt.Sprintf("缺少环境变量（相关业务接口将不可用）: %s", strings.Join(missing, ", ")))
	}
	compileModel, imageModel := cfg.QwenVLModel, cfg.QwenImageModel
	if cfg.CompileProvider == ProviderArk {
		compileModel = cfg.ArkVLModel
	}
	if cfg.ImageProvider == ProviderArk {
		imageModel = cfg.ArkImageModel
	}
	logger.Info(fmt.Sprintf("模型管线默认: compile=%s image=%s", cfg.CompileProvider, cfg.ImageProvider),
		"compileModel", compileModel, "imageModel", imageModel)
	if cfg.RegisterSecret == "" {
		logger.Warn("未配置 REGISTER_SECRET，设备注册端点将返回 503（无法签发新 token）")
	}
	if cfg.AdminToken != "" {
		logger.Warn("已配置 ADMIN_TOKEN 运维旁路，生产环境建议移除")
	}
	if cfg.AppleClientID == "" {
		logger.Warn("未配置 APPLE_CLIENT_ID，SIWA 登录端点将返回 503")
	}
	if len(cfg.IAPProducts) == 0 {
		logger.Warn("未配置 IAP_PRODUCT_MAP，购买落账端点将返回 503")
	}
	return cfg
}

// parseList 解析逗号分隔列表为集合（STAFF_USER_IDS 等）
func parseList(raw string) map[string]bool {
	out := map[string]bool{}
	for _, item := range strings.Split(raw, ",") {
		if item = strings.TrimSpace(item); item != "" {
			out[item] = true
		}
	}
	return out
}

// parseIAPProductMap 解析 "productID:次数,productID:次数"；非法条目告警跳过
func parseIAPProductMap(raw string) map[string]int {
	out := map[string]int{}
	for _, item := range strings.Split(raw, ",") {
		item = strings.TrimSpace(item)
		if item == "" {
			continue
		}
		kv := strings.Split(item, ":")
		if len(kv) != 2 {
			continue
		}
		n, err := strconv.Atoi(strings.TrimSpace(kv[1]))
		if err != nil || n <= 0 || kv[0] == "" {
			continue
		}
		out[strings.TrimSpace(kv[0])] = n
	}
	return out
}

func envOr(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}
