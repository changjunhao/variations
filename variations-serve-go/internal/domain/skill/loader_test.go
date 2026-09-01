package skill

import (
	"os"
	"path/filepath"
	"testing"
)

func setupSkillDir(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	dir := filepath.Join(root, "demo-skill")
	mustWrite(t, filepath.Join(dir, "SKILL.md"), "---\nname: \"演示模版\"\ndescription: 一个测试模版\n---\n# 正文内容\n")
	mustWrite(t, filepath.Join(dir, "references", "style.md"), "风格说明")
	mustWrite(t, filepath.Join(dir, "agents", "openai.yaml"), "interface:\n  display_name: 演示\n")
	mustWrite(t, filepath.Join(dir, "assets", "note.txt"), "不应注入的资产文本")
	return root
}

func mustWrite(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

// yaml.v3 frontmatter 解析边界：引号值、无围栏、非法 YAML
func TestParseFrontmatter(t *testing.T) {
	meta, body := ParseFrontmatter("---\nname: \"带引号\"\ndescription: 描述\n---\n正文")
	if meta.Name != "带引号" || meta.Description != "描述" || body != "正文" {
		t.Fatalf("引号值解析异常: %+v %q", meta, body)
	}
	meta, body = ParseFrontmatter("无围栏正文")
	if meta.Name != "" || body != "无围栏正文" {
		t.Fatalf("无围栏应原样返回: %+v %q", meta, body)
	}
	meta, _ = ParseFrontmatter("---\n: : : 非法\n---\n正文")
	if meta.Name != "" {
		t.Fatal("非法 YAML 应按无 frontmatter 处理")
	}
}

func TestListAndLoad(t *testing.T) {
	root := setupSkillDir(t)
	entries, err := List(root)
	if err != nil || len(entries) != 1 || entries[0].Name != "demo-skill" || entries[0].Meta.Name != "演示模版" {
		t.Fatalf("List 异常: %v %+v", err, entries)
	}

	loaded, err := Load(root, "demo-skill")
	if err != nil {
		t.Fatal(err)
	}
	if loaded.Body == "" || loaded.Meta.Description != "一个测试模版" {
		t.Fatalf("Load 异常: %+v", loaded)
	}
	// 辅助文件：references 注入、agents/ 跳过、assets 下的 .txt 也会收集（文本扩展名）但 agents 不收集
	if loaded.Files["references/style.md"] != "风格说明" {
		t.Fatalf("辅助文件缺失: %+v", loaded.Files)
	}
	for rel := range loaded.Files {
		if rel == "agents/openai.yaml" {
			t.Fatal("agents/ 不应注入")
		}
	}
}

// 路径遍历防护：白名单 + resolve 越界检查
func TestLoadTraversalGuard(t *testing.T) {
	root := setupSkillDir(t)
	if _, err := Load(root, "../evil"); err == nil {
		t.Fatal("非法名称应拒绝")
	}
	if _, err := Load(root, "no-such-skill"); err == nil {
		t.Fatal("不存在的 skill 应 404")
	} else if nf, ok := err.(*NotFoundError); !ok || nf.Message == "" {
		t.Fatalf("应为 NotFoundError: %v", err)
	}
}
