package skill

import "errors"

// Meta SKILL.md frontmatter 元数据（仅取 name/description）
type Meta struct {
	Name        string
	Description string
}

// Loaded loadSkill 的返回值：Body 为 SKILL.md 正文，Files 为辅助文件 { 相对路径: 内容 }
type Loaded struct {
	Name  string
	Meta  Meta
	Body  string
	Files map[string]string
}

// ErrUnavailable 资产目录缺失（领域错误，由 handler 映射 503）
var ErrUnavailable = errors.New("skills 资产目录未就位")

// ErrNotFound skill 不存在（领域错误，由 handler 映射 404，message 含可用列表）
type NotFoundError struct {
	Message string
}

func (e *NotFoundError) Error() string { return e.Message }
