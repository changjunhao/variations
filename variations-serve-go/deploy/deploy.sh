#!/bin/bash
# 可选一键发版：交叉编译 → rsync 二进制与 assets → ssh 切换符号链接并重启
# 用法：./deploy/deploy.sh <ssh 目标>   例如 ./deploy/deploy.sh root@1.2.3.4
# 手动发版步骤见 DEPLOY-GO.md「发版更新流程」
set -euo pipefail

TARGET="${1:?用法: deploy.sh <user@host>}"
REMOTE_DIR=/opt/variations-serve
STAMP="$(date +%Y%m%d)-$(git -C "$(dirname "$0")/.." rev-parse --short HEAD 2>/dev/null || echo nogit)"

cd "$(dirname "$0")/.."

echo "==> 测试 + 交叉编译"
go test ./...
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags "-s -w" \
  -o dist/variations-serve-linux-amd64 ./cmd/variations-serve

echo "==> 上传二进制"
scp dist/variations-serve-linux-amd64 "$TARGET:/tmp/variations-serve-new"

echo "==> 同步 assets（热更新，无需重启即生效；此处随版同步）"
rsync -a --delete assets/ "$TARGET:$REMOTE_DIR/assets/"

echo "==> 同步静态页（/privacy /terms /support，nginx 直读）"
rsync -a --delete deploy/web/ "$TARGET:$REMOTE_DIR/web/"

echo "==> 切换版本并重启"
ssh "$TARGET" "
  install -m 755 /tmp/variations-serve-new $REMOTE_DIR/bin/releases/variations-serve-$STAMP &&
  ln -sfn releases/variations-serve-$STAMP $REMOTE_DIR/bin/variations-serve &&
  rm -f /tmp/variations-serve-new &&
  sudo systemctl restart variations-serve &&
  sleep 1 && systemctl is-active variations-serve
"

echo "==> 发版完成：${STAMP}（回滚：ln -sfn 上一版本 + systemctl restart）"
