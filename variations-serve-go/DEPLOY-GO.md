# variations-serve-go 部署运维手册（阿里云 ECS，无 Docker）

形态：本地交叉编译 linux/amd64 静态二进制 → 手动上传 ECS → systemd 拉起。
交付物三件套：**二进制 + assets/ 目录 + deploy/ 配置模板**（migrations 已 embed 进二进制）。

## 构建产物

```bash
make test      # 全量单测（含集成测试）
make release   # CGO_ENABLED=0 GOOS=linux GOARCH=amd64 → dist/variations-serve-linux-amd64
```

- 倚天 ARM 实例：`GOARCH=arm64`，其余流程不变
- 本机验证：`make dev` + `make smoke` 后再发布

## 服务器目录布局

```
/opt/variations-serve/
├── bin/variations-serve                     # 当前版本（符号链接 → releases/ 中某版本）
├── bin/releases/variations-serve-<yyyyMMdd>-<git短hash>   # 历史版本，保留最近 3 个供回滚
├── assets/                                  # skills 资产（rsync 自仓库 variations-serve-go/assets）
├── data/                                    # variations.db 及备份（服务自动创建）
└── variations.env                           # 生产环境变量（chmod 600）
/etc/systemd/system/variations-serve.service
```

## 首次初始化检查清单（按序执行）

1. **用户与目录**
   ```bash
   sudo useradd -r -s /usr/sbin/nologin variations
   sudo mkdir -p /opt/variations-serve/{bin/releases,assets,data}
   sudo chown -R variations:variations /opt/variations-serve
   ```
2. **环境变量**
   ```bash
   sudo cp deploy/variations.env.example /opt/variations-serve/variations.env
   sudo vim /opt/variations-serve/variations.env
   # 必填：DASHSCOPE_API_KEY / ARK_API_KEY（按管线）、OSS_* 四项、
   #       REGISTER_SECRET（openssl rand -hex 32，与 iOS 端内置值一致）
   sudo chmod 600 /opt/variations-serve/variations.env
   ```
3. **systemd 服务**
   ```bash
   sudo cp deploy/variations-serve.service /etc/systemd/system/
   sudo systemctl daemon-reload && sudo systemctl enable variations-serve
   ```
4. **OSS bucket 一次性配置（必做）**
   - 生命周期规则：前缀 `uploads/`、按对象**最后修改时间**过期 **2 天**
     - 控制台：OSS → 目标 Bucket → 基础设置 → 生命周期 → 创建规则
     - ossutil 示例：
       ```bash
       cat > /tmp/lifecycle.json <<'EOF'
       {"Rules":[{"ID":"uploads-48h","Prefix":"uploads/","Status":"Enabled","Expiration":{"Days":2}}]}
       EOF
       ossutil lifecycle --method put oss://<your-bucket> /tmp/lifecycle.json
       # 验证：ossutil lifecycle --method get oss://<your-bucket>
       ```
   - 确认 bucket 为**私有读写**（预签名 URL 承担访问控制）
5. **安全组**：放行 8787/tcp（若上 nginx/TLS 反代则仅放行 443，反代需 `proxy_read_timeout 310s;` 透传 5min 长请求）
6. **上传首版并启动**
   ```bash
   scp dist/variations-serve-linux-amd64 ecs:/tmp/
   rsync -a --delete variations-serve-go/assets/ ecs:/opt/variations-serve/assets/
   # 服务器上：
   sudo install -m 755 -o variations -g variations /tmp/variations-serve-linux-amd64 \
     /opt/variations-serve/bin/releases/variations-serve-$(date +%Y%m%d)-init
   sudo -u variations ln -sfn releases/variations-serve-$(date +%Y%m%d)-init /opt/variations-serve/bin/variations-serve
   sudo systemctl start variations-serve
   ```
7. **验证**
   ```bash
   curl -s localhost:8787/healthz                    # {"ok":true,...}
   journalctl -u variations-serve -n 30 --no-pager   # 无 ERROR，迁移成功
   # 本地全量契约验收（REGISTER_SECRET 需与服务器一致）：
   SMOKE_BASE_URL=http://<ECS_IP>:8787 SMOKE_REGISTER_SECRET=<secret> node scripts/smoke-go.mjs
   # 真实链路（需供应商 key + bucket 图）：
   SMOKE_BASE_URL=... SMOKE_REAL_CALLS=1 SMOKE_IMAGE_URL=https://<bucket>.<region>.aliyuncs.com/xxx.jpg node scripts/smoke-go.mjs
   ```

## 发版更新流程（手动上传）

1. 本地：`make test && make release`
2. 上传：
   ```bash
   scp dist/variations-serve-linux-amd64 ecs:/tmp/
   rsync -a --delete variations-serve-go/assets/ ecs:/opt/variations-serve/assets/   # 资产有变更时
   ```
3. 服务器切换版本：
   ```bash
   sudo install -m 755 -o variations -g variations /tmp/variations-serve-linux-amd64 \
     /opt/variations-serve/bin/releases/variations-serve-$(date +%Y%m%d)-<git短hash>
   sudo ln -sfn releases/<新版本> /opt/variations-serve/bin/variations-serve
   ```
4. `sudo systemctl restart variations-serve`（SIGTERM 优雅关停，等待在途长请求最多 30s）
5. 验证：`systemctl status` + `journalctl -u variations-serve -n 50 --no-pager` + `curl localhost:8787/healthz` + smoke 抽测
6. **回滚（< 1 分钟）**：符号链接指回上一版本 → `sudo systemctl restart variations-serve`

> 快捷方式：`./deploy/deploy.sh user@host` 一键完成 1-4 步。

## 日常运维速查

| 场景 | 命令/说明 |
|---|---|
| 实时日志 | `journalctl -u variations-serve -f`（LOG_FORMAT=json 便于 `grep '"level":"ERROR"'`） |
| 日志容量 | journald 默认留存足够；必要时 `/etc/systemd/journald.conf` 调 `SystemMaxUse=1G` |
| DB 备份 | cron 每日：`sqlite3 /opt/variations-serve/data/variations.db ".backup '/opt/variations-serve/data/backup/variations-$(date +%F).db'"` 保留 7 天。**禁止直接 cp 库文件**（WAL 不完整） |
| skills 资产热更新 | rsync 覆盖 assets 后**无需重启**（fsnotify 监听 + 快照重载，~200ms 生效） |
| migration 变更 | 随二进制启动自动执行 up；down 不自动执行（`go run -tags ... migrate` CLI 或手工 SQL） |
| 健康探活 | 阿里云云监控站点监控 `GET /healthz`；进程层由 systemd `Restart=on-failure` 兜底 |
| 吊销设备 | 当前无管理端点，手工 SQL：`UPDATE devices SET revoked_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id='<deviceId>';`（该设备全部 token 立即失效） |

## 环境变量表

| 变化 | 说明 |
|---|---|
| **移除** `API_TOKEN` | 鉴权改为设备身份令牌（Bearer） |
| `VL_MODEL` → **`QWEN_VL_MODEL`** | 与 `QWEN_IMAGE_MODEL` 命名对齐；启动期检测旧名打告警 |
| **新增** `REGISTER_SECRET` | 设备注册 App Secret（未配置则注册端点 503） |
| **新增** `ADMIN_TOKEN`（可选） | 运维旁路 Bearer token，生产建议不配置 |
| **新增** `ASSETS_DIR` | 默认探测 `./assets`（随服务自包含）；生产固定 `/opt/variations-serve/assets` |
| **新增** `DB_PATH` | 默认 `./data/variations.db` |
| **新增** `AUTH_REGISTER_PER_MIN` | 设备注册 IP 限频，默认 10/min |
