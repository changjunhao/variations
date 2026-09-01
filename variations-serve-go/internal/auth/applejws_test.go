package auth

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"math/big"
	"testing"
	"time"
)

// testChain 生成自签根（替代 Apple Root G3 的信任锚角色仅在本测试内）+ 叶子
func testChain(t *testing.T) (*ecdsa.PrivateKey, string) {
	t.Helper()
	rootKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	tmpl := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{CommonName: "Test Root"},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().Add(24 * time.Hour),
		IsCA:                  true,
		BasicConstraintsValid: true,
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature,
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &rootKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	pem := "-----BEGIN CERTIFICATE-----\n" + base64.StdEncoding.EncodeToString(der) + "\n-----END CERTIFICATE-----\n"
	return rootKey, pem
}

// signTestJWS 以叶子私钥签 JWS（x5c 仅叶子，根由 verifier 注入信任）。
// ES256 按 JOSE 规范输出 raw R||S（各 32 字节大端），与生产票据同构。
func signTestJWS(t *testing.T, leafKey *ecdsa.PrivateKey, leafDER []byte, payload any) string {
	t.Helper()
	hdr, _ := json.Marshal(map[string]any{"alg": "ES256", "x5c": []string{base64.StdEncoding.EncodeToString(leafDER)}})
	pl, _ := json.Marshal(payload)
	signingInput := base64.RawURLEncoding.EncodeToString(hdr) + "." + base64.RawURLEncoding.EncodeToString(pl)
	digest := sha256.Sum256([]byte(signingInput))
	r, s, err := ecdsa.Sign(rand.Reader, leafKey, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	sig := make([]byte, 64)
	r.FillBytes(sig[:32])
	s.FillBytes(sig[32:])
	return signingInput + "." + base64.RawURLEncoding.EncodeToString(sig)
}

func leafCert(t *testing.T, rootKey *ecdsa.PrivateKey, rootCert *x509.Certificate) (*ecdsa.PrivateKey, []byte) {
	t.Helper()
	leafKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	tmpl := &x509.Certificate{
		SerialNumber: big.NewInt(2),
		Subject:      pkix.Name{CommonName: "Test Leaf"},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(24 * time.Hour),
		KeyUsage:     x509.KeyUsageDigitalSignature,
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, rootCert, &leafKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	return leafKey, der
}

func TestVerifyTransactionJWS(t *testing.T) {
	rootKey, rootPEM := testChain(t)
	rootCert, err := x509.ParseCertificate(mustDecodePEM(t, rootPEM))
	if err != nil {
		t.Fatal(err)
	}
	leafKey, leafDER := leafCert(t, rootKey, rootCert)

	payload := map[string]any{
		"transactionId": "10000001", "productId": "pack.small", "quantity": 1,
		"bundleId": "cn.ifable.Variations", "environment": "Sandbox",
	}
	jws := signTestJWS(t, leafKey, leafDER, payload)

	v := NewJWSVerifier(rootPEM)
	info, err := v.Verify(jws, "cn.ifable.Variations", "Sandbox")
	if err != nil {
		t.Fatalf("验签应通过: %v", err)
	}
	if info.TransactionID != "10000001" || info.ProductID != "pack.small" {
		t.Fatalf("claims 提取异常: %+v", info)
	}

	// bundleId 不符 → 拒绝
	if _, err := v.Verify(jws, "other.bundle", "Sandbox"); err == nil {
		t.Fatal("bundleId 不符应拒绝")
	}
	// environment 不符 → 拒绝
	if _, err := v.Verify(jws, "cn.ifable.Variations", "Production"); err == nil {
		t.Fatal("environment 不符应拒绝")
	}
	// 篡改 payload → 签名失败
	tampered := jws[:len(jws)-6] + "AAAAAA"
	if _, err := v.Verify(tampered, "cn.ifable.Variations", "Sandbox"); err == nil {
		t.Fatal("篡改签名应拒绝")
	}
	// 垃圾输入 → 拒绝
	if _, err := v.Verify("garbage", "cn.ifable.Variations", "Sandbox"); err == nil {
		t.Fatal("垃圾输入应拒绝")
	}
}

func mustDecodePEM(t *testing.T, pemStr string) []byte {
	t.Helper()
	block, _ := pem.Decode([]byte(pemStr))
	if block == nil {
		t.Fatal("PEM 解码失败")
	}
	return block.Bytes
}
