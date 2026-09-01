# variations-serve-go

变奏 Variations 的 Go 后端：skill 模版编译（VL → 提示词）
与生图代理（qwen/ark 双供应商），设备令牌 + Sign in with Apple 会话双身份鉴权，
生图配额阶梯（游客体验 / 新用户特权 / IAP 已购余额），SQLite 持久化，
OSS 预签名直传（内容寻址 + 48h 生命周期）。

## 快速开始（本地开发）

```bash
cp .env.example .env      # 填入密钥（至少 REGISTER_SECRET；生图链路还需供应商/OSS 密钥，
                          # 账号与内购链路另需 APPLE_CLIENT_ID / IAP_PRODUCT_MAP）
make dev                  # 加载 .env 并运行（默认 :8788）
make test                 # 全量单测（含集成测试）
make smoke                # 契约验收（先起 make dev）
```

> 与 iOS Debug 构建（默认连 `localhost:8787`）联调时，把 `.env` 的 `PORT` 改为 8787。

## 端点

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| GET | `/healthz` | 无 | 探活 |
| POST | `/api/auth/device` | 公开（App Secret HMAC 门槛 + IP 限频） | 设备注册换取长期设备令牌 |
| POST | `/api/auth/apple` | 公开（SIWA identityToken 校验 + IP 限频） | Sign in with Apple 登录/注册，换发用户会话令牌 |
| POST | `/api/auth/logout` | Bearer | 登出并吊销当前令牌 |
| POST | `/api/account/delete` | Bearer（用户） | 注销账号及关联数据 |
| GET | `/api/quota` | Bearer | 配额摘要（三态口径 + 余额） |
| POST | `/api/billing/confirm` | Bearer（用户） | IAP 票据服务端验签落账 |
| GET | `/api/skills` | Bearer | 模版卡片（ETag/304） |
| GET | `/api/upload-ticket?ext=&hash=` | Bearer + 限频 | OSS 预签名票据（objectKey=uploads/{sha256}.{ext}） |
| GET | `/api/file-url?ext=&hash=` | Bearer + 限频 | 再次变奏：探测对象存在性并重签 GET 票据（已清理返回 410） |
| POST | `/api/compile` | Bearer + 每日防刷上限 | skillId/inlineSkill + imageUrl → prompt |
| POST | `/api/image` | Bearer + 配额扣减 | prompt + 参考图（+ 可选 skillId）→ 生成图 URL |

Bearer 支持双身份：设备令牌（`device:` principal，游客）与用户会话令牌（`user:` principal，SIWA 登录后）；
限频与配额口径均为 principal 优先、设备回退。

## 配额与计费

生图是唯一扣减点，先扣后行、失败原路退还，阶梯：

1. **游客**：终身 1 次体验（`GUEST_FREE_TOTAL`）；
2. **新用户特权**：SIWA 登录后 7 日内每日 10 次（`NEW_USER_PRIVILEGE_DAYS` / `NEW_USER_DAILY`）；
3. **已购余额**：IAP 积分包（`IAP_PRODUCT_MAP` productID:次数），特权额度优先、余额兜底；
4. **Staff 白名单**（`STAFF_USER_IDS` Apple sub）：生图不扣减。

编译不扣次数，仅按日防刷上限独立计数（游客/用户分档：`GUEST_DAILY_COMPILE_CAP` / `USER_DAILY_COMPILE_CAP`）。

## 技能资产

`assets/skills/` 内置 27 个官方技能模板（SKILL.md + agents/openai.yaml + 样图），
fsnotify 监听热重载，rsync 覆盖后无需重启即生效；
`assets/skills-ui.json` 提供客户端展示元数据，`assets/pipeline-overrides.json` 支持按 skill 指定供应商混搭。
样图经 `cmd/sync-samples` 运营工具同步到 OSS 公共读前缀（不进请求链路；未就位时 `sampleImageUrl` 优雅为 null）。

供应商三级选择：pipeline-overrides.json（按 skill）→ `COMPILE_PROVIDER`/`IMAGE_PROVIDER`（按管线）→ `MODEL_PROVIDER`（统一默认）。

## 架构

```
cmd/variations-serve        引导与装配（优雅关停）
cmd/sync-samples            运营工具：技能样图同步至 OSS 公共读前缀
internal/config             env 解析（12-factor，供应商三级回退，配额/IAP/Staff 配置）
internal/server             Gin 路由 + 中间件（Bearer auth/限频/bodyLimit/日志）+ 配额守卫（阶梯扣减/退还）
internal/auth               设备注册 + SIWA 登录（identityToken/JWS 校验）+ token 签发/哈希 + RegisterGate（可升级 App Attest）
internal/handlers           业务端点（严格类型化请求：账号/计费/配额/skills/upload-ticket/file-url/compile/image）
internal/domain/skill       skill 加载/UI 元数据/JPEG 探测 + fsnotify 快照热重载
internal/domain/pipeline    按 skill 的供应商混搭注册表
internal/domain/model       VL 编译/生图（Responses API、seedream 钳制）+ 校验
internal/domain/oss         OSS V4 预签名（PUT 1h / GET ≤2h）+ HeadObject 存在性探测（再次变奏重签）
internal/upstream           池化 http.Client（ctx 超时 max(T-5s,10s)）
internal/store              SQLite（modernc 纯 Go）+ golang-migrate（embed）：auth_tokens/users/quota 账本
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
