package model

import (
	"fmt"
	"testing"
)

func TestToArkSize(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want string
	}{
		{"空串", "", ""},
		{"非法格式x", "1152x1536", ""},
		{"非法字符", "abc*def", ""},
		{"零宽", "0*100", ""},
		{"低于下限等比放大", "896*1600", "1437x2566"},
		{"下限原样", "2560*1440", "2560x1440"},
		{"区间内原样", "3000*2000", "3000x2000"},
		{"超上限等比缩小", "8192*8192", "4096x4096"},
		{"极端竖图", "100*4000", "304x12143"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ToArkSize(tt.in)
			if got != tt.want {
				t.Fatalf("ToArkSize(%q) = %q, want %q", tt.in, got, tt.want)
			}
		})
	}
}

// 钳制结果的不变量：总像素绝不低于下限（取整误差修正循环保证）
func TestToArkSizeClampInvariant(t *testing.T) {
	inputs := []string{"1*1", "10*10", "896*1600", "1152*1536", "16*9000", "9000*16", "4096*4096", "9999*9999"}
	for _, in := range inputs {
		got := ToArkSize(in)
		if got == "" {
			t.Fatalf("ToArkSize(%q) 意外返回空", in)
		}
		var w, h int
		if _, err := fmt.Sscanf(got, "%dx%d", &w, &h); err != nil {
			t.Fatalf("输出格式非法: %q (%v)", got, err)
		}
		if w*h < minTotalPixels {
			t.Fatalf("ToArkSize(%q)=%q 总像素 %d 低于下限 %d", in, got, w*h, minTotalPixels)
		}
	}
}
