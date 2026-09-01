# variations-serve-go

变奏 Variations 的 Go 后端：skill 模版编译（VL → 提示词）
与生图代理（qwen/ark 双供应商），设备身份令牌鉴权，SQLite 持久化，
OSS 预签名直传（内容寻址 + 48h 生命周期）。

## 快速开始（本地开发）

```bash
cp .env.example .env      # 填入密钥（至少 REGISTER_SECRET；业务接口需供应商/OSS 密钥）
make dev                  # 加载 .env 并运行（默认 :8788）
make test                 # 全量单测（含集成测试）
make smoke                # 契约验收（先起 make dev）
```

> 与 iOS Debug 构建（默认连 `localhost:8787`）联调时，把 `.env` 的 `PORT` 改为 8787。

## 端点

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/healthz` | 无 | 探活 |
| POST | `/api/auth/device` | 公开（App Secret HMAC 门槛 + IP 限频） | 设备注册换取长期 token |
| GET | `/api/skills` | Bearer | 模版卡片（ETag/304） |
| GET | `/api/upload-ticket?ext=&hash=` | Bearer + 设备限频 | OSS 预签名票据（objectKey=uploads/{sha256}.{ext}） |
| GET | `/api/file-url?ext=&hash=` | Bearer + 设备限频 | 再次变奏：探测对象存在性并重签 GET 票据（已清理返回 410） |
| POST | `/api/compile` | Bearer | skillId/inlineSkill + imageUrl → prompt |
| POST | `/api/image` | Bearer | prompt + 参考图（+ 可选 skillId）→ 生成图 URL |

## 技能资产

`assets/skills/` 内置 21 个官方技能模板（SKILL.md + agents/openai.yaml + 样图），
fsnotify 监听热重载，rsync 覆盖后无需重启即生效；
`assets/skills-ui.json` 提供客户端展示元数据，`assets/pipeline-overrides.json` 支持按 skill 指定供应商混搭。

供应商三级选择：pipeline-overrides.json（按 skill）→ `COMPILE_PROVIDER`/`IMAGE_PROVIDER`（按管线）→ `MODEL_PROVIDER`（统一默认）。

## 架构

```
cmd/variations-serve        引导与装配（优雅关停）
internal/config             env 解析（12-factor，供应商三级回退）
internal/server             Gin 路由 + 中间件（Bearer auth/限频/bodyLimit/日志）
internal/auth               设备注册 + token 签发/哈希 + RegisterGate（可升级 App Attest）
internal/handlers           业务端点（严格类型化请求：skills/upload-ticket/file-url/compile/image）
internal/domain/skill       skill 加载/UI 元数据/JPEG 探测 + fsnotify 快照热重载
internal/domain/pipeline    按 skill 的供应商混搭注册表
internal/domain/model       VL 编译/生图（Responses API、seedream 钳制）+ 校验
internal/domain/oss         OSS V4 预签名（PUT 1h / GET ≤2h）+ HeadObject 存在性探测（再次变奏重签）
internal/upstream           池化 http.Client（ctx 超时 max(T-5s,10s)）
internal/store              SQLite（modernc 纯 Go）+ golang-migrate（embed）
assets/                     skills 技能资产 + skills-ui + pipeline-overrides（随服务自包含）
deploy/                     ECS 部署资产（systemd unit / env 模板 / 一键脚本）
```

## 部署

本地交叉编译静态二进制 → 手动上传阿里云 ECS → systemd 拉起（无 Docker），
nginx 反代 `variations.ifable.cn` → 127.0.0.1:8787。
完整运维手册：[DEPLOY-GO.md](./DEPLOY-GO.md)

```bash
make release             # dist/variations-serve-linux-amd64
./deploy/deploy.sh user@host   # 一键发版（编译 + 上传 + 切符号链接 + restart）
```
