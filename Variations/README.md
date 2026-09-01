# Variations · iOS 客户端

变奏 Variations 的 iOS/iPad 胖客户端：本地编排三流程（官方模版 / 我的模版 / 直接输入），
图片经 OSS 预签名直传，服务端只编译提示词与调生图模型。
账号体系为 Sign in with Apple（游客可先体验），配额三态（游客体验 / 新用户特权 / IAP 已购余额）+ StoreKit 2 积分包，
首次启动有隐私同意闸门（中国区合规）。

## 联调步骤

1. 起后端（同仓库 `variations-serve-go/`，Go 版为唯一服务端）：

   ```bash
   cd ../variations-serve-go
   cp .env.example .env   # 至少填 REGISTER_SECRET；生图链路还需供应商/OSS 密钥，
                          # 账号与内购链路另需 APPLE_CLIENT_ID / IAP_PRODUCT_MAP
   make dev               # 加载 .env 运行
   ```

   > `.env.example` 默认 `PORT=8788`；iOS Debug 构建默认连 `http://localhost:8787`，
   > 建议把 `.env` 的 `PORT` 改为 8787，或在 App 设置页覆盖地址。

2. Xcode 打开 `Variations.xcodeproj`，跑模拟器或真机。首次克隆需复制 `Configurations/Secrets.xcconfig.example` 为同目录 `Secrets.xcconfig` 并填写 `REGISTER_SECRET`（与后端 `.env` 一致；该文件不入库，缺失时可构建但设备注册会失败）。

3. App 环境由构建配置决定（Debug = 开发环境，Release = 正式环境）：
   - Debug 构建内置默认地址 `http://localhost:8787`，模拟器开箱即用，无需配置；
   - 真机联调在「设置」页将服务器地址覆盖为 `http://<Mac 局域网 IP>:8787`（同一 Wi-Fi；`ipconfig getifaddr en0` 查询）；
   - Release 构建强制使用构建期正式地址，设置页不可改。
   - 鉴权为**设备身份令牌**：首次启动自动调 `POST /api/auth/device` 注册换取长期 token（存 Keychain），无需手工配置；
     后端 `.env` 的 `REGISTER_SECRET` 须与客户端 `Configurations/Secrets.xcconfig` 一致（经 Info.plist 构建期注入，不入库）。
   - **账号（可选）**：Sign in with Apple 登录后调 `POST /api/auth/apple` 换发用户会话令牌（存 Keychain，与设备令牌同构），
     解锁新用户特权配额；游客身份仍可完成一次体验。本地联调需后端配置 `APPLE_CLIENT_ID`（正式签名 + 真机才可完整走通）。

4. 后端监听：默认 `HOST=0.0.0.0` 供真机/局域网联调；鉴权闸门由设备 token 承担。

5. 首页选官方模版 → 选图 → 生成提示词 → 开始变奏。

> ATS 已收紧为 `NSAllowsLocalNetworking`（仅放行 dev 局域网 http 联调：回环/私有网段/.local），公网一律 https；应用层校验（ServerURLValidator）与此同口径。

## 环境切换（构建期注入）

注入链：`Configurations/Debug.xcconfig|Release.xcconfig`（`APP_ENVIRONMENT = dev|prod`）→ `Info.plist` 的 `AppEnvironment = $(APP_ENVIRONMENT)` → `Services/AppConfiguration.swift` 类型化解析。

- 基地址映射收敛在 `AppConfiguration.swift` 单一事实源（xcconfig 里勿写 URL，`//` 会被当注释截断）；
- 注册门槛密钥同源注入：`Configurations/Secrets.xcconfig`（gitignore 不入库，`#include?` 可选引入）→ `Info.plist` 的 `RegisterSecret = $(REGISTER_SECRET)` → `Services/DeviceAuth.swift` 运行时读取；源码仓库不含明文值；
- 正式环境地址在 `AppConfiguration.prodBaseURLString`（当前 `https://variations.ifable.cn`），如需变更只改这一处；
- dev 设置页手填地址仅作为覆盖项，空/非法时回落内置默认；prod 忽略一切覆盖；
- skills 磁盘缓存与 Keychain 凭据均按环境命名空间隔离（`Caches/<env>/`、Keychain service 带环境后缀），防 dev/prod 同设备串台。

## 测试

```bash
# 单测 + 快照比对
xcodebuild test -scheme Variations \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:VariationsTests

# 重录快照基线（设计改版后）
SNAPSHOT_RECORD=1 xcodebuild test -scheme Variations \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:VariationsTests/HomeSnapshotTests

# UI 冒烟
xcodebuild test -scheme Variations \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:VariationsUITests/SmokeUITests
```

## 结构

- `DesignSystem/` 令牌与通用组件（日谱/夜谱动态色）
- `Models/` DTO 与 SwiftData 模型
- `Services/` APIClient / DeviceAuth（设备令牌） / AccountAuth（SIWA 会话） / Store（StoreKit 2 积分包） / QuotaStore（配额三态） / ConsentStore（隐私同意） / 压缩 / OSS 直传 / 设置 / 环境配置 / AppServices 依赖容器 / Nuke 引导
- `Features/` 按页面分目录（Home / Flow / Collection / Direct / SkillEditor / Result / Settings 我的页 / Account 同意闸门与付费墙）；`Navigation.swift` 路由、`Router.swift` 栈
- `Stores/` 结果图与缩略图文件存储
- `AppStore/` App Store 营销资产（puppeteer 渲染截图/预览视频的 HTML 源）；配套 `MarketingSeed.swift`（仅 DEBUG 注入演示记录）
