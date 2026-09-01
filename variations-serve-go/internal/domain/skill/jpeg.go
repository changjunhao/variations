package skill

import (
	"image"
	_ "image/jpeg" // 注册 JPEG 解码器，仅解码头部取尺寸
	"math"
	"os"
	"path/filepath"
)

// ProbeAspect 样图宽高比（宽/高，保留 4 位小数）：标准库 image.DecodeConfig 只解码头部。
// 文件缺失或非图片格式返回 nil（客户端按缺省比例占位）
func ProbeAspect(skillsDir, dirName string) *float64 {
	if skillsDir == "" {
		return nil
	}
	f, err := os.Open(filepath.Join(skillsDir, dirName, "assets", "sample.jpg"))
	if err != nil {
		return nil
	}
	defer f.Close()
	cfg, _, err := image.DecodeConfig(f)
	if err != nil || cfg.Height == 0 {
		return nil
	}
	aspect := math.Round(float64(cfg.Width)/float64(cfg.Height)*1e4) / 1e4
	return &aspect
}
