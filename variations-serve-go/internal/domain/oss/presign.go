package oss

import (
	"context"
	"errors"
	"sync"
	"time"

	osssdk "github.com/aliyun/alibabacloud-oss-go-sdk-v2/oss"
	"github.com/aliyun/alibabacloud-oss-go-sdk-v2/oss/credentials"

	"variations-serve-go/internal/config"
)

// ErrNotConfigured OSS 环境变量不全（领域错误，由 handler 映射 503）
var ErrNotConfigured = errors.New("OSS 环境变量未配齐（OSS_REGION/OSS_BUCKET/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET）")

// Signer OSS V4 预签名：
// PUT 票据（客户端上传，Content-Type 绑入签名）+ GET 票据（喂模型 / 再次变奏，签名 ≤2h）。
// 对象本身 48h 后由 bucket 生命周期规则删除（前缀 uploads/、2 天），服务端零清理代码；
// 再次变奏不依赖长效签名——客户端凭内容哈希走 /api/file-url 探测存在性并重签新 GET 票据。
type Signer struct {
	cfg    config.OssConfig
	mu     sync.Mutex
	client *osssdk.Client
}

func NewSigner(cfg config.OssConfig) *Signer {
	return &Signer{cfg: cfg}
}

// Configured 四要素是否配齐
func (s *Signer) Configured() bool {
	return s.cfg.Region != "" && s.cfg.Bucket != "" && s.cfg.AccessKeyID != "" && s.cfg.AccessKeySecret != ""
}

// getClient 懒初始化：配置齐全且首次调用时创建
func (s *Signer) getClient() (*osssdk.Client, error) {
	if !s.Configured() {
		return nil, ErrNotConfigured
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.client == nil {
		cfg := osssdk.LoadDefaultConfig().
			WithRegion(s.cfg.Region).
			WithCredentialsProvider(credentials.NewStaticCredentialsProvider(s.cfg.AccessKeyID, s.cfg.AccessKeySecret))
		s.client = osssdk.NewClient(cfg)
	}
	return s.client, nil
}

// SignPut PUT 预签名（客户端上传）：Content-Type 绑入签名，客户端必须携带同值 header
func (s *Signer) SignPut(ctx context.Context, objectKey, contentType string, expires time.Duration) (string, error) {
	client, err := s.getClient()
	if err != nil {
		return "", err
	}
	result, err := client.Presign(ctx, &osssdk.PutObjectRequest{
		Bucket:      osssdk.Ptr(s.cfg.Bucket),
		Key:         osssdk.Ptr(objectKey),
		ContentType: osssdk.Ptr(contentType),
	}, osssdk.PresignExpires(expires))
	if err != nil {
		return "", err
	}
	return result.URL, nil
}

// SignGet GET 预签名（喂模型 / 客户端再次变奏）：签名有效期 ≤2h，
// 对象 48h 生命周期内可反复重签，不依赖长效签名
func (s *Signer) SignGet(ctx context.Context, objectKey string, expires time.Duration) (string, error) {
	client, err := s.getClient()
	if err != nil {
		return "", err
	}
	result, err := client.Presign(ctx, &osssdk.GetObjectRequest{
		Bucket: osssdk.Ptr(s.cfg.Bucket),
		Key:    osssdk.Ptr(objectKey),
	}, osssdk.PresignExpires(expires))
	if err != nil {
		return "", err
	}
	return result.URL, nil
}

// ObjectExists 对象存在性探测（HeadObject，单次网络调用）：
// 已被生命周期清理返回 false；仅 404 判不存在，其余服务错误原样上抛（handler 映射 5xx）
func (s *Signer) ObjectExists(ctx context.Context, objectKey string) (bool, error) {
	client, err := s.getClient()
	if err != nil {
		return false, err
	}
	_, err = client.HeadObject(ctx, &osssdk.HeadObjectRequest{
		Bucket: osssdk.Ptr(s.cfg.Bucket),
		Key:    osssdk.Ptr(objectKey),
	})
	if err != nil {
		var serr *osssdk.ServiceError
		if errors.As(err, &serr) && serr.StatusCode == 404 {
			return false, nil
		}
		return false, err
	}
	return true, nil
}
