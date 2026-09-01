package auth

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"testing"
)

func TestTokenRoundTrip(t *testing.T) {
	token, err := GenerateToken()
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(token, "var_") || len(token) < 40 {
		t.Fatalf("token 形态异常: %q", token)
	}
	h1, h2 := HashToken(token), HashToken(token)
	if h1 != h2 || len(h1) != 64 {
		t.Fatal("哈希不稳定或长度异常")
	}
	if strings.Contains(h1, token) {
		t.Fatal("哈希不应包含明文")
	}
}

func TestHMACGate(t *testing.T) {
	gate := NewHMACGate("secret-123")
	valid := computeProof(t, "secret-123", "device-a")
	if err := gate.Verify(RegisterRequest{DeviceID: "device-a", Proof: valid}); err != nil {
		t.Fatalf("合法 proof 被拒: %v", err)
	}
	if err := gate.Verify(RegisterRequest{DeviceID: "device-a", Proof: computeProof(t, "wrong-secret", "device-a")}); err != ErrProofInvalid {
		t.Fatalf("错误 secret 应拒绝: %v", err)
	}
	if err := gate.Verify(RegisterRequest{DeviceID: "device-b", Proof: valid}); err != ErrProofInvalid {
		t.Fatalf("deviceId 不匹配应拒绝: %v", err)
	}
	if err := gate.Verify(RegisterRequest{DeviceID: "device-a", Proof: "zzz"}); err != ErrProofInvalid {
		t.Fatalf("非法 hex 应拒绝: %v", err)
	}
}

// secret 未配置：门槛校验返回 ErrGateNotConfigured（注册端点映射 503）
func TestHMACGateNotConfigured(t *testing.T) {
	gate := NewHMACGate("")
	if gate.Configured() {
		t.Fatal("空 secret 不应视为已配置")
	}
	if err := gate.Verify(RegisterRequest{DeviceID: "d", Proof: "x"}); err != ErrGateNotConfigured {
		t.Fatalf("期望 ErrGateNotConfigured: %v", err)
	}
}

func computeProof(t *testing.T, secret, deviceID string) string {
	t.Helper()
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(deviceID))
	return hex.EncodeToString(mac.Sum(nil))
}
