package model

import (
	"math"
	"regexp"
	"strconv"
	"strings"
)

// seedream 5.0 lite 精确像素的总像素范围（官方规格：[2560x1440, 4096x4096]，宽高比 [1/16, 16]）；
// 通过 ARK_IMAGE_MODEL 切换其他版本模型时在此调整常量（4.0 下限为 1280x720）
const (
	minTotalPixels = 2560 * 1440
	maxTotalPixels = 4096 * 4096
)

var arkSizeRe = regexp.MustCompile(`^(\d+)\*(\d+)$`)

// ToArkSize 客户端 "宽*高" 星号串 → seedream "宽x高"；总像素超出合法范围时按比例钳制。
// 客户端像素串（如 896*1600≈143 万像素）低于 seedream 5.0 lite 下限（约 369 万像素），
// 此处等比放大到下限以上，对客户端透明。解析失败返回 ""（不传 size，用模型默认值）。
func ToArkSize(size string) string {
	m := arkSizeRe.FindStringSubmatch(strings.TrimSpace(size))
	if m == nil {
		return ""
	}
	w, err1 := strconv.Atoi(m[1])
	h, err2 := strconv.Atoi(m[2])
	if err1 != nil || err2 != nil || w <= 0 || h <= 0 {
		return ""
	}
	total := w * h
	bound := 0
	if total < minTotalPixels {
		bound = minTotalPixels
	} else if total > maxTotalPixels {
		bound = maxTotalPixels
	}
	if bound > 0 {
		scale := math.Sqrt(float64(bound) / float64(total))
		w = int(float64(w)*scale + 0.5)
		h = int(float64(h)*scale + 0.5)
		// 取整误差修正：放大后仍低于下限时递增短边，保证必然落入合法区间
		for w*h < minTotalPixels {
			if w <= h {
				w++
			} else {
				h++
			}
		}
	}
	return strconv.Itoa(w) + "x" + strconv.Itoa(h)
}
