// Package httpx 业务错误与统一响应：ApiError{status, code, message} → JSON {code, message}
package httpx

import "github.com/gin-gonic/gin"

// 稳定错误码（iOS AppError 按 status 分支消费，code 保持稳定存在）
const (
	CodeUnauthorized       = "UNAUTHORIZED"
	CodeBadRequest         = "BAD_REQUEST"
	CodeNotFound           = "NOT_FOUND"
	CodeRateLimited        = "RATE_LIMITED"
	CodeBodyTooLarge       = "BODY_TOO_LARGE"
	CodeServiceUnavailable = "SERVICE_UNAVAILABLE"
	CodeDashscopeError     = "DASHSCOPE_ERROR"
	CodeArkError           = "ARK_ERROR"
	CodeInternalError      = "INTERNAL_ERROR"
	CodeRegisterDenied     = "REGISTER_DENIED"
	// CodeSourceFileGone 源图已过 48h 生命周期被清理（410）：客户端提示「不可变奏」，不得降级文生图
	CodeSourceFileGone = "SOURCE_FILE_GONE"
	// CodeQuotaExceeded 当日积分配额不足（429）：body 附 quota 详情供客户端展示
	CodeQuotaExceeded = "QUOTA_EXCEEDED"
	// CodeAccountDeleted 账号已注销（403）
	CodeAccountDeleted = "ACCOUNT_DELETED"
	// CodeAppleTokenInvalid SIWA identityToken 验签失败（401）
	CodeAppleTokenInvalid = "APPLE_TOKEN_INVALID"
	// CodeBillingInvalid IAP 票据验签失败（401）
	CodeBillingInvalid = "BILLING_INVALID"
)

// ApiError 带稳定 code 的业务错误，由 server 层统一映射为 {code, message}
type ApiError struct {
	Status  int
	Code    string
	Message string
}

func (e *ApiError) Error() string { return e.Message }

func New(status int, code, message string) *ApiError {
	return &ApiError{Status: status, Code: code, Message: message}
}

func Unauthorized(message string) *ApiError {
	return New(401, CodeUnauthorized, message)
}

func BadRequest(message string) *ApiError {
	return New(400, CodeBadRequest, message)
}

func NotFound(message string) *ApiError {
	return New(404, CodeNotFound, message)
}

func TooManyRequests(message string) *ApiError {
	return New(429, CodeRateLimited, message)
}

func ServiceUnavailable(message string) *ApiError {
	return New(503, CodeServiceUnavailable, message)
}

// RenderError 统一错误体 {code, message}
func RenderError(c *gin.Context, status int, code, message string) {
	c.AbortWithStatusJSON(status, gin.H{"code": code, "message": message})
}
