package skill

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

// 会注入给模型的辅助文件类型（脚本/二进制素材不注入）
var textExts = map[string]bool{".md": true, ".txt": true, ".csv": true}

// 不注入的子目录：agents/ 是 UI 元数据，单独解析
const skipDir = "agents"

// 合法 skill 目录名（防路径遍历）
var nameRe = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9_-]*$`)

// frontmatter 首块 --- 围栏
var frontmatterRe = regexp.MustCompile(`(?s)^---\r?\n(.*?)\r?\n---(?:\r?\n|$)`)

// ParseFrontmatter yaml.v3 正规解析首块 frontmatter（仅取 name/description），返回剩余正文
func ParseFrontmatter(content string) (Meta, string) {
	m := frontmatterRe.FindStringSubmatch(content)
	if m == nil {
		return Meta{}, content
	}
	var fm struct {
		Name        string `yaml:"name"`
		Description string `yaml:"description"`
	}
	if err := yaml.Unmarshal([]byte(m[1]), &fm); err != nil {
		// 非法 YAML 按无 frontmatter 处理（与资产容错口径一致）
		return Meta{}, content
	}
	return Meta{Name: fm.Name, Description: fm.Description}, content[len(m[0]):]
}

// List 列出全部 skill（目录 + 含 SKILL.md + 非.开头），按名称字节序排序
func List(skillsDir string) ([]Entry, error) {
	if skillsDir == "" {
		return nil, ErrUnavailable
	}
	dirEntries, err := os.ReadDir(skillsDir)
	if err != nil {
		return nil, ErrUnavailable
	}
	var entries []Entry
	for _, de := range dirEntries {
		if !de.IsDir() || strings.HasPrefix(de.Name(), ".") {
			continue
		}
		skillMd := filepath.Join(skillsDir, de.Name(), "SKILL.md")
		raw, err := os.ReadFile(skillMd)
		if err != nil {
			continue
		}
		meta, _ := ParseFrontmatter(string(raw))
		if meta.Name == "" {
			meta.Name = de.Name()
		}
		entries = append(entries, Entry{Name: de.Name(), Meta: meta})
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name < entries[j].Name })
	return entries, nil
}

// Entry 列表条目
type Entry struct {
	Name string
	Meta Meta
}

// Load 加载 skill 全文与辅助文件；路径遍历防护：目录名白名单 + resolve 后必须仍在 skillsDir 内
func Load(skillsDir, name string) (*Loaded, error) {
	if skillsDir == "" {
		return nil, ErrUnavailable
	}
	if !nameRe.MatchString(name) {
		return nil, &NotFoundError{Message: fmt.Sprintf("非法 skill 名称「%s」", name)}
	}
	root, err := filepath.Abs(skillsDir)
	if err != nil {
		return nil, ErrUnavailable
	}
	dir := filepath.Join(root, name)
	resolved, err := filepath.Abs(dir)
	if err != nil || !strings.HasPrefix(resolved, root+string(os.PathSeparator)) {
		return nil, notFoundWithAvailable(skillsDir, name)
	}
	raw, err := os.ReadFile(filepath.Join(resolved, "SKILL.md"))
	if err != nil {
		return nil, notFoundWithAvailable(skillsDir, name)
	}
	meta, body := ParseFrontmatter(string(raw))
	if meta.Name == "" {
		meta.Name = name
	}
	return &Loaded{
		Name:  name,
		Meta:  meta,
		Body:  body,
		Files: loadAuxFiles(resolved),
	}, nil
}

func notFoundWithAvailable(skillsDir, name string) *NotFoundError {
	available := ""
	if entries, err := List(skillsDir); err == nil {
		names := make([]string, 0, len(entries))
		for _, e := range entries {
			names = append(names, e.Name)
		}
		available = strings.Join(names, ", ")
	}
	return &NotFoundError{Message: fmt.Sprintf("未找到 skill「%s」，可用：%s", name, available)}
}

// loadAuxFiles 递归收集辅助文件（跳 agents/ 与点文件、仅文本扩展名），键序确定（排序）
func loadAuxFiles(root string) map[string]string {
	files := make(map[string]string)
	var walk func(dir, prefix string)
	walk = func(dir, prefix string) {
		dirEntries, err := os.ReadDir(dir)
		if err != nil {
			return
		}
		for _, de := range dirEntries {
			if strings.HasPrefix(de.Name(), ".") || (prefix == "" && (de.Name() == skipDir || de.Name() == "SKILL.md")) {
				continue
			}
			rel := de.Name()
			if prefix != "" {
				rel = prefix + "/" + de.Name()
			}
			full := filepath.Join(dir, de.Name())
			if de.IsDir() {
				walk(full, rel)
			} else if textExts[strings.ToLower(filepath.Ext(de.Name()))] {
				if content, err := os.ReadFile(full); err == nil {
					files[rel] = string(content)
				}
			}
		}
	}
	walk(root, "")
	return files
}

// SortedFileKeys 辅助文件按键序返回（注入顺序确定性）
func SortedFileKeys(files map[string]string) []string {
	keys := make([]string, 0, len(files))
	for k := range files {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
