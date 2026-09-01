// sync-samples 运营工具：把各 skill 的 assets/sample.jpg 同步到 OSS 公共读前缀（对象级 public-read）
// 不进请求链路；样图未就位时 /api/skills 的 sampleImageUrl 优雅为 null
// 用法：cd variations-serve-go && go run ./cmd/sync-samples（依赖 .env 或环境变量 OSS_* 与 OSS_PUBLIC_PREFIX）
package main

import (
	"context"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"strings"

	osssdk "github.com/aliyun/alibabacloud-oss-go-sdk-v2/oss"
	"github.com/aliyun/alibabacloud-oss-go-sdk-v2/oss/credentials"

	"variations-serve-go/internal/config"
)

func main() {
	logger := config.NewLogger()
	cfg := config.Load(logger)

	if cfg.Oss.Region == "" || cfg.Oss.Bucket == "" || cfg.Oss.AccessKeyID == "" || cfg.Oss.AccessKeySecret == "" {
		logger.Error("缺少 OSS_REGION/OSS_BUCKET/OSS_ACCESS_KEY_ID/OSS_ACCESS_KEY_SECRET")
		os.Exit(1)
	}
	if cfg.OssPublicPrefix == "" {
		logger.Error("缺少 OSS_PUBLIC_PREFIX（如 https://<bucket>.<endpoint>/public）")
		os.Exit(1)
	}
	prefixURL, err := url.Parse(cfg.OssPublicPrefix)
	if err != nil {
		logger.Error("OSS_PUBLIC_PREFIX 解析失败", "error", err.Error())
		os.Exit(1)
	}
	prefixPath := strings.Trim(prefixURL.Path, "/")

	// 资产目录：显式 ASSETS_DIR 优先，否则 ./assets（与主服务同口径）
	assetsDir := os.Getenv("ASSETS_DIR")
	if assetsDir == "" {
		assetsDir = "assets"
	}
	skillsDir := filepath.Join(assetsDir, "skills")
	entries, err := os.ReadDir(skillsDir)
	if err != nil {
		logger.Error("读取 skills 目录失败", "dir", skillsDir, "error", err.Error())
		os.Exit(1)
	}

	sdkCfg := osssdk.LoadDefaultConfig().
		WithRegion(cfg.Oss.Region).
		WithCredentialsProvider(credentials.NewStaticCredentialsProvider(cfg.Oss.AccessKeyID, cfg.Oss.AccessKeySecret))
	client := osssdk.NewClient(sdkCfg)

	synced := 0
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		sampleFile := filepath.Join(skillsDir, entry.Name(), "assets", "sample.jpg")
		f, err := os.Open(sampleFile)
		if err != nil {
			logger.Warn("样图不存在，跳过", "skill", entry.Name())
			continue
		}
		objectKey := entry.Name()
		objectKey = "skills/" + objectKey + "/assets/sample.jpg"
		if prefixPath != "" {
			objectKey = prefixPath + "/" + objectKey
		}
		_, err = client.PutObject(context.Background(), &osssdk.PutObjectRequest{
			Bucket: osssdk.Ptr(cfg.Oss.Bucket),
			Key:    osssdk.Ptr(objectKey),
			Body:   f,
			Acl:    osssdk.ObjectACLPublicRead,
		})
		f.Close()
		if err != nil {
			logger.Error("同步失败", "skill", entry.Name(), "error", err.Error())
			os.Exit(1)
		}
		fmt.Printf("[ok] %s -> %s\n", entry.Name(), objectKey)
		synced++
	}
	fmt.Printf("完成：%d 张样图已同步\n", synced)
}
