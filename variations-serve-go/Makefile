# 变奏 Variations Go 后端：模版编译与生图代理
# 配置方式：纯环境变量（12-factor）。本地开发由 make dev 加载 .env；生产由 systemd EnvironmentFile 注入。
SHELL := /bin/bash

BIN := variations-serve

.PHONY: dev build test vet release clean smoke

## 本地开发：加载 .env（存在则加载）后热运行
dev:
	@if [ -f .env ]; then set -a; source ./.env; set +a; fi; \
	go run ./cmd/variations-serve

## 本机构建
build:
	go build -o dist/$(BIN) ./cmd/variations-serve

## 单元测试
test:
	go test ./...

vet:
	go vet ./...

## 交叉编译阿里云 ECS（linux/amd64）静态二进制；倚天 ARM 换 GOARCH=arm64
release:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o dist/$(BIN)-linux-amd64 ./cmd/variations-serve

clean:
	rm -rf dist

## Go 版契约验收（先起服务：make dev）
smoke:
	node scripts/smoke-go.mjs
