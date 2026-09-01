package model

import "errors"

// DashScopeError 百炼上游错误（清理后透传，handler 映射 502 DASHSCOPE_ERROR）
type DashScopeError struct {
	Message string
}

func (e *DashScopeError) Error() string { return e.Message }

// ArkError 火山方舟上游错误（清理后透传，handler 映射 502 ARK_ERROR）
type ArkError struct {
	Message string
}

func (e *ArkError) Error() string { return e.Message }

// ValidationError 请求校验错误（handler 映射 400 BAD_REQUEST）
type ValidationError struct {
	Message string
}

func (e *ValidationError) Error() string { return e.Message }

func newValidationError(msg string) error { return &ValidationError{Message: msg} }

func newDashScopeError(msg string) error { return &DashScopeError{Message: msg} }

func newArkError(msg string) error { return &ArkError{Message: msg} }

// AsValidation 便捷判定
func AsValidation(err error) (*ValidationError, bool) {
	var v *ValidationError
	ok := errors.As(err, &v)
	return v, ok
}
