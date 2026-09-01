// 源图尺寸探测：compile 前以本 bucket 签名 URL 只读文件头，
// 为「画幅跟随原图朝向」类 skill 提供权威朝向，避免 VL 模型自行目测出错。
package model

import (
	"context"
	"io"
	"net/http"
	"strconv"
)

// 探测读取上限：Range 请求 64KB 足够覆盖 JPEG SOF；服务端不支持 Range 时整图回传，封顶 1MB 防撑爆
const (
	probeRangeBytes = 64 * 1024
	probeMaxBody    = 1024 * 1024
)

// probeClient 不跟随重定向：URL 上游已经 AssertBucketURL 白名单校验（仅本 bucket 域名），
// 禁重定向防止签名 URL 被 302 引向任意主机（SSRF 兜底）
var probeClient = &http.Client{
	CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
}

// ProbeRemoteImageSize 探测图片像素宽高（JPEG SOF / PNG IHDR）；
// 非这两种格式、请求失败或头部不完整一律返回 false（调用方 fail-soft，不注入朝向）
func ProbeRemoteImageSize(ctx context.Context, url string) (width, height int, ok bool) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return 0, 0, false
	}
	req.Header.Set("Range", "bytes=0-"+strconv.Itoa(probeRangeBytes-1))
	res, err := probeClient.Do(req)
	if err != nil {
		return 0, 0, false
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK && res.StatusCode != http.StatusPartialContent {
		return 0, 0, false
	}
	buf, err := io.ReadAll(io.LimitReader(res.Body, probeMaxBody))
	if err != nil || len(buf) < 24 {
		return 0, 0, false
	}
	if w, h, found := probePNG(buf); found {
		return w, h, true
	}
	if w, h, found := probeJPEG(buf); found {
		return w, h, true
	}
	return 0, 0, false
}

// probePNG 魔数 + IHDR：宽高为 16-24 字节大端
func probePNG(buf []byte) (int, int, bool) {
	if len(buf) < 24 || buf[0] != 0x89 || buf[1] != 'P' || buf[2] != 'N' || buf[3] != 'G' {
		return 0, 0, false
	}
	return int(uint32(buf[16])<<24 | uint32(buf[17])<<16 | uint32(buf[18])<<8 | uint32(buf[19])),
		int(uint32(buf[20])<<24 | uint32(buf[21])<<16 | uint32(buf[22])<<8 | uint32(buf[23])), true
}

// probeJPEG SOI 后逐段扫 marker，SOF0–SOF15（剔除 DHT/JPG/DAC 保留段）段内含像素宽高
func probeJPEG(buf []byte) (int, int, bool) {
	if len(buf) < 2 || buf[0] != 0xff || buf[1] != 0xd8 {
		return 0, 0, false
	}
	offset := 2
	for offset+4 <= len(buf) {
		if buf[offset] != 0xff {
			return 0, 0, false
		}
		code := buf[offset+1]
		length := int(buf[offset+2])<<8 | int(buf[offset+3])
		if code >= 0xc0 && code <= 0xcf && code != 0xc4 && code != 0xc8 && code != 0xcc {
			if offset+9 > len(buf) {
				return 0, 0, false // 头部不完整（Range 截断）：fail-soft
			}
			h := int(buf[offset+5])<<8 | int(buf[offset+6])
			w := int(buf[offset+7])<<8 | int(buf[offset+8])
			return w, h, true
		}
		offset += 2 + length
	}
	return 0, 0, false
}
