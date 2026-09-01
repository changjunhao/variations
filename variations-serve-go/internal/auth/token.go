// Package auth 设备身份令牌：注册端点、token 签发/哈希、注册门槛（gate）。
package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
)

// tokenPrefix 使 token 在日志/DB 中可辨识
const tokenPrefix = "var_"

// userTokenPrefix 用户会话令牌前缀（与设备令牌区分，30 天有效）
const userTokenPrefix = "var_u_"

// GenerateToken 签发长期 token：前缀 + 32 字节 crypto/rand base64url（明文仅下发一次）
func GenerateToken() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return tokenPrefix + base64.RawURLEncoding.EncodeToString(buf), nil
}

// GenerateUserToken 签发用户会话令牌（var_u_ 前缀，明文仅下发一次）
func GenerateUserToken() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return userTokenPrefix + base64.RawURLEncoding.EncodeToString(buf), nil
}

// HashToken token → SHA-256 hex（DB 仅存哈希，比对走查表，天然恒定时间）
func HashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}
