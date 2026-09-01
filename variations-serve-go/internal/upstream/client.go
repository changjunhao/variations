// Package upstream 上游 HTTP 客户端：进程级单例 + Transport 调优；
// 超时不设 Client.Timeout，全部由请求级 context 控制（长耗时生图场景）。
package upstream

import (
	"net/http"
	"time"
)

var shared = &http.Client{
	Transport: &http.Transport{
		MaxIdleConns:        128,
		MaxIdleConnsPerHost: 32,
		IdleConnTimeout:     90 * time.Second,
		TLSHandshakeTimeout: 10 * time.Second,
	},
}

// Client 进程级单例 http.Client（连接复用）
func Client() *http.Client {
	return shared
}

// CallTimeout 请求级超时：略短于服务端总超时，给响应回写留余量
func CallTimeout(requestTimeout time.Duration) time.Duration {
	t := requestTimeout - 5*time.Second
	if t < 10*time.Second {
		t = 10 * time.Second
	}
	return t
}
