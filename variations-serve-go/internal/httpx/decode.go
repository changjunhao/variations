package httpx

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
)

// BodyLimit 请求体上限：读时经 MaxBytesReader 截断，超限由 DecodeJSON 映射 413
func BodyLimit(maxBytes int64) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBytes)
		c.Next()
	}
}

// DecodeJSON 读取并解析请求体到 v；非法 JSON→400、超限→413
func DecodeJSON(c *gin.Context, v any) *ApiError {
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		var maxErr *http.MaxBytesError
		if errors.As(err, &maxErr) {
			return New(413, CodeBodyTooLarge, "请求体超过 1MB 限制")
		}
		return New(400, CodeBadRequest, "请求体必须是合法 JSON")
	}
	if err := json.Unmarshal(body, v); err != nil {
		return New(400, CodeBadRequest, "请求体必须是合法 JSON")
	}
	return nil
}
