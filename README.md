# 变奏 Variations

照片艺术变奏工具：选一个风格技能（skill）→ 上传照片 → 服务端 VL 模型把「照片 + 技能说明」编译成生图提示词 → 生图模型产出风格化变奏图。

iOS/iPad 胖客户端 + Go 轻量后端的 monorepo：客户端负责编排与展示，图片经 OSS 预签名直传，服务端只做提示词编译与生图代理，不存图。

## 仓库结构

```
Variations/            iOS/iPad 客户端（SwiftUI / SwiftData / Swift 6）
variations-serve-go/   Go 后端（Gin / SQLite / OSS 预签名，唯一服务端）
```

各子目录有独立 README：

- [Variations/README.md](./Variations/README.md) — 客户端联调、环境切换、测试
- [variations-serve-go/README.md](./variations-serve-go/README.md) — 后端快速开始、端点与架构
- [variations-serve-go/DEPLOY-GO.md](./variations-serve-go/DEPLOY-GO.md) — 生产部署运维手册（阿里云 ECS）

## 系统架构

```
┌────────────────────────┐          ┌─────────────────────┐        ┌──────────────┐
│  Variations iOS 客户端  │          │  variations-serve-go │        │  模型供应商   │
│                        │          │        (Gin)         │        │              │
│ ① 设备自助注册 ─────────┼─ token ─▶│ 设备鉴权 / 限频       │        │ 阿里百炼      │
│ ② 拉取技能卡片 ─────────┼─────────▶│ skills 资产(热重载)   │        │ · qwen3.7-plus│
│ ③ 原图压缩 → 预签名直传 ─┼──PUT───▶│ OSS V4 预签名 ────────┼──PUT──▶│   (VL 编译)  │
│                        │   OSS    │ ④ 编译提示词 ─────────┼───────▶│ · qwen-image │
│ ⑤ 展示/收藏变奏图       │◀─────────│ ⑤ 生成变奏图 ─────────┼───────▶│   (生图)     │
└────────────────────────┘          └─────────────────────┘        │ 火山方舟      │
                                                                    │ · doubao VL  │
                                                                    │ · seedream   │
                                                                    └──────────────┘
```

核心链路：

1. **设备身份令牌**：首次启动以自生成 UUID + HMAC proof 调 `POST /api/auth/device` 换取长期 token（存 Keychain），业务请求携带 `Authorization: Bearer`；401 自动重注册自愈
2. **原图直传**：客户端压缩后按内容寻址（SHA-256）取预签名 PUT 票据直传 OSS，服务端不经手图片字节；`uploads/` 前缀 48h 生命周期自动清理
3. **提示词编译**：`POST /api/compile` 以 VL 模型（Responses API）将技能 SKILL.md + 照片编译为结构化提示词
4. **生图**：`POST /api/image` 以提示词 + 参考图 URL 调生图模型，返回 OSS GET 预签名 URL
5. **再次变奏**：对象 48h 内存在则经 `GET /api/file-url` 探测重签新 GET 票据；已清理返回 410

## 技能（skills）

`variations-serve-go/assets/skills/` 内置 21 个官方技能模板（压印浮雕、墨迹海报、像素海报、超现实拼贴、有机针织、Minecraft 世界等），每个技能为自包含目录：

```
skills/<skill-id>/
├── SKILL.md            # 技能说明（编译进提示词）
├── agents/openai.yaml  # 编译参数（模型/尺寸等）
└── assets/sample.jpg   # 技能样图
```

资产目录经 fsnotify 监听，rsync 覆盖后无需重启即热重载生效。单个技能可在 `assets/pipeline-overrides.json` 指定供应商混搭（如某 skill 编译用 ark、生图用 qwen）。

## 模型供应商三级选择

优先级：`assets/pipeline-overrides.json`（按 skill）→ `COMPILE_PROVIDER` / `IMAGE_PROVIDER`（按管线）→ `MODEL_PROVIDER`（统一默认）→ 内置 qwen。

| 供应商 | VL 编译 | 生图 |
|---|---|---|
| qwen（阿里百炼） | qwen3.7-plus（Responses API） | qwen-image-3.0 |
| ark（火山方舟） | doubao-seed-2-0-lite | doubao-seedream-5-0 |

## 快速开始

### 后端

```bash
cd variations-serve-go
cp .env.example .env   # 至少填 REGISTER_SECRET；真实链路还需供应商/OSS 密钥
make dev               # 默认 :8788
make test && make smoke
```

### iOS 客户端

Xcode 打开 `Variations/Variations.xcodeproj` 跑模拟器；Debug 构建默认连 `http://localhost:8787`（本地 Go 服务把 `.env` 的 `PORT` 设为 8787 即可开箱即用）。详见 [Variations/README.md](./Variations/README.md)。

## 部署

生产形态：本地交叉编译 linux/amd64 静态二进制 → 上传阿里云 ECS → systemd 拉起（无 Docker），nginx 反代 `variations.ifable.cn`。一键发版：`./variations-serve-go/deploy/deploy.sh user@host`。完整手册见 [DEPLOY-GO.md](./variations-serve-go/DEPLOY-GO.md)。

客户端经 App Store 分发：Debug = 开发环境（地址可在设置页覆盖），Release = 正式环境（构建期注入地址，设置页只读）。
