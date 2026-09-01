package auth

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
)

// ErrGateNotConfigured 注册门槛未配置（REGISTER_SECRET 为空）→ 注册端点 503
var ErrGateNotConfigured = errors.New("注册服务未启用")

// ErrProofInvalid 门槛校验失败 → 注册端点 401 REGISTER_DENIED
var ErrProofInvalid = errors.New("设备注册凭证校验失败")

// RegisterRequest 设备注册请求（门槛校验入参）
type RegisterRequest struct {
	DeviceID   string
	DeviceName string
	Proof      string
}

// RegisterGate 注册门槛抽象：当前为 App Secret HMAC 软门槛；
// 未来升级 Apple App Attest（硬件证明）时实现同接口替换，token 机制与客户端流程不变。
// 注意：软门槛是门槛不是保证——iOS 二进制可被脱壳逆向提取密钥，认真攻击者仍可注册。
type RegisterGate interface {
	Verify(req RegisterRequest) error
}

// HMACGate App Secret 软门槛：proof = HMAC-SHA256(secret, deviceId) 十六进制
type HMACGate struct {
	secret []byte
}

func NewHMACGate(secret string) *HMACGate {
	return &HMACGate{secret: []byte(secret)}
}

// Configured 门槛是否已配置（secret 未配置时注册端点直接 503，不允许裸开放）
func (g *HMACGate) Configured() bool {
	return len(g.secret) > 0
}

func (g *HMACGate) Verify(req RegisterRequest) error {
	if !g.Configured() {
		return ErrGateNotConfigured
	}
	mac := hmac.New(sha256.New, g.secret)
	mac.Write([]byte(req.DeviceID))
	expected := hex.EncodeToString(mac.Sum(nil))
	proof, err := hex.DecodeString(req.Proof)
	if err != nil || len(proof) != sha256.Size {
		return ErrProofInvalid
	}
	if !hmac.Equal([]byte(expected), []byte(req.Proof)) {
		return ErrProofInvalid
	}
	return nil
}
