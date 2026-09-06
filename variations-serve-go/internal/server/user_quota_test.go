package server_test

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"variations-serve-go/internal/auth"
	"variations-serve-go/internal/config"
	"variations-serve-go/internal/store"
)

// ============================== SIWA 测试基建 ==============================

var testRSAKey = func() *rsa.PrivateKey {
	k, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		panic(err)
	}
	return k
}()

// staticKeySource 注入式 JWKS：本地 RSA 公钥，不打 Apple 真服务
type staticKeySource struct{}

func (staticKeySource) Fetch(context.Context) (map[string]*rsa.PublicKey, error) {
	return map[string]*rsa.PublicKey{"test-kid": &testRSAKey.PublicKey}, nil
}

// signAppleToken 伪造 Apple identityToken（iss/aud/kid 与验签器约定一致）
func signAppleToken(t *testing.T, sub, email string) string {
	return signAppleTokenWithNonce(t, sub, email, "")
}

// signAppleTokenWithNonce nonceDigest 非空时写入 nonce claim（模拟客户端设了 request.nonce）
func signAppleTokenWithNonce(t *testing.T, sub, email, nonceDigest string) string {
	t.Helper()
	claims := jwt.MapClaims{
		"sub":   sub,
		"iss":   "https://appleid.apple.com",
		"aud":   "test-client",
		"email": email,
		"exp":   time.Now().Add(time.Hour).Unix(),
		"iat":   time.Now().Unix(),
	}
	if nonceDigest != "" {
		claims["nonce"] = nonceDigest
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	tok.Header["kid"] = "test-kid"
	signed, err := tok.SignedString(testRSAKey)
	if err != nil {
		t.Fatalf("签名测试 token 失败: %v", err)
	}
	return signed
}

func appleLogin(t *testing.T, env *testEnv, identityToken string) (token string, body map[string]any) {
	t.Helper()
	payload, _ := json.Marshal(map[string]string{"identityToken": identityToken, "fullName": "常 君豪"})
	w := do(t, env.engine, "POST", "/api/auth/apple", string(payload), "")
	if w.Code != 200 {
		t.Fatalf("SIWA 登录应 200: %d %s", w.Code, w.Body.String())
	}
	var res struct {
		Token string         `json:"token"`
		Quota map[string]any `json:"quota"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &res); err != nil || res.Token == "" {
		t.Fatalf("登录响应异常: %s", w.Body.String())
	}
	if !strings.HasPrefix(res.Token, "var_u_") {
		t.Fatalf("会话令牌应为 var_u_ 前缀: %s", res.Token)
	}
	return res.Token, res.Quota
}

// ============================== SIWA 登录 → 配额 → 注销 ==============================

func TestAppleLoginQuotaAndDelete(t *testing.T) {
	env := newTestEnv(t)

	token, quota := appleLogin(t, env, signAppleToken(t, "apple-sub-1", "relay@privaterelay.appleid.com"))
	// 对外口径为次数：新用户特权每日 10 次
	priv, _ := quota["privilege"].(map[string]any)
	if quota["tier"] != "user" || priv == nil || priv["limitToday"] != float64(10) {
		t.Fatalf("登录配额应为 user/特权每日 10 次: %v", quota)
	}

	// 会话令牌可访问业务与配额端点
	w := do(t, env.engine, "GET", "/api/quota", "", token)
	if w.Code != 200 {
		t.Fatalf("quota 应 200: %d %s", w.Code, w.Body.String())
	}
	var q map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &q); err != nil || q["tier"] != "user" {
		t.Fatalf("quota tier 应为 user: %s", w.Body.String())
	}

	// 再次登录（另一台设备）：旧令牌必须仍然可用——iPhone 与 iPad 需同时在线
	token2, _ := appleLogin(t, env, signAppleToken(t, "apple-sub-1", "relay@privaterelay.appleid.com"))
	if w = do(t, env.engine, "GET", "/api/quota", "", token); w.Code != 200 {
		t.Fatalf("新设备登录不得踢下旧设备: %d", w.Code)
	}
	if w = do(t, env.engine, "GET", "/api/quota", "", token2); w.Code != 200 {
		t.Fatalf("新令牌应可用: %d", w.Code)
	}

	// 退出登录只影响当前设备，另一台仍在线
	if w = do(t, env.engine, "POST", "/api/auth/logout", "", token); w.Code != 200 {
		t.Fatalf("退出应 200: %d", w.Code)
	}
	if w = do(t, env.engine, "GET", "/api/quota", "", token); w.Code != 401 {
		t.Fatalf("退出后本设备令牌应 401: %d", w.Code)
	}
	if w = do(t, env.engine, "GET", "/api/quota", "", token2); w.Code != 200 {
		t.Fatalf("单设备退出不得踢下其他设备: %d", w.Code)
	}

	// 注销账号：全部设备令牌失效、个人信息被清
	w = do(t, env.engine, "POST", "/api/account/delete", "", token2)
	if w.Code != 200 {
		t.Fatalf("注销应 200: %d %s", w.Code, w.Body.String())
	}
	w = do(t, env.engine, "GET", "/api/quota", "", token2)
	if w.Code != 401 {
		t.Fatalf("注销后会话令牌应 401: %d", w.Code)
	}
	deleted, err := env.userRepo.GetUser(context.Background(), "apple-sub-1")
	if err != nil {
		t.Fatalf("读取已注销用户失败: %v", err)
	}
	if deleted.Email != "" || deleted.FullName != "" {
		t.Fatalf("注销应清除邮箱与昵称: %+v", deleted)
	}
}

// 注销后同一 Apple ID 重新登录必须能复活（永久锁死会直接阻死审核），
// 但 created_at 不重置——否则「注销→重登」可反复刷新用户 7 日特权；已购次数也不能丢
func TestDeletedAccountRevivesOnRelogin(t *testing.T) {
	env := newTestEnv(t)
	ctx := context.Background()

	token, _ := appleLogin(t, env, signAppleToken(t, "apple-sub-revive", "a@b.c"))
	if _, _, err := env.userRepo.CreditPurchase(ctx, "tx-1", "apple-sub-revive", "test.pack.small", 10); err != nil {
		t.Fatalf("预置已购次数失败: %v", err)
	}
	before, err := env.userRepo.CreatedAt(ctx, "apple-sub-revive")
	if err != nil {
		t.Fatalf("读取注册时间失败: %v", err)
	}

	if w := do(t, env.engine, "POST", "/api/account/delete", "", token); w.Code != 200 {
		t.Fatalf("注销应 200: %d %s", w.Code, w.Body.String())
	}

	// 重新登录：200 而非 403，且新会话可用
	reborn, quota := appleLogin(t, env, signAppleToken(t, "apple-sub-revive", "a@b.c"))
	if w := do(t, env.engine, "GET", "/api/quota", "", reborn); w.Code != 200 {
		t.Fatalf("复活后会话应可用: %d", w.Code)
	}
	paid, _ := quota["paid"].(map[string]any)
	if paid == nil || paid["remaining"] != float64(10) {
		t.Fatalf("复活后已购次数应留存 10: %v", quota)
	}
	after, err := env.userRepo.CreatedAt(ctx, "apple-sub-revive")
	if err != nil {
		t.Fatalf("读取注册时间失败: %v", err)
	}
	if !after.Equal(before) {
		t.Fatalf("复活不得重置 created_at（否则特权窗口可刷）: %v → %v", before, after)
	}
}

// Staff 白名单配额口径：登录响应与 GET /api/quota 必须同为 staff
// （登录响应漏覆写会让客户端「我的」页权益行登录后短暂误显 user 态）
func TestStaffQuotaTierConsistentAcrossLoginAndQuota(t *testing.T) {
	env := newTestEnvWith(t, func(c *config.Config) {
		c.StaffUserIDs = map[string]bool{"apple-sub-staff": true}
	})

	token, quota := appleLogin(t, env, signAppleToken(t, "apple-sub-staff", "staff@privaterelay.appleid.com"))
	if quota["tier"] != "staff" {
		t.Fatalf("登录配额 tier 应为 staff: %v", quota)
	}

	w := do(t, env.engine, "GET", "/api/quota", "", token)
	if w.Code != 200 {
		t.Fatalf("quota 应 200: %d %s", w.Code, w.Body.String())
	}
	var q map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &q); err != nil || q["tier"] != "staff" {
		t.Fatalf("quota tier 应为 staff: %s", w.Body.String())
	}
}

func TestAppleLoginInvalidToken(t *testing.T) {
	env := newTestEnv(t)

	// 垃圾 token → 401 APPLE_TOKEN_INVALID
	w := do(t, env.engine, "POST", "/api/auth/apple", `{"identityToken":"garbage"}`, "")
	if w.Code != 401 {
		t.Fatalf("垃圾 token 应 401: %d", w.Code)
	}
	if code, _ := parseErr(t, w); code != "APPLE_TOKEN_INVALID" {
		t.Fatalf("错误码应为 APPLE_TOKEN_INVALID: %s", code)
	}
	// aud 不符 → 401
	w = do(t, env.engine, "POST", "/api/auth/apple",
		`{"identityToken":"`+signAppleTokenWithAud(t, "apple-sub-2", "wrong-client")+`"}`, "")
	if w.Code != 401 {
		t.Fatalf("aud 不符应 401: %d", w.Code)
	}
	// 缺 identityToken → 400
	w = do(t, env.engine, "POST", "/api/auth/apple", `{}`, "")
	if w.Code != 400 {
		t.Fatalf("缺参应 400: %d", w.Code)
	}
}

// nonce 防重放：token 带 nonce claim 时，请求必须携带能对上摘要的 raw nonce。
// 尤其需要钉住「不传 nonce 字段即可绕过」这个绕过面。
func TestAppleLoginNonceReplayProtection(t *testing.T) {
	env := newTestEnv(t)
	raw := "raw-nonce-abc123"
	token := signAppleTokenWithNonce(t, "apple-sub-nonce", "a@b.c", auth.NonceDigest(raw))

	login := func(body map[string]string) int {
		payload, _ := json.Marshal(body)
		return do(t, env.engine, "POST", "/api/auth/apple", string(payload), "").Code
	}

	// 缺 nonce 字段 → 401（不可省略绕过）
	if code := login(map[string]string{"identityToken": token}); code != 401 {
		t.Fatalf("token 带 nonce 而请求不传应 401: %d", code)
	}
	// nonce 不匹配 → 401
	if code := login(map[string]string{"identityToken": token, "nonce": "wrong-nonce"}); code != 401 {
		t.Fatalf("nonce 不匹配应 401: %d", code)
	}
	// nonce 匹配 → 200
	if code := login(map[string]string{"identityToken": token, "nonce": raw}); code != 200 {
		t.Fatalf("nonce 匹配应 200: %d", code)
	}
}

// 过渡兼容：旧版客户端不设 request.nonce，token 无 nonce claim，不传 nonce 仍应能登录
// （否则发版当日存量安装全部登不上）
func TestAppleLoginWithoutNonceStillWorks(t *testing.T) {
	env := newTestEnv(t)
	payload, _ := json.Marshal(map[string]string{
		"identityToken": signAppleToken(t, "apple-sub-legacy", "a@b.c"),
	})
	if w := do(t, env.engine, "POST", "/api/auth/apple", string(payload), ""); w.Code != 200 {
		t.Fatalf("旧版客户端（无 nonce）应仍可登录: %d %s", w.Code, w.Body.String())
	}
}

func signAppleTokenWithAud(t *testing.T, sub, aud string) string {
	t.Helper()
	claims := jwt.MapClaims{
		"sub": sub, "iss": "https://appleid.apple.com", "aud": aud,
		"exp": time.Now().Add(time.Hour).Unix(), "iat": time.Now().Unix(),
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	tok.Header["kid"] = "test-kid"
	signed, err := tok.SignedString(testRSAKey)
	if err != nil {
		t.Fatal(err)
	}
	return signed
}

// ============================== 退出登录 ==============================

func TestLogoutFlow(t *testing.T) {
	env := newTestEnv(t)
	token, _ := appleLogin(t, env, signAppleToken(t, "apple-sub-3", "a@b.c"))

	w := do(t, env.engine, "POST", "/api/auth/logout", "", token)
	if w.Code != 200 {
		t.Fatalf("退出应 200: %d", w.Code)
	}
	w = do(t, env.engine, "GET", "/api/quota", "", token)
	if w.Code != 401 {
		t.Fatalf("退出后令牌应 401: %d", w.Code)
	}

	// 游客会话退出 → 400
	guest := registerToken(t, env, "dev-logout")
	w = do(t, env.engine, "POST", "/api/auth/logout", "", guest)
	if w.Code != 400 {
		t.Fatalf("游客退出应 400: %d", w.Code)
	}
}

// ============================== 配额：游客耗尽 / 编译防刷 ==============================

func TestImageQuotaExceeded(t *testing.T) {
	env := newTestEnv(t)
	guest := registerToken(t, env, "dev-quota")

	// 预扣满游客终身体验额度（1 次）
	if err := env.quotaRepo.Deduct(context.Background(), "device:dev-quota", store.LifetimeBucket, 1); err != nil {
		t.Fatalf("预扣失败: %v", err)
	}
	w := do(t, env.engine, "POST", "/api/image", `{"prompt":"x"}`, guest)
	if w.Code != 429 {
		t.Fatalf("配额耗尽应 429: %d %s", w.Code, w.Body.String())
	}
	var body struct {
		Code  string `json:"code"`
		Quota struct {
			Tier  string `json:"tier"`
			Trial struct {
				Remaining int `json:"remaining"`
				Limit     int `json:"limit"`
			} `json:"trial"`
		} `json:"quota"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil || body.Code != "QUOTA_EXCEEDED" {
		t.Fatalf("429 契约异常: %s", w.Body.String())
	}
	if body.Quota.Tier != "guest" || body.Quota.Trial.Remaining != 0 || body.Quota.Trial.Limit != 1 {
		t.Fatalf("quota 详情异常: %+v", body.Quota)
	}
}

func TestCompileCapExceeded(t *testing.T) {
	env := newTestEnvWith(t, func(c *config.Config) { c.GuestDailyCompileCap = 2 })
	guest := registerToken(t, env, "dev-cap")

	// 预扣满编译上限（4xx/5xx 会退还，故直接预扣模拟当日已用满）
	bucket := env.quotaRepo.TodayBucket()
	for i := 0; i < 2; i++ {
		if err := env.quotaRepo.Deduct(context.Background(), "device:dev-cap:compile", bucket, 2); err != nil {
			t.Fatalf("预扣失败: %v", err)
		}
	}
	w := do(t, env.engine, "POST", "/api/compile",
		`{"skillId":"no-such","imageUrl":"https://my-bucket.oss-cn-hangzhou.aliyuncs.com/a.jpg"}`, guest)
	if w.Code != 429 {
		t.Fatalf("编译防刷上限应 429: %d %s", w.Code, w.Body.String())
	}
	if code, _ := parseErr(t, w); code != "QUOTA_EXCEEDED" {
		t.Fatalf("错误码应为 QUOTA_EXCEEDED: %s", code)
	}
}

// ============================== 游客配额查询 ==============================

func TestGuestQuotaEndpoint(t *testing.T) {
	env := newTestEnv(t)
	guest := registerToken(t, env, "dev-guest-quota")

	w := do(t, env.engine, "GET", "/api/quota", "", guest)
	if w.Code != 200 {
		t.Fatalf("游客 quota 应 200: %d", w.Code)
	}
	var q struct {
		Tier  string `json:"tier"`
		Trial struct {
			Remaining int `json:"remaining"`
			Limit     int `json:"limit"`
		} `json:"trial"`
		ResetsAt string `json:"resetsAt"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &q); err != nil {
		t.Fatal(err)
	}
	if q.Tier != "guest" || q.Trial.Limit != 1 || q.Trial.Remaining != 1 || q.ResetsAt == "" {
		t.Fatalf("游客配额摘要异常: %+v", q)
	}
}
