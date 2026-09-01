package auth

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type localKeySource struct{ key *rsa.PrivateKey }

func (s localKeySource) Fetch(context.Context) (map[string]*rsa.PublicKey, error) {
	return map[string]*rsa.PublicKey{"kid-1": &s.key.PublicKey}, nil
}

func newTestVerifier(t *testing.T) (*AppleVerifier, *rsa.PrivateKey) {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	return NewAppleVerifierWithSource("cn.ifable.Variations", localKeySource{key: key}, time.Hour), key
}

func signIdentity(t *testing.T, key *rsa.PrivateKey, claims jwt.MapClaims) string {
	t.Helper()
	base := jwt.MapClaims{
		"iss": "https://appleid.apple.com",
		"aud": "cn.ifable.Variations",
		"exp": time.Now().Add(time.Hour).Unix(),
		"iat": time.Now().Unix(),
	}
	for k, v := range claims {
		base[k] = v
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, base)
	tok.Header["kid"] = "kid-1"
	signed, err := tok.SignedString(key)
	if err != nil {
		t.Fatal(err)
	}
	return signed
}

func TestVerifySuccess(t *testing.T) {
	v, key := newTestVerifier(t)
	token := signIdentity(t, key, jwt.MapClaims{
		"sub": "apple-sub", "email": "r@privaterelay.appleid.com", "is_private_email": "true",
	})
	identity, err := v.Verify(context.Background(), token)
	if err != nil {
		t.Fatalf("验签应通过: %v", err)
	}
	if identity.Sub != "apple-sub" || identity.Email != "r@privaterelay.appleid.com" || !identity.IsPrivateEmail {
		t.Fatalf("claims 提取异常: %+v", identity)
	}
}

func TestVerifyRejects(t *testing.T) {
	v, key := newTestVerifier(t)

	// aud 不符
	if _, err := v.Verify(context.Background(), signIdentity(t, key, jwt.MapClaims{"sub": "s", "aud": "other"})); err == nil {
		t.Fatal("aud 不符应拒绝")
	}
	// 过期
	if _, err := v.Verify(context.Background(), signIdentity(t, key, jwt.MapClaims{"sub": "s", "exp": time.Now().Add(-time.Hour).Unix()})); err == nil {
		t.Fatal("过期应拒绝")
	}
	// iss 不符
	if _, err := v.Verify(context.Background(), signIdentity(t, key, jwt.MapClaims{"sub": "s", "iss": "https://evil.example"})); err == nil {
		t.Fatal("iss 不符应拒绝")
	}
	// 缺 sub
	if _, err := v.Verify(context.Background(), signIdentity(t, key, jwt.MapClaims{})); err == nil {
		t.Fatal("缺 sub 应拒绝")
	}
	// 错误密钥签名
	other, _ := rsa.GenerateKey(rand.Reader, 2048)
	if _, err := v.Verify(context.Background(), signIdentity(t, other, jwt.MapClaims{"sub": "s"})); err == nil {
		t.Fatal("错误密钥应拒绝")
	}
}

func TestVerifyKeyRotationRefresh(t *testing.T) {
	// 首轮密钥 A 已缓存；Apple 轮换到密钥 B 后，kid 未命中应强制刷新并重试成功
	keyA, _ := rsa.GenerateKey(rand.Reader, 2048)
	keyB, _ := rsa.GenerateKey(rand.Reader, 2048)
	src := &rotatingKeySource{keys: map[string]*rsa.PublicKey{"kid-a": &keyA.PublicKey}}
	v := NewAppleVerifierWithSource("cn.ifable.Variations", src, time.Hour)

	// 预热缓存
	if _, err := v.Verify(context.Background(), signWith(t, keyA, "kid-a", "s")); err != nil {
		t.Fatalf("预热应通过: %v", err)
	}
	// 轮换：缓存里只有 kid-a，新 token 用 kid-b
	src.keys = map[string]*rsa.PublicKey{"kid-b": &keyB.PublicKey}
	identity, err := v.Verify(context.Background(), signWith(t, keyB, "kid-b", "s2"))
	if err != nil {
		t.Fatalf("轮换后应强制刷新重试成功: %v", err)
	}
	if identity.Sub != "s2" {
		t.Fatalf("sub 异常: %+v", identity)
	}
}

type rotatingKeySource struct{ keys map[string]*rsa.PublicKey }

func (s *rotatingKeySource) Fetch(context.Context) (map[string]*rsa.PublicKey, error) {
	return s.keys, nil
}

func signWith(t *testing.T, key *rsa.PrivateKey, kid, sub string) string {
	t.Helper()
	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims{
		"sub": sub, "iss": "https://appleid.apple.com", "aud": "cn.ifable.Variations",
		"exp": time.Now().Add(time.Hour).Unix(), "iat": time.Now().Unix(),
	})
	tok.Header["kid"] = kid
	signed, err := tok.SignedString(key)
	if err != nil {
		t.Fatal(err)
	}
	return signed
}
