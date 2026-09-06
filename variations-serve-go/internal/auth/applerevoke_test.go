package auth

// Apple 授权撤销客户端单测：client_secret 声明（ES256/kid/iss/sub/aud）、
// authorizationCode 换 refresh_token、撤销表单契约、未配置密钥时的降级语义。
// 端点根注入本地 httptest，不打 Apple 真服务。

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/golang-jwt/jwt/v5"
)

// testP8PEM 生成一份 PKCS#8 EC 私钥 PEM（形态与门户下载的 .p8 一致）
func testP8PEM(t *testing.T) (string, *ecdsa.PrivateKey) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("生成测试密钥失败: %v", err)
	}
	der, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatalf("编码 PKCS#8 失败: %v", err)
	}
	return string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})), key
}

// appleStub 记录收到的表单，按路径返回预设响应
type appleStub struct {
	server *httptest.Server
	forms  map[string]url.Values
}

func newAppleStub(t *testing.T, tokenStatus int, tokenBody string) *appleStub {
	t.Helper()
	stub := &appleStub{forms: map[string]url.Values{}}
	stub.server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseForm(); err != nil {
			t.Errorf("解析表单失败: %v", err)
		}
		stub.forms[r.URL.Path] = r.PostForm
		if r.Header.Get("Content-Type") != "application/x-www-form-urlencoded" {
			t.Errorf("Content-Type 应为表单: %s", r.Header.Get("Content-Type"))
		}
		switch r.URL.Path {
		case "/auth/token":
			w.WriteHeader(tokenStatus)
			_, _ = w.Write([]byte(tokenBody))
		case "/auth/revoke":
			w.WriteHeader(200)
		default:
			w.WriteHeader(404)
		}
	}))
	t.Cleanup(stub.server.Close)
	return stub
}

func newStubClient(t *testing.T, stub *appleStub) (*AppleTokenClient, *ecdsa.PrivateKey) {
	t.Helper()
	keyPEM, key := testP8PEM(t)
	client, err := newAppleTokenClientWithBase("cn.ifable.Variations", "TEAM123456", "KEY7890", keyPEM, stub.server.URL)
	if err != nil {
		t.Fatalf("构造撤销客户端失败: %v", err)
	}
	if client == nil {
		t.Fatal("配置完整时不应返回 nil 客户端")
	}
	return client, key
}

func TestExchangeCodeAndClientSecretClaims(t *testing.T) {
	stub := newAppleStub(t, 200, `{"refresh_token":"rt_abc","access_token":"at"}`)
	client, key := newStubClient(t, stub)

	refresh, err := client.ExchangeCode(context.Background(), "code_xyz")
	if err != nil {
		t.Fatalf("换取 refresh_token 应成功: %v", err)
	}
	if refresh != "rt_abc" {
		t.Fatalf("refresh_token 应为 rt_abc: %s", refresh)
	}

	form := stub.forms["/auth/token"]
	if form.Get("grant_type") != "authorization_code" || form.Get("code") != "code_xyz" {
		t.Fatalf("换取表单契约异常: %v", form)
	}
	if form.Get("client_id") != "cn.ifable.Variations" {
		t.Fatalf("client_id 应为 bundle id: %s", form.Get("client_id"))
	}

	// client_secret 必须是可验签的 ES256 JWT，且声明符合 Apple 约定
	parsed, err := jwt.Parse(form.Get("client_secret"), func(*jwt.Token) (any, error) {
		return &key.PublicKey, nil
	}, jwt.WithValidMethods([]string{"ES256"}),
		jwt.WithIssuer("TEAM123456"),
		jwt.WithAudience("https://appleid.apple.com"))
	if err != nil {
		t.Fatalf("client_secret 应可用私钥对应公钥验签: %v", err)
	}
	if parsed.Header["kid"] != "KEY7890" {
		t.Fatalf("client_secret 头部 kid 应为 KEY7890: %v", parsed.Header["kid"])
	}
	sub, err := parsed.Claims.GetSubject()
	if err != nil || sub != "cn.ifable.Variations" {
		t.Fatalf("client_secret sub 应为 client_id: %s (%v)", sub, err)
	}
}

func TestRevokeSendsRefreshTokenHint(t *testing.T) {
	stub := newAppleStub(t, 200, `{}`)
	client, _ := newStubClient(t, stub)

	if err := client.Revoke(context.Background(), "rt_abc"); err != nil {
		t.Fatalf("撤销应成功: %v", err)
	}
	form := stub.forms["/auth/revoke"]
	if form.Get("token") != "rt_abc" || form.Get("token_type_hint") != "refresh_token" {
		t.Fatalf("撤销表单契约异常: %v", form)
	}
}

// Apple 侧报错（如 invalid_client）必须带进错误信息，否则线上只能看到裸状态码
func TestExchangeCodeSurfacesAppleError(t *testing.T) {
	stub := newAppleStub(t, 400, `{"error":"invalid_client"}`)
	client, _ := newStubClient(t, stub)

	_, err := client.ExchangeCode(context.Background(), "code_xyz")
	if err == nil {
		t.Fatal("Apple 返回 400 时应报错")
	}
	if got := err.Error(); !strings.Contains(got, "invalid_client") {
		t.Fatalf("错误信息应含 Apple error 字段: %s", got)
	}
}

// 未配置私钥 → nil 客户端：注销仍可本地完成，方法返回 ErrRevokeNotConfigured 供调用方告警
func TestNilClientReportsNotConfigured(t *testing.T) {
	client, err := NewAppleTokenClient("cn.ifable.Variations", "TEAM123456", "KEY7890", "")
	if err != nil || client != nil {
		t.Fatalf("缺私钥应返回 (nil, nil): %v %v", client, err)
	}
	if err := client.Revoke(context.Background(), "rt"); !errors.Is(err, ErrRevokeNotConfigured) {
		t.Fatalf("nil 客户端撤销应报未配置: %v", err)
	}
	if _, err := client.ExchangeCode(context.Background(), "code"); !errors.Is(err, ErrRevokeNotConfigured) {
		t.Fatalf("nil 客户端换取应报未配置: %v", err)
	}
}

// 有私钥但缺 TeamID/KeyID 属配置写错，必须启动即报错而非静默关闭撤销
func TestPartialConfigIsError(t *testing.T) {
	keyPEM, _ := testP8PEM(t)
	if _, err := NewAppleTokenClient("cn.ifable.Variations", "", "KEY7890", keyPEM); err == nil {
		t.Fatal("缺 APPLE_TEAM_ID 应报错")
	}
	if _, err := NewAppleTokenClient("cn.ifable.Variations", "TEAM123456", "KEY7890", "not-a-pem"); err == nil {
		t.Fatal("私钥非 PEM 应报错")
	}
}
