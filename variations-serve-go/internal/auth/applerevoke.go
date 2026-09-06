package auth

// Apple 授权撤销（App Store Guideline 5.1.1(v)）：登录时用 authorizationCode 换 refresh_token 存库，
// 注销账号时调 POST /auth/revoke 撤销用户与本 App 的 Apple 授权。
// client_secret 为 ES256 JWT（iss=TeamID、sub=ClientID、aud=https://appleid.apple.com），
// 私钥取自开发者门户「Sign in with Apple」Key 的 .p8（PKCS#8 EC P-256）。
// 密钥三件套未配置时 AppleTokenClient 为 nil，各方法返回 ErrRevokeNotConfigured（注销仍可本地完成，调用方告警）。

import (
	"context"
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	appleAuthBaseURL = "https://appleid.apple.com"
	// appleClientSecretTTL client_secret JWT 有效期（Apple 上限 6 个月，取短时效即用即签）
	appleClientSecretTTL = 5 * time.Minute
)

// ErrRevokeNotConfigured 未配置 SIWA 撤销密钥（APPLE_TEAM_ID / APPLE_KEY_ID / 私钥）
var ErrRevokeNotConfigured = errors.New("未配置 Apple 授权撤销密钥")

// AppleTokenClient Apple 授权服务客户端（换 refresh_token / 撤销授权）
type AppleTokenClient struct {
	clientID string
	teamID   string
	keyID    string
	key      *ecdsa.PrivateKey
	baseURL  string
	client   *http.Client
}

// NewAppleTokenClient 构造撤销客户端；四项配置缺一即返回 (nil, nil)——撤销能力关闭但服务照常启动。
// 私钥存在却解析失败返回 error：配置写错必须在启动时可见，不静默降级。
func NewAppleTokenClient(clientID, teamID, keyID, privateKeyPEM string) (*AppleTokenClient, error) {
	return newAppleTokenClient(clientID, teamID, keyID, privateKeyPEM, appleAuthBaseURL)
}

// newAppleTokenClientWithBase 测试注入：端点根指向本地 httptest
func newAppleTokenClientWithBase(clientID, teamID, keyID, privateKeyPEM, baseURL string) (*AppleTokenClient, error) {
	return newAppleTokenClient(clientID, teamID, keyID, privateKeyPEM, baseURL)
}

func newAppleTokenClient(clientID, teamID, keyID, privateKeyPEM, baseURL string) (*AppleTokenClient, error) {
	if privateKeyPEM == "" {
		return nil, nil
	}
	if clientID == "" || teamID == "" || keyID == "" {
		return nil, fmt.Errorf("已配置 SIWA 私钥但缺少 APPLE_CLIENT_ID / APPLE_TEAM_ID / APPLE_KEY_ID")
	}
	key, err := parseApplePrivateKey(privateKeyPEM)
	if err != nil {
		return nil, err
	}
	base, err := url.Parse(strings.TrimRight(baseURL, "/"))
	if err != nil || base.Host == "" {
		return nil, fmt.Errorf("Apple 授权端点根非法: %s", baseURL)
	}
	return &AppleTokenClient{
		clientID: clientID,
		teamID:   teamID,
		keyID:    keyID,
		key:      key,
		baseURL:  base.String(),
		client: &http.Client{
			Timeout: 10 * time.Second,
			// 端点根为编译期常量（无用户输入，无 SSRF 面）；额外限制重定向不得跳出该主机，与 apple.go 同口径
			CheckRedirect: func(req *http.Request, via []*http.Request) error {
				if req.URL.Host != base.Host || req.URL.Scheme != base.Scheme {
					return http.ErrUseLastResponse
				}
				return nil
			},
		},
	}, nil
}

// parseApplePrivateKey 解析 .p8（PKCS#8 EC）为 ECDSA 私钥
func parseApplePrivateKey(privateKeyPEM string) (*ecdsa.PrivateKey, error) {
	block, _ := pem.Decode([]byte(strings.TrimSpace(privateKeyPEM)))
	if block == nil {
		return nil, fmt.Errorf("SIWA 私钥不是合法 PEM（应为门户下载的 .p8 原文）")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("解析 SIWA 私钥失败: %w", err)
	}
	key, ok := parsed.(*ecdsa.PrivateKey)
	if !ok {
		return nil, fmt.Errorf("SIWA 私钥类型应为 ECDSA，实际 %T", parsed)
	}
	return key, nil
}

// ExchangeCode 用一次性 authorizationCode（5 分钟内有效）换 refresh_token
func (c *AppleTokenClient) ExchangeCode(ctx context.Context, code string) (string, error) {
	if c == nil {
		return "", ErrRevokeNotConfigured
	}
	secret, err := c.clientSecret()
	if err != nil {
		return "", err
	}
	body, err := c.post(ctx, "/auth/token", url.Values{
		"client_id":     {c.clientID},
		"client_secret": {secret},
		"code":          {code},
		"grant_type":    {"authorization_code"},
	})
	if err != nil {
		return "", err
	}
	var reply struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.Unmarshal(body, &reply); err != nil {
		return "", fmt.Errorf("解析 Apple token 响应失败: %w", err)
	}
	if reply.RefreshToken == "" {
		return "", fmt.Errorf("Apple token 响应未返回 refresh_token")
	}
	return reply.RefreshToken, nil
}

// Revoke 撤销用户与本 App 的 Apple 授权（注销账号必须调用；Apple 成功时返回 200 空体）
func (c *AppleTokenClient) Revoke(ctx context.Context, refreshToken string) error {
	if c == nil {
		return ErrRevokeNotConfigured
	}
	secret, err := c.clientSecret()
	if err != nil {
		return err
	}
	_, err = c.post(ctx, "/auth/revoke", url.Values{
		"client_id":       {c.clientID},
		"client_secret":   {secret},
		"token":           {refreshToken},
		"token_type_hint": {"refresh_token"},
	})
	return err
}

// clientSecret 即用即签的 ES256 JWT（kid 置于头部，Apple 据此选公钥）
func (c *AppleTokenClient) clientSecret() (string, error) {
	now := time.Now()
	token := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.MapClaims{
		"iss": c.teamID,
		"iat": now.Unix(),
		"exp": now.Add(appleClientSecretTTL).Unix(),
		"aud": appleAuthBaseURL,
		"sub": c.clientID,
	})
	token.Header["kid"] = c.keyID
	signed, err := token.SignedString(c.key)
	if err != nil {
		return "", fmt.Errorf("签发 Apple client_secret 失败: %w", err)
	}
	return signed, nil
}

// post 表单请求 Apple 授权端点；非 2xx 时把 Apple 的 error 字段带进错误信息（便于排查 invalid_client 等）
func (c *AppleTokenClient) post(ctx context.Context, path string, form url.Values) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+path, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, fmt.Errorf("构造 Apple 请求失败: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := c.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("请求 Apple %s 失败: %w", path, err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, fmt.Errorf("读取 Apple %s 响应失败: %w", path, err)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		var apiErr struct {
			Error string `json:"error"`
		}
		_ = json.Unmarshal(body, &apiErr)
		if apiErr.Error != "" {
			return nil, fmt.Errorf("Apple %s 返回 %d: %s", path, resp.StatusCode, apiErr.Error)
		}
		return nil, fmt.Errorf("Apple %s 返回 %d", path, resp.StatusCode)
	}
	return body, nil
}
