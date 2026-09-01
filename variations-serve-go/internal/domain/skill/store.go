package skill

import (
	"log/slog"
	"os"
	"path/filepath"
	"sync/atomic"
	"time"

	"github.com/fsnotify/fsnotify"

	"variations-serve-go/internal/config"
	"variations-serve-go/internal/domain/pipeline"
)

// Snapshot 资产内存快照：skills 列表 + UI 元数据 + 管线注册表。
// atomic 指针持有，fsnotify 事件触发重建；请求路径零文件 IO。
type Snapshot struct {
	// Available skills 资产目录是否就位
	Available bool
	Skills    []Entry
	UI        map[string]ResolvedUi
	Overrides map[string]pipeline.Override
}

// Store 资产快照管理器（fsnotify 监听 + 防抖重建）
type Store struct {
	assetsDir     string
	SkillsDir     string
	uiFile        string
	overridesFile string
	logger        *slog.Logger
	snap          atomic.Pointer[Snapshot]
	watcher       *fsnotify.Watcher
	stop          chan struct{}
}

// NewStore 构建初始快照；assetsDir 缺失时 Available=false（/api/skills 将 503，其余接口不受影响）
func NewStore(assetsDir string, logger *slog.Logger) *Store {
	s := &Store{
		assetsDir: assetsDir,
		logger:    logger.With("scope", "assets"),
		stop:      make(chan struct{}),
	}
	if assetsDir != "" {
		s.SkillsDir = filepath.Join(assetsDir, "skills")
		s.uiFile = filepath.Join(assetsDir, "skills-ui.json")
		s.overridesFile = filepath.Join(assetsDir, "pipeline-overrides.json")
	}
	s.snap.Store(s.build())
	return s
}

// Snapshot 当前快照（永不返回 nil）
func (s *Store) Snapshot() *Snapshot {
	return s.snap.Load()
}

// LoadSkill 加载 skill 全文（按需读盘，与快照元数据分离——全文仅 compile 路径使用）
func (s *Store) LoadSkill(name string) (*Loaded, error) {
	return Load(s.SkillsDir, name)
}

// ReferencedProviders 当前注册表引用到的供应商（启动预检用）
func (s *Store) ReferencedProviders() map[config.ModelProvider]bool {
	return pipeline.ReferencedProviders(s.Snapshot().Overrides)
}

func (s *Store) build() *Snapshot {
	snap := &Snapshot{UI: make(map[string]ResolvedUi), Overrides: make(map[string]pipeline.Override)}
	if s.SkillsDir == "" {
		return snap
	}
	if _, err := os.Stat(s.SkillsDir); err != nil {
		s.logger.Warn("未找到 skills 资产目录，/api/skills 将不可用", "dir", s.SkillsDir)
		return snap
	}
	snap.Available = true
	entries, err := List(s.SkillsDir)
	if err != nil {
		snap.Available = false
		return snap
	}
	snap.Skills = entries
	uiStore := LoadUiStore(s.uiFile, s.logger)
	for _, e := range entries {
		snap.UI[e.Name] = ResolveUi(s.SkillsDir, uiStore, e.Name)
	}
	snap.Overrides = pipeline.LoadFile(s.overridesFile, s.logger)
	return snap
}

// StartWatch 启动 fsnotify 监听（递归 skills 目录 + assets 根），事件防抖 200ms 后重建快照。
// watcher 启动失败仅告警（降级为启动时快照，资产变更需重启——可接受兜底）。
func (s *Store) StartWatch() {
	if s.assetsDir == "" {
		return
	}
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		s.logger.Warn("fsnotify 初始化失败，资产热重载不可用（变更需重启服务）", "error", err.Error())
		return
	}
	s.watcher = watcher
	// assets 根（覆盖两个 JSON 文件的替换式写入）
	_ = watcher.Add(s.assetsDir)
	// skills 目录递归
	if s.SkillsDir != "" {
		_ = filepath.WalkDir(s.SkillsDir, func(path string, d os.DirEntry, err error) error {
			if err == nil && d.IsDir() {
				_ = watcher.Add(path)
			}
			return nil
		})
	}
	go s.loop()
	s.logger.Info("资产热重载已启用", "assetsDir", s.assetsDir)
}

func (s *Store) loop() {
	var timer *time.Timer
	for {
		select {
		case <-s.stop:
			return
		case err, ok := <-s.watcher.Errors:
			if ok && err != nil {
				s.logger.Warn("fsnotify 错误", "error", err.Error())
			}
		case _, ok := <-s.watcher.Events:
			if !ok {
				return
			}
			// 防抖：200ms 内多事件合并为一次重建
			if timer != nil {
				timer.Stop()
			}
			timer = time.AfterFunc(200*time.Millisecond, func() {
				snap := s.build()
				s.snap.Store(snap)
				s.logger.Info("资产快照已重载", "skills", len(snap.Skills))
			})
		}
	}
}

// Close 停止监听
func (s *Store) Close() {
	close(s.stop)
	if s.watcher != nil {
		_ = s.watcher.Close()
	}
}
