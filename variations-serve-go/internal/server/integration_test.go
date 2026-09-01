package server_test

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"variations-serve-go/internal/auth"
	"variations-serve-go/internal/config"
	"variations-serve-go/internal/domain/oss"
	"variations-serve-go/internal/domain/skill"
	"variations-serve-go/internal/handlers"
	"variations-serve-go/internal/server"
	"variations-serve-go/internal/store"
)

const testSecret = "test-register-secret"

// testEnv 全量装配：临时 DB + 临时 assets + 全部 handler
type testEnv struct {
	engine    http.Handler
	cfg       *config.Config
	quotaRepo *store.QuotaRepo
	userRepo  *store.UserRepo
}

func newTestEnv(t *testing.T) *testEnv { return newTestEnvWith(t, nil) }

func newTestEnvWith(t *testing.T, mutate func(*config.Config)) *testEnv {
	t.Helper()
	tmp := t.TempDir()

	// 临时 assets：一个 skill + skills-ui.json manual 条目
	assetsDir := filepath.Join(tmp, "assets")
	skillDir := filepath.Join(assetsDir, "skills", "demo-skill")
	for _, d := range []string{skillDir, filepath.Join(skillDir, "references")} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	writeFile := func(path, content string) {
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	writeFile(filepath.Join(skillDir, "SKILL.md"), "---\nname: 演示模版\ndescription: 测试用\n---\n正文")
	writeFile(filepath.Join(skillDir, "references", "style.md"), "风格说明")
	writeFile(filepath.Join(assetsDir, "skills-ui.json"),
		`{"demo-skill":{"manual":{"displayName":"演示","shortDescription":"短描述","size":"3:5","instructionTemplate":[{"label":"主题","placeholder":"如：深夜电台"}]}}}`)
	writeFile(filepath.Join(assetsDir, "pipeline-overrides.json"), `{}`)

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	cfg := &config.Config{
		Port: 0, Host: "127.0.0.1",
		CompileProvider: config.ProviderQwen, ImageProvider: config.ProviderQwen,
		RequestTimeout:  300 * time.Second, // 占位，集成测试不打上游
		RateLimitPerMin: 100, AuthRegisterPerMin: 100, AuthApplePerMin: 100,
		RegisterSecret: testSecret,
		AppleClientID:  "test-client",
		Oss:            config.OssConfig{Region: "cn-hangzhou", Bucket: "my-bucket"},
		DBPath:         filepath.Join(tmp, "test.db"),
		// 配额：次数口径默认值
		GuestFreeTotal: 1, NewUserPrivilegeDays: 7, NewUserDaily: 10,
		GuestDailyCompileCap: 20, UserDailyCompileCap: 100,
		IAPProducts: map[string]int{"test.pack.small": 10},
	}
	if mutate != nil {
		mutate(cfg)
	}

	db, err := store.Open(cfg.DBPath)
	if err != nil {
		t.Fatalf("打开 DB 失败: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	authRepo := store.NewAuthRepo(db)
	userRepo := store.NewUserRepo(db)
	quotaRepo := store.NewQuotaRepo(db)
	assetStore := skill.NewStore(assetsDir, logger)
	accountHandler := handlers.NewAccountHandler(userRepo, quotaRepo, cfg, logger)
	appleVerifier := auth.NewAppleVerifierWithSource("test-client", staticKeySource{}, time.Hour)

	engine := server.BuildRoutes(cfg, logger, authRepo, quotaRepo, userRepo, server.Handlers{
		Register:       auth.NewRegisterHandler(auth.NewHMACGate(cfg.RegisterSecret), authRepo, logger).Handle,
		AppleLogin:     auth.NewAppleLoginHandler(appleVerifier, userRepo, quotaRepo, cfg, logger).Handle,
		Logout:         accountHandler.Logout,
		DeleteAccount:  accountHandler.DeleteAccount,
		Quota:          accountHandler.Quota,
		BillingConfirm: handlers.NewBillingHandler(userRepo, cfg, logger).Confirm,
		Skills:         handlers.NewSkillsHandler(cfg, assetStore).Handle,
		UploadTicket:   handlers.NewUploadTicketHandler(cfg, oss.NewSigner(cfg.Oss)).Handle,
		FileURL:        handlers.NewFileURLHandler(cfg, oss.NewSigner(cfg.Oss)).Handle,
		Compile:        handlers.NewCompileHandler(cfg, assetStore, logger).Handle,
		Image:          handlers.NewImageHandler(cfg, assetStore, logger).Handle,
	})
	return &testEnv{engine: engine, cfg: cfg, quotaRepo: quotaRepo, userRepo: userRepo}
}

func do(t *testing.T, h http.Handler, method, path, body, token string) *httptest.ResponseRecorder {
	t.Helper()
	var reader io.Reader
	if body != "" {
		reader = strings.NewReader(body)
	}
	req := httptest.NewRequest(method, path, reader)
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, req)
	return w
}

func registerToken(t *testing.T, env *testEnv, deviceID string) string {
	t.Helper()
	mac := hmac.New(sha256.New, []byte(testSecret))
	mac.Write([]byte(deviceID))
	proof := hex.EncodeToString(mac.Sum(nil))
	payload, _ := json.Marshal(map[string]string{"deviceId": deviceID, "proof": proof})
	w := do(t, env.engine, "POST", "/api/auth/device", string(payload), "")
	if w.Code != 200 {
		t.Fatalf("设备注册失败: %d %s", w.Code, w.Body.String())
	}
	var res struct {
		Token string `json:"token"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &res); err != nil || res.Token == "" {
		t.Fatalf("注册响应异常: %s", w.Body.String())
	}
	return res.Token
}

func parseErr(t *testing.T, w *httptest.ResponseRecorder) (code, message string) {
	t.Helper()
	var body struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("错误体非法: %s", w.Body.String())
	}
	return body.Code, body.Message
}

// ============================== 基础契约 ==============================

func TestHealthz(t *testing.T) {
	env := newTestEnv(t)
	w := do(t, env.engine, "GET", "/healthz", "", "")
	if w.Code != 200 || !strings.Contains(w.Body.String(), `"ok":true`) {
		t.Fatalf("healthz 异常: %d %s", w.Code, w.Body.String())
	}
}

func TestUnknownRouteAndMethodMismatch(t *testing.T) {
	env := newTestEnv(t)
	token := registerToken(t, env, "dev-route")

	// 未知路径 → 404 NOT_FOUND
	w := do(t, env.engine, "GET", "/api/nope", "", token)
	if w.Code != 404 {
		t.Fatalf("未知路由应 404: %d", w.Code)
	}
	code, message := parseErr(t, w)
	if code != "NOT_FOUND" || !strings.Contains(message, "未知路由：GET /api/nope") {
		t.Fatalf("404 契约异常: %s %s", code, message)
	}

	// 方法不匹配也回 404（Gin NoRoute，与既有客户端契约一致，不允许 405）
	w = do(t, env.engine, "POST", "/api/skills", "{}", token)
	if w.Code != 404 {
		t.Fatalf("方法不匹配应 404（非 405）: %d", w.Code)
	}
}

// ============================== 鉴权 ==============================

func TestAuthFlow(t *testing.T) {
	env := newTestEnv(t)

	// 无 token → 401
	w := do(t, env.engine, "GET", "/api/skills", "", "")
	if w.Code != 401 {
		t.Fatalf("无 token 应 401: %d", w.Code)
	}
	// 伪造 token → 401
	w = do(t, env.engine, "GET", "/api/skills", "", "var_fake-token")
	if w.Code != 401 {
		t.Fatalf("伪造 token 应 401: %d", w.Code)
	}
	// 注册 proof 错误 → 401 REGISTER_DENIED
	w = do(t, env.engine, "POST", "/api/auth/device",
		`{"deviceId":"dev-x","proof":"`+strings.Repeat("0", 64)+`"}`, "")
	if w.Code != 401 {
		t.Fatalf("错误 proof 应 401: %d %s", w.Code, w.Body.String())
	}
	if code, _ := parseErr(t, w); code != "REGISTER_DENIED" {
		t.Fatalf("proof 错误码应为 REGISTER_DENIED: %s", code)
	}
	// 非法 deviceId → 400
	w = do(t, env.engine, "POST", "/api/auth/device", `{"deviceId":"../evil","proof":"x"}`, "")
	if w.Code != 400 {
		t.Fatalf("非法 deviceId 应 400: %d", w.Code)
	}
	// 正路径：注册 → token → 业务可用
	token := registerToken(t, env, "dev-ok")
	w = do(t, env.engine, "GET", "/api/skills", "", token)
	if w.Code != 200 {
		t.Fatalf("合法 token 应 200: %d %s", w.Code, w.Body.String())
	}
}

// ============================== skills：DTO 形状 + ETag/304 ==============================

func TestSkillsContract(t *testing.T) {
	env := newTestEnv(t)
	token := registerToken(t, env, "dev-skills")

	w := do(t, env.engine, "GET", "/api/skills", "", token)
	if w.Code != 200 {
		t.Fatalf("skills 应 200: %d", w.Code)
	}
	var cards []map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &cards); err != nil {
		t.Fatal(err)
	}
	if len(cards) != 1 {
		t.Fatalf("期望 1 张卡片: %d", len(cards))
	}
	card := cards[0]
	// 字段齐全：字符串字段缺省空串，可空字段存在
	for _, f := range []string{"id", "name", "description", "displayName", "shortDescription", "defaultPrompt", "sampleImageUrl", "sampleImageAspect", "size", "instructionTemplate"} {
		if _, ok := card[f]; !ok {
			t.Fatalf("卡片缺少字段 %s", f)
		}
	}
	if card["sampleImageUrl"] != nil {
		t.Fatal("未配置 OSS_PUBLIC_PREFIX 时 sampleImageUrl 应为 null")
	}
	if card["displayName"] != "演示" {
		t.Fatalf("displayName 异常: %v", card["displayName"])
	}
	if strings.Contains(w.Body.String(), "正文") {
		t.Fatal("skills 响应绝不应泄漏 SKILL.md 正文")
	}

	// ETag/304 回环
	etag := w.Header().Get("ETag")
	if etag == "" || !strings.HasPrefix(etag, `W/"`) {
		t.Fatalf("ETag 格式异常: %q", etag)
	}
	req := httptest.NewRequest("GET", "/api/skills", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("If-None-Match", etag)
	w2 := httptest.NewRecorder()
	env.engine.ServeHTTP(w2, req)
	if w2.Code != 304 || w2.Body.Len() != 0 {
		t.Fatalf("If-None-Match 应回 304 空 body: %d len=%d", w2.Code, w2.Body.Len())
	}
	if w2.Header().Get("ETag") == "" {
		t.Fatal("304 应保留 ETag 头")
	}
}

// ============================== 严格类型与请求校验 ==============================

func TestStrictTyping(t *testing.T) {
	env := newTestEnv(t)
	token := registerToken(t, env, "dev-types")

	// seed 传字符串 → 400
	w := do(t, env.engine, "POST", "/api/image", `{"prompt":"x","seed":"7"}`, token)
	if w.Code != 400 {
		t.Fatalf("seed 字符串应 400: %d", w.Code)
	}
	// instruction 传数字 → 400
	w = do(t, env.engine, "POST", "/api/compile",
		`{"inlineSkill":{"body":"b"},"imageUrl":"https://my-bucket.oss-cn-hangzhou.aliyuncs.com/a.jpg","instruction":123}`, token)
	if w.Code != 400 {
		t.Fatalf("instruction 数字应 400: %d", w.Code)
	}
	// 非法 JSON → 400「请求体必须是合法 JSON」
	w = do(t, env.engine, "POST", "/api/image", `{bad json`, token)
	if w.Code != 400 {
		t.Fatalf("非法 JSON 应 400: %d", w.Code)
	}
	if _, msg := parseErr(t, w); msg != "请求体必须是合法 JSON" {
		t.Fatalf("文案异常: %s", msg)
	}
	// compile 互斥校验
	w = do(t, env.engine, "POST", "/api/compile", `{}`, token)
	if w.Code != 400 {
		t.Fatalf("缺参应 400: %d", w.Code)
	}
	// image prompt 必填
	w = do(t, env.engine, "POST", "/api/image", `{}`, token)
	if w.Code != 400 {
		t.Fatalf("缺 prompt 应 400: %d", w.Code)
	}
	// 参考图 4 张 → 400
	w = do(t, env.engine, "POST", "/api/image",
		`{"prompt":"x","imageUrls":["https://my-bucket.oss-cn-hangzhou.aliyuncs.com/a.jpg","https://my-bucket.oss-cn-hangzhou.aliyuncs.com/b.jpg","https://my-bucket.oss-cn-hangzhou.aliyuncs.com/c.jpg","https://my-bucket.oss-cn-hangzhou.aliyuncs.com/d.jpg"]}`, token)
	if w.Code != 400 {
		t.Fatalf("参考图超 3 张应 400: %d", w.Code)
	}
	// 非法域名参考图 → 400
	w = do(t, env.engine, "POST", "/api/image", `{"prompt":"x","imageUrls":["https://evil.com/a.jpg"]}`, token)
	if w.Code != 400 {
		t.Fatalf("非法域名应 400: %d", w.Code)
	}
}

// ============================== upload-ticket：hash 校验 ==============================

func TestUploadTicketValidation(t *testing.T) {
	env := newTestEnv(t)
	token := registerToken(t, env, "dev-ticket")

	validHash := strings.Repeat("a", 64)
	// 非法 ext → 400
	w := do(t, env.engine, "GET", "/api/upload-ticket?ext=gif&hash="+validHash, "", token)
	if w.Code != 400 {
		t.Fatalf("非法 ext 应 400: %d", w.Code)
	}
	// 非法 hash → 400
	w = do(t, env.engine, "GET", "/api/upload-ticket?ext=jpg&hash=ZZZ", "", token)
	if w.Code != 400 {
		t.Fatalf("非法 hash 应 400: %d", w.Code)
	}
	if _, msg := parseErr(t, w); !strings.Contains(msg, "hash") {
		t.Fatalf("hash 文案异常: %s", msg)
	}
	// OSS 未配齐 → 503（测试 cfg 的 AK/SK 为空）
	w = do(t, env.engine, "GET", "/api/upload-ticket?ext=jpg&hash="+validHash, "", token)
	if w.Code != 503 {
		t.Fatalf("OSS 未配齐应 503: %d %s", w.Code, w.Body.String())
	}
}

// ============================== file-url：再次变奏重签校验 ==============================

func TestFileURLValidation(t *testing.T) {
	env := newTestEnv(t)
	token := registerToken(t, env, "dev-file-url")

	validHash := strings.Repeat("b", 64)
	// 非法 ext → 400
	w := do(t, env.engine, "GET", "/api/file-url?ext=gif&hash="+validHash, "", token)
	if w.Code != 400 {
		t.Fatalf("非法 ext 应 400: %d", w.Code)
	}
	// 非法 hash → 400
	w = do(t, env.engine, "GET", "/api/file-url?ext=jpg&hash=ZZZ", "", token)
	if w.Code != 400 {
		t.Fatalf("非法 hash 应 400: %d", w.Code)
	}
	// OSS 未配齐 → 503（探测存在性依赖 OSS；测试 cfg 的 AK/SK 为空）
	w = do(t, env.engine, "GET", "/api/file-url?ext=jpg&hash="+validHash, "", token)
	if w.Code != 503 {
		t.Fatalf("OSS 未配齐应 503: %d %s", w.Code, w.Body.String())
	}
	// 无 token → 401（重签端点同样走设备鉴权）
	w = do(t, env.engine, "GET", "/api/file-url?ext=jpg&hash="+validHash, "", "")
	if w.Code != 401 {
		t.Fatalf("无 token 应 401: %d", w.Code)
	}
}

// ============================== compile：未知 skill → 404 含可用列表 ==============================

func TestCompileUnknownSkill(t *testing.T) {
	env := newTestEnv(t)
	token := registerToken(t, env, "dev-compile")
	w := do(t, env.engine, "POST", "/api/compile",
		`{"skillId":"no-such-skill","imageUrl":"https://my-bucket.oss-cn-hangzhou.aliyuncs.com/a.jpg"}`, token)
	if w.Code != 404 {
		t.Fatalf("未知 skill 应 404: %d %s", w.Code, w.Body.String())
	}
	if _, msg := parseErr(t, w); !strings.Contains(msg, "可用") {
		t.Fatalf("404 message 应含可用列表: %s", msg)
	}
}

// ============================== 请求体上限 ==============================

func TestBodyLimit(t *testing.T) {
	env := newTestEnv(t)
	token := registerToken(t, env, "dev-limit")
	big := `{"prompt":"` + strings.Repeat("x", 1024*1024+100) + `"}`
	w := do(t, env.engine, "POST", "/api/image", big, token)
	if w.Code != 413 {
		t.Fatalf("超 1MB 应 413: %d", w.Code)
	}
	if code, _ := parseErr(t, w); code != "BODY_TOO_LARGE" {
		t.Fatalf("错误码应为 BODY_TOO_LARGE: %s", code)
	}
}
