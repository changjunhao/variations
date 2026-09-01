package httpx

import "github.com/gin-gonic/gin"

// CtxKey gin context 键（类型化防碰撞）：server 中间件写入、handlers 读取，
// 置于 httpx 防 server ↔ handlers 循环依赖。
type CtxKey string

const (
	CtxDeviceID      CtxKey = "deviceId"
	CtxUserID        CtxKey = "userId"
	CtxPrincipal     CtxKey = "principal"     // 'device:'||id / 'user:'||id / 'admin'
	CtxTokenHash     CtxKey = "tokenHash"     // 当前请求令牌哈希（退出登录吊销用）
	CtxUserCreatedAt CtxKey = "userCreatedAt" // 用户注册时间 RFC3339（特权窗口判定）
)

// DeviceID 鉴权通过的设备 id（游客链路；未鉴权/用户会话返回空）
func DeviceID(c *gin.Context) string {
	v, _ := c.Get(string(CtxDeviceID))
	s, _ := v.(string)
	return s
}

// UserID SIWA 用户 id（未登录返回空）
func UserID(c *gin.Context) string {
	v, _ := c.Get(string(CtxUserID))
	s, _ := v.(string)
	return s
}

// Principal 配额/限频归属键（admin 旁路为 "admin"）
func Principal(c *gin.Context) string {
	v, _ := c.Get(string(CtxPrincipal))
	s, _ := v.(string)
	return s
}

// TokenHash 当前请求令牌哈希
func TokenHash(c *gin.Context) string {
	v, _ := c.Get(string(CtxTokenHash))
	s, _ := v.(string)
	return s
}

// UserCreatedAt 用户注册时间串（游客/admin 返回空）
func UserCreatedAt(c *gin.Context) string {
	v, _ := c.Get(string(CtxUserCreatedAt))
	s, _ := v.(string)
	return s
}
