package auth

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Apple identityToken 验签：拉取 Apple JWKS 缓存 24h；kid 未命中时强制刷新重试一次（兼容密钥轮换）。
// 校验项：RS256、iss=https://appleid.apple.com、aud=APPLE_CLIENT_ID、exp/iat；nonce 本期不强制。

const appleJWKSURL = "https://appleid.apple.com/auth/keys"

// ErrAppleTokenInvalid 验签失败 → 401 APPLE_TOKEN_INVALID
var ErrAppleTokenInvalid = errors.New("Apple identityToken 校验失败")

// errKeyUnknown kid 不在缓存（触发强制刷新重试）
var errKeyUnknown = errors.New("kid 不在密钥缓存")

// AppleIdentity 验签通过后提取的声明
type AppleIdentity struct {
	Sub            string
	Email          string
	IsPrivateEmail bool
}

type jwkKey struct {
	Kty string `json:"kty"`
	Kid string `json:"kid"`
	N   string `json:"n"`
	E   string `json:"e"`
}

type jwkSet struct {
	Keys []jwkKey `json:"keys"`
}

// KeySource JWKS 来源抽象：生产走 Apple 端点，测试注入本地 RSA
type KeySource interface {
	Fetch(ctx context.Context) (map[string]*rsa.PublicKey, error)
}

type httpKeySource struct{ client *http.Client }

func (s httpKeySource) Fetch(ctx context.Context) (map[string]*rsa.PublicKey, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, appleJWKSURL, nil)
	if err != nil {
		return nil, fmt.Errorf("构造 JWKS 请求失败: %w", err)
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("拉取 JWKS 失败: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("拉取 JWKS 状态异常: %d", resp.StatusCode)
	}
	var set jwkSet
	if err := json.NewDecoder(resp.Body).Decode(&set); err != nil {
		return nil, fmt.Errorf("解析 JWKS 失败: %w", err)
	}
	keys := make(map[string]*rsa.PublicKey, len(set.Keys))
	for _, k := range set.Keys {
		if k.Kty != "RSA" || k.Kid == "" {
			continue
		}
		nb, err := base64.RawURLEncoding.DecodeString(k.N)
		if err != nil {
			continue
		}
		eb, err := base64.RawURLEncoding.DecodeString(k.E)
		if err != nil {
			continue
		}
		keys[k.Kid] = &rsa.PublicKey{
			N: new(big.Int).SetBytes(nb),
			E: int(new(big.Int).SetBytes(eb).Int64()),
		}
	}
	return keys, nil
}

// AppleVerifier SIWA identityToken 验签器（JWKS 内存缓存 + 失败延用旧缓存）
type AppleVerifier struct {
	clientID string
	src      KeySource
	ttl      time.Duration

	mu        sync.RWMutex
	keys      map[string]*rsa.PublicKey
	fetchedAt time.Time
}

func NewAppleVerifier(clientID string) *AppleVerifier {
	return &AppleVerifier{
		clientID: clientID,
		// 端点为编译期常量（无用户输入，无 SSRF 面）；额外限制重定向仅允许同主机 HTTPS
		src: httpKeySource{client: &http.Client{
			Timeout: 10 * time.Second,
			CheckRedirect: func(req *http.Request, via []*http.Request) error {
				if req.URL.Host != "appleid.apple.com" || req.URL.Scheme != "https" {
					return http.ErrUseLastResponse
				}
				return nil
			},
		}},
		ttl: 24 * time.Hour,
	}
}

// NewAppleVerifierWithSource 测试注入：本地 JWKS + 自定义缓存时长
func NewAppleVerifierWithSource(clientID string, src KeySource, ttl time.Duration) *AppleVerifier {
	return &AppleVerifier{clientID: clientID, src: src, ttl: ttl}
}

// Verify 验签入口：kid 未命中强制刷新重试一次
func (v *AppleVerifier) Verify(ctx context.Context, identityToken string) (*AppleIdentity, error) {
	identity, err := v.parse(ctx, identityToken, false)
	if err != nil && errors.Is(err, errKeyUnknown) {
		return v.parse(ctx, identityToken, true)
	}
	return identity, err
}

func (v *AppleVerifier) parse(ctx context.Context, token string, forceRefresh bool) (*AppleIdentity, error) {
	var (
		keys map[string]*rsa.PublicKey
		err  error
	)
	if forceRefresh {
		keys, err = v.refresh(ctx, true)
	} else {
		keys, err = v.refresh(ctx, false)
	}
	if err != nil {
		return nil, err
	}
	parser := jwt.NewParser(
		jwt.WithValidMethods([]string{"RS256"}),
		jwt.WithIssuer("https://appleid.apple.com"),
		jwt.WithAudience(v.clientID),
	)
	claims := jwt.MapClaims{}
	if _, err := parser.ParseWithClaims(token, claims, func(t *jwt.Token) (any, error) {
		kid, _ := t.Header["kid"].(string)
		if k, ok := keys[kid]; ok {
			return k, nil
		}
		return nil, errKeyUnknown
	}); err != nil {
		if errors.Is(err, errKeyUnknown) {
			return nil, err
		}
		return nil, fmt.Errorf("%w: %v", ErrAppleTokenInvalid, err)
	}
	sub, _ := claims["sub"].(string)
	if sub == "" {
		return nil, ErrAppleTokenInvalid
	}
	email, _ := claims["email"].(string)
	var isPrivate bool
	switch p := claims["is_private_email"].(type) {
	case bool:
		isPrivate = p
	case string:
		isPrivate = p == "true"
	}
	return &AppleIdentity{Sub: sub, Email: email, IsPrivateEmail: isPrivate}, nil
}

// refresh 拉取 JWKS；force=true 跳过 TTL 双检（密钥轮换重试路径）。
// 非强制路径缓存未过期直接返回；拉取失败延用旧缓存。
func (v *AppleVerifier) refresh(ctx context.Context, force bool) (map[string]*rsa.PublicKey, error) {
	v.mu.Lock()
	defer v.mu.Unlock()
	if !force && v.keys != nil && time.Since(v.fetchedAt) < v.ttl {
		return v.keys, nil
	}
	keys, err := v.src.Fetch(ctx)
	if err != nil {
		if v.keys != nil {
			return v.keys, nil // 拉取失败延用旧缓存，登录不中断
		}
		return nil, err
	}
	v.keys = keys
	v.fetchedAt = time.Now()
	return keys, nil
}
