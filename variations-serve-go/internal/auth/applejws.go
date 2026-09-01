package auth

import (
	"crypto/ecdsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"strings"
)

// appleRootG3PEM Apple Root CA - G3（StoreKit JWS x5c 链信任锚，自 Apple PKI 站点取回）
// sha256 指纹 63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79
const appleRootG3PEM = `-----BEGIN CERTIFICATE-----
MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwS
QXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9u
IEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcN
MTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBS
b290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9y
aXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49
AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtf
TjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517
IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySr
MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gA
MGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4
at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM
6BgD56KyKA==
-----END CERTIFICATE-----`

// ErrJWSInvalid IAP 票据验签失败 → 401 BILLING_INVALID
var ErrJWSInvalid = errors.New("IAP 票据校验失败")

type jwsHeader struct {
	Alg string   `json:"alg"`
	X5c []string `json:"x5c"`
}

// TransactionInfo StoreKit 交易 JWS 载荷的必要 claims
type TransactionInfo struct {
	TransactionID string `json:"transactionId"`
	ProductID     string `json:"productId"`
	Quantity      int    `json:"quantity"`
	BundleID      string `json:"bundleId"`
	Environment   string `json:"environment"`
}

// VerifyTransactionJWS 校验 StoreKit JWS：alg=ES256；x5c 证书链验证至信任根；
// 叶子公钥验签；bundleId/environment 与配置匹配。离线完成，无外部依赖。
// JWSVerifier 信任根可注入（生产用内嵌 Apple Root G3，测试用自签根）
type JWSVerifier struct {
	roots *x509.CertPool
}

// NewJWSVerifier 以给定根 PEM 构造验签器
func NewJWSVerifier(rootPEM string) *JWSVerifier {
	pool := x509.NewCertPool()
	pool.AppendCertsFromPEM([]byte(rootPEM))
	return &JWSVerifier{roots: pool}
}

// NewAppleJWSVerifier 生产验签器：内嵌 Apple Root CA - G3
func NewAppleJWSVerifier() *JWSVerifier { return NewJWSVerifier(appleRootG3PEM) }

func (v *JWSVerifier) Verify(jws, expectBundle, expectEnv string) (*TransactionInfo, error) {
	parts := strings.Split(jws, ".")
	if len(parts) != 3 {
		return nil, ErrJWSInvalid
	}
	hdrRaw, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, fmt.Errorf("%w: header 解码失败", ErrJWSInvalid)
	}
	var hdr jwsHeader
	if err := json.Unmarshal(hdrRaw, &hdr); err != nil {
		return nil, fmt.Errorf("%w: header 解析失败", ErrJWSInvalid)
	}
	if hdr.Alg != "ES256" || len(hdr.X5c) == 0 {
		return nil, fmt.Errorf("%w: alg/x5c 不合规", ErrJWSInvalid)
	}

	// 证书链：叶子 + 中间 → 信任根
	leafDER, err := base64.StdEncoding.DecodeString(hdr.X5c[0])
	if err != nil {
		return nil, fmt.Errorf("%w: 叶子证书解码失败", ErrJWSInvalid)
	}
	leaf, err := x509.ParseCertificate(leafDER)
	if err != nil {
		return nil, fmt.Errorf("%w: 叶子证书解析失败", ErrJWSInvalid)
	}
	intermediates := x509.NewCertPool()
	for _, c := range hdr.X5c[1:] {
		der, derr := base64.StdEncoding.DecodeString(c)
		if derr != nil {
			return nil, fmt.Errorf("%w: 中间证书解码失败", ErrJWSInvalid)
		}
		cert, cerr := x509.ParseCertificate(der)
		if cerr != nil {
			return nil, fmt.Errorf("%w: 中间证书解析失败", ErrJWSInvalid)
		}
		intermediates.AddCert(cert)
	}
	if _, err := leaf.Verify(x509.VerifyOptions{
		Roots:         v.roots,
		Intermediates: intermediates,
		KeyUsages:     []x509.ExtKeyUsage{x509.ExtKeyUsageAny},
	}); err != nil {
		return nil, fmt.Errorf("%w: 证书链验证失败", ErrJWSInvalid)
	}

	// 签名：叶子 ECDSA 公钥验签 signing input。
	// JOSE ES256 签名为 raw R||S（各 32 字节大端），非 ASN.1 DER。
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return nil, fmt.Errorf("%w: 签名解码失败", ErrJWSInvalid)
	}
	pub, ok := leaf.PublicKey.(*ecdsa.PublicKey)
	if !ok {
		return nil, fmt.Errorf("%w: 叶子公钥非 ECDSA", ErrJWSInvalid)
	}
	if len(sig) != 64 {
		return nil, fmt.Errorf("%w: ES256 签名长度应为 64", ErrJWSInvalid)
	}
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	r := new(big.Int).SetBytes(sig[:32])
	s := new(big.Int).SetBytes(sig[32:])
	if !ecdsa.Verify(pub, digest[:], r, s) {
		return nil, fmt.Errorf("%w: 签名验证失败", ErrJWSInvalid)
	}

	// 载荷 claims 校验
	payloadRaw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, fmt.Errorf("%w: payload 解码失败", ErrJWSInvalid)
	}
	var info TransactionInfo
	if err := json.Unmarshal(payloadRaw, &info); err != nil {
		return nil, fmt.Errorf("%w: payload 解析失败", ErrJWSInvalid)
	}
	if info.TransactionID == "" || info.ProductID == "" {
		return nil, fmt.Errorf("%w: 缺 transactionId/productId", ErrJWSInvalid)
	}
	if expectBundle != "" && info.BundleID != expectBundle {
		return nil, fmt.Errorf("%w: bundleId 不符", ErrJWSInvalid)
	}
	if expectEnv != "" && !strings.EqualFold(info.Environment, expectEnv) {
		return nil, fmt.Errorf("%w: environment 不符", ErrJWSInvalid)
	}
	return &info, nil
}
