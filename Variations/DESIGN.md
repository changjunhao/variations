# 变奏 Variations · 设计系统 DESIGN.md

> 产品：照片的艺术变奏（iOS/iPad，SwiftUI）
> 设计语言：**纸上乐谱（Score on Paper）**——纸为底，墨为文，朱为记。
> 原则：界面是安静的谱面，作品（生成的图像）永远是最响的音符。

---

## 1. 设计理念

| 原则 | 含义 |
|---|---|
| 主题与变奏 | 照片是主题，界面是谱面；每次生成是"变奏 No.X"，编号以衬线体呈现，是全 App 的标志性记号 |
| 纸感三色 | 全 App 只用三个色彩家族：**纸**（背景）、**墨**（内容）、**朱**（唯一行动色/印章感标记） |
| 作品优先 | 界面克制度与留白对齐产品产出的 zine 审美：低饱和、暖调、无渐变、无霓虹 |
| 谱面动效 | 动效节奏像乐句：轻起轻落（spring），不弹跳、不闪烁；生成等待是"谱写中" |

---

## 2. Token 架构（三层，iOS 载体）

```
Primitive（原始值）   →  Assets.xcassets 颜色集（Any/Dark 双值）+ 数字常量
Semantic（语义别名）  →  Swift: Color.surface / Color.inkPrimary / Spacing.card …
Component（组件令牌） →  组件内部默认值（按钮高度、卡片圆角等，就近定义）
```

命名规范：`{类别}.{名称}.{变体}.{状态}`，如 `Color.vermilion.500`、`Spacing.card.padding`。

---

## 3. Primitive Tokens

### 3.1 色板 · 纸（暖白，非冷灰）

| Token | Hex（亮色） | 用途 |
|---|---|---|
| `paper-50` | `#FDFCF9` | 最浅面（输入框内底） |
| `paper-100` | `#FAF8F3` | **页面背景** |
| `paper-200` | `#F4F1E9` | 卡片/二级面 |
| `paper-300` | `#EAE5D9` | 分隔线·浅 |
| `paper-400` | `#DDD6C6` | 边框 |

### 3.2 色板 · 墨（暖黑）

| Token | Hex（亮色） | 用途 |
|---|---|---|
| `ink-900` | `#1E1B17` | **主文字** |
| `ink-700` | `#3A362F` | 标题次级 |
| `ink-500` | `#6B655A` | 次要文字（muted） |
| `ink-300` | `#A9A294` | 占位/禁用 |

### 3.3 色板 · 夜谱（暗色模式背景族）

| Token | Hex（暗色） | 用途 |
|---|---|---|
| `night-900` | `#191613` | 暗色页面背景 |
| `night-800` | `#221F1A` | 暗色卡片 |
| `night-700` | `#2E2A24` | 暗色输入/分隔 |

### 3.4 色板 · 朱（唯一强调色）

| Token | Hex | 用途 |
|---|---|---|
| `vermilion-600` | `#A63A26` | 按压态 / 暗色警示 |
| `vermilion-500` | `#BE3E2B` | **主行动色**（按钮、进度、选中） |
| `vermilion-400` | `#D95740` | 暗色模式主行动（提亮） |
| `vermilion-100` | `#F6E3DD` | 浅标记底（徽记、高亮行） |

### 3.5 状态色（暖调，低饱和）

| Token | Hex | 说明 |
|---|---|---|
| `moss-500` | `#587D4F` | 成功（上传完成等） |
| `ochre-500` | `#C08A2D` | 警示 |
| — | `vermilion-600` | **错误复用朱色**（朱即印章即警示，全 App 不引入第四个彩色） |

### 3.6 字阶（pt，Dynamic Type 基准）

| Token | 值 | 字体 | 用途 |
|---|---|---|---|
| `font-display` | 34 / 斜体 | **New York / Songti SC 衬线** | 变奏编号 "Variation No.3"（标志记号） |
| `font-title-1` | 28 | 系统 Semibold | 页面大标题 |
| `font-title-2` | 22 | 系统 Semibold | 区块标题（模版分类） |
| `font-headline` | 17 | 系统 Semibold | 卡片名、按钮 |
| `font-body` | 17 | 系统 Regular | 正文 |
| `font-subhead` | 15 | 系统 Regular | 卡片描述 |
| `font-caption` | 12 | 系统 Regular | 辅助说明 |

编号格式规范：`Variation No.X`（英文衬线斜体）或 `第 X 号变奏`（宋体），编号永远衬线，其余永远无衬线。

### 3.7 间距（4pt 基数）

`2 / 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 56`

### 3.8 圆角

| Token | 值 | 用途 |
|---|---|---|
| `radius-xs` | 4 | 徽记、小标签 |
| `radius-sm` | 8 | 按钮、输入框 |
| `radius-md` | 12 | 模版卡片、图片 |
| `radius-lg` | 16 | 弹层、结果舞台 |

### 3.9 阴影（纸落在桌上，极轻）

| Token | 值 |
|---|---|
| `shadow-paper` | `y:2 blur:8 color:#1E1B17@8%` |
| `shadow-raised` | `y:6 blur:16 color:#1E1B17@12%`（仅悬浮卡/弹层） |

### 3.10 动效时长

| Token | 值 | 用途 |
|---|---|---|
| `duration-fast` | 150ms | 按压、选中 |
| `duration-normal` | 250ms | 卡片展开、推入 |
| `duration-slow` | 400ms | 结果揭示、sheet |

---

## 4. Semantic Tokens（亮 / 暗双主题）

| Semantic | 亮色引用 | 暗色引用 | 说明 |
|---|---|---|---|
| `Color.surface` | `paper-100` | `night-900` | 页面底 |
| `Color.surfaceCard` | `paper-200` | `night-800` | 卡片面 |
| `Color.surfaceInput` | `paper-50` | `night-700` | 输入底 |
| `Color.inkPrimary` | `ink-900` | `paper-100` | 主文字 |
| `Color.inkSecondary` | `ink-500` | `ink-300` | 次文字 |
| `Color.hairline` | `paper-300` | `night-700` | 分隔线（0.5pt） |
| `Color.action` | `vermilion-500` | `vermilion-400` | 行动色 |
| `Color.actionPressed` | `vermilion-600` | `vermilion-500` | 按压 |
| `Color.actionOn` | `paper-50` | `paper-50` | 行动色上的文字 |
| `Color.mark` | `vermilion-500` | `vermilion-400` | 编号/选中标记 |
| `Color.markSurface` | `vermilion-100` | `night-700` | 浅标记底 |

Swift 实现：所有颜色在 Assets.xcassets 建 Any Appearance + Dark Appearance 双值；语义层用 `extension Color` 暴露，**组件永远只用语义层**。

---

## 5. Component Specs（核心组件）

### 5.1 TemplateCard（模版卡片 · Home）

| 属性 | 默认 | 按压 |
|---|---|---|
| 背景 | `surfaceCard` | `surfaceCard` + `shadow-paper→raised` 过渡 |
| 圆角 | `radius-md` 12 | 同 |
| 结构 | 样图（3:5，占卡上部）+ 名称 `font-headline` + 描述 `font-subhead` `inkSecondary` | 同 |
| 内边距 | 图 0 / 文字区 12pt | — |
| 尺寸 | iPhone 2 列 / iPad 4 列；卡最小宽 160pt | — |

### 5.2 PrimaryButton（开始变奏 / 再变奏一次）

| 属性 | 默认 | 按压 | 禁用 | 加载中 |
|---|---|---|---|---|
| 背景 | `action` | `actionPressed` | `surfaceCard` | `action`（文字→谱线动画） |
| 文字 | `actionOn` `font-headline` | 同 | `inkSecondary` | 同 |
| 形状 | `radius-sm` 8，高 50pt，全宽（流程页） | 同 | 同 | 同 |
| 反馈 | — | scale 0.97（150ms） | — | — |

### 5.3 PromptEditor（提示词编辑器 · 核心界面）

- 容器：`surfaceInput` 底、`radius-sm`、内边距 16pt
- 字体：`font-body`、行距 1.5×；**已编辑过的文字用 `inkPrimary`，编译原文未动时用 `inkSecondary`**（让"我改过"可见）
- 顶部工具行：「重新编译」「恢复原文」（文字按钮，`mark` 色）+ 字数统计 `font-caption`（超 16000 变 `ochre-500`）
- 底部固定：「开始变奏」PrimaryButton

### 5.4 ComposingProgress（谱写变奏 · 生成等待）

- 中心：衬线斜体「谱写变奏…」+ 其下五线谱式进度条（3 条 0.5pt `hairline` 横线，朱色音符点沿谱面匀速移动，60s 线性循环）
- 不用系统转圈；文案轮换：`谱写变奏… / 第 X 号变奏排练中…`（每 15s）
- 可取消（返回上一页，文字按钮）

### 5.5 ResultStage（结果舞台）

- 编号先行：`font-display` 衬线 "Variation No.X" 以 250ms 淡入于图像上方
- 图像揭示：scale 0.94→1.0 + 上移 8pt，`duration-slow`，曲线 gentle spring
- 操作行（图像下方）：存相册 / 分享 / **再变奏一次**（PrimaryButton 小号，高 36pt）
- 页脚：`font-caption` `inkSecondary`「由 AI 生成 · 变奏 Variations」
- 导出水印：右下角 `paper-100@70%` 底 + `ink-500` "Variation No.X"，3pt 边距

### 5.6 NumberBadge（编号徽记 · 列表/历史）

- `markSurface` 底、`radius-xs`、`mark` 色衬线斜体编号（如 "No.7"），高 20pt

### 5.7 SIWAButton（通过 Apple 登录 · 系统控件例外）

- **唯一允许脱离朱色体系的控件**：Apple HIG 强制样式。亮色模式 `.black`、暗色模式 `.white`；`radius-sm` 8、高 50pt、全宽——与 PrimaryButton 同尺寸，并排出现时视觉对齐
- 出现位置仅两处：「我的」页身份票券卡（未登录态）、游客配额耗尽引导
- 文案用系统本地化（"通过 Apple 登录"），不自定义、不套朱色、不加阴影
- 点击后系统弹出授权面板，App 侧不做任何中间页

### 5.8 ProfilePage（「我的」页 · 第三 Tab）

第三个 Tab 由「设置」更名为「**我的**」（图标 `person.crop.circle`）：IAP 上线后该 Tab 的重心是身份与权益，「设置」语义已不能命名目的地。页面自上而下四段：

1. **身份票券卡**（`card` 底、`radius-md`、padding 16）
   - 已登录：身份徽记放大至 **56pt** 圆（`markSurface` 底 + `mark` 色衬线首字符，无姓名用音符 𝄞）+ 名称 `font-headline` + 邮箱 `font-caption` `inkSecondary`（私密转发邮箱显示「已隐藏邮箱地址」）；卡末两行「退出登录」（`inkSecondary`）/「注销账号」（`vermilion-600`，二次确认弹层以 `font-caption` 明示删除范围）
   - 未登录：SIWAButton（5.7）+ 一行 `font-caption` `inkSecondary`「游客 1 次体验 · 登录享 7 日每日 10 次特权」——权益叙事紧贴登录按钮，转化路径最短
2. **权益行 QuotaLine v2**（5.9）：右端「购买次数」为全页**唯一朱色行动**（文字按钮，`mark` 色）→ PaywallSheet（5.12）
3. **设置分组**：外观 / 清除缓存 / 设备身份 / 服务器地址（仅 dev）/ 版本——原设置卡片原样下沉，**不另设设置子页**（当前规模多一层 push 违反 fewer steps；待购买记录/客服进入再提升）
4. 页脚 `font-caption` `inkSecondary`「变奏 x.x.x」

克制守则：「我的」页只承载身份 / 权益 / 设置三类内容，永不放运营 banner、推荐位、会员等级体系。

### 5.9 QuotaLine v2（权益行 · 三态）

- **游客态**：`font-subhead`「体验额度」+ 右 `font-caption`「余 1 次」；耗尽后文字变 `vermilion-600`「已用完」+ 同行文字按钮「登录得 7 日特权」（`mark` 色）
- **特权态**（登录且 7 日窗口内）：「今日额度」+ 右「余 N / 10 次 · 特权剩 D 天」；其下 2pt 谱线横轨，剩余比例以 `mark` 色填充（复用谱面语言）
- **已购态**（特权过期或耗尽后）：「已购次数」+ 右「N 次」——**永久余额只以数字直陈，不画进度条/倒计时**（进度条暗示消耗期限，语义错误）
- 右端常驻「购买次数」文字按钮（`mark` 色，全页唯一朱色行动）；**创作者模式（staff）不限次数，隐藏该入口**
- 无倒计时、无闪烁；数字与填充变化以 150ms 交叉淡入淡出

### 5.10 ConsentGate（首次启动 · 隐私同意页）

- 全屏 `surface`，无导航栏；顶部衬线斜体 "Variations" 标志字，中部 `font-body` 简述数据用途（≤3 行），《用户协议》《隐私政策》为 `mark` 色文字链接
- 底部吸底两按钮：「同意并继续」PrimaryButton（朱，全宽）+「不同意」文字按钮（`inkSecondary`）
- **不同意不退出 App**：保持可浏览（首页/变奏集可逛），任何需要网络的操作就地提示「需先同意《隐私政策》」
- 仅首次启动出现一次；整体 `duration-slow` 淡入，无模态弹跳感

### 5.11 配额耗尽态（流程内 · 安静阻断）

- 「开始变奏 / 再变奏一次」进入 PrimaryButton 禁用态（5.2 规格）
- 按钮上方一行 `font-caption`：
  - 游客：「体验 1 次已用完」+ 同行文字按钮「登录 Apple 享 7 日每日 10 次」（`mark` 色，跳转「我的」页）
  - 特权期当日满：「今日 10 次已用完，明天零点再来」
  - 特权过期且无余额：「次数已用完」+ 同行文字按钮「购买次数」（`mark` 色，弹 PaywallSheet）
- **不弹模态、不自动跳页、不打断已编辑的提示词**——阻断是谱面上的一个休止符，不是警报

### 5.12 PaywallSheet（购买次数弹层）

- `presentationDetents([.medium])`，`presentationBackground(surface)`；弹簧入场 damping 1.0 / response 0.3（无 overshoot，第 7 节）
- 标题 `font-title-2`「购买次数」+ `font-caption`「永久有效 · 不退换」
- 三档 pack 纵向列表（`card` 底行卡、`radius-md`）：名称 `font-headline` + 次数衬线斜体记号（如 *60 次*，延续编号语言）+ 右端 `product.displayPrice` `font-headline`
- 购买按钮复用行卡整行按压（scale 0.97）；成功以 `moss-500` ∗ 行内确认，失败行内 `vermilion-600` 文案——不上阻断式弹窗

---

## 6. 布局

- **iPhone**：单列导航；Home 模版 2 列网格；流程页（选图→编译→编辑）垂直分步，主按钮吸底；胶囊 TabBar 三 Tab：首页 / 变奏集 / **我的**（5.8）
- **iPad**：`NavigationSplitView`——侧栏（变奏集/我的模版/我的，240pt）+ 内容区；Home 4 列网格；结果舞台居中限宽 720pt
- 页边距：iPhone 20pt / iPad 32pt；区块间距 40pt；安全区严格遵循
- 分隔线一律 0.5pt `hairline`（发丝线，谱面感）

---

## 7. 动效规范

| 场景 | 规格 |
|---|---|
| 通用按压 | scale 0.97，`duration-fast` |
| 页面推入 | 系统导航默认（不自定义） |
| 卡片→流程 | 卡片轻放大衔接（matchedGeometryEffect，`duration-normal`） |
| **变奏揭示**（标志动效） | 编号淡入 → 图像 0.94→1.0 归位，`duration-slow`，gentle spring |
| 谱写进度 | 朱点沿三线谱匀速，无闪烁 |
| 隐私同意页出现 | 整体淡入，`duration-slow`；无滑入弹跳 |
| 额度数字/谱线填充变化 | 150ms 交叉淡入淡出，无计数动画 |
| PaywallSheet 入场 | 弹簧 damping 1.0 / response 0.3（临界阻尼，无 overshoot）；Reduce Motion 降级纯淡入 |
| 禁用弹跳/视差/粒子 | 一律不用 |

---

## 8. 无障碍

- `inkPrimary` on `surface`：对比度 ≥ 13:1 ✅；`actionOn` on `action`：≥ 4.6:1 ✅；`action` on `surface`：≥ 4.5:1 ✅（供大按钮文字用）
- 全部控件 ≥ 44pt 命中区；支持 Dynamic Type（编号徽记随字号缩放）
- 图片卡片提供 label（模版 displayName）；生成结果标记 `accessibilityLabel("AI 生成图像，第 X 号变奏")`
- 状态色永不只靠颜色传达（成功√、警示! 图标 + 文字）
- SIWAButton 用系统控件自带无障碍标签；身份徽记首字符不读字（装饰性，设 `accessibilityHidden`），身份卡整体朗读「已登录，{名称}」
- 权益行朗读完整语义：特权态「今日额度，剩余 N 次，共 10 次，特权剩 D 天」；已购态「已购次数，N 次」；谱线填充仅装饰
- 配额耗尽的禁用按钮保留焦点，朗读「已用完」状态而非静默消失

---

## 9. SwiftUI 实现指引

```
ios/Variations/DesignSystem/
├── Tokens.swift            # 间距/圆角/时长常量（Spacing.radius.duration 枚举）
├── Color+Semantic.swift    # extension Color：surface/inkPrimary/action…
├── Typography.swift        # Font.display(衬线编号)/headline…（Dynamic Type 映射）
├── Components/
│   ├── TemplateCard.swift
│   ├── PrimaryButton.swift
│   ├── PromptEditor.swift
│   ├── ComposingProgress.swift
│   ├── ResultStage.swift
│   ├── NumberBadge.swift
│   ├── ProfileView.swift       # 「我的」页（身份票券卡 + 权益行 + 设置分组）
│   ├── QuotaLine.swift         # 权益行三态（游客/特权/已购）+ 迷你谱线
│   ├── PaywallSheet.swift      # 购买次数弹层（StoreKit 2 三档 pack）
│   └── ConsentGate.swift       # 首次启动隐私同意页
└── Assets.xcassets         # 原始色板（Any/Dark 双值）
```

守则：
1. 视图代码**禁止硬编码 hex**，只用语义色；新色需求先回到第 3 节加 token
2. 编号一律衬线、正文一律无衬线，不混用
3. 强调色只有朱——任何"再加一个彩色"的提议先质疑
4. 阴影只两档；不新增投影
5. 暗色模式是"夜谱"（第 3.3 节），不是反转

---

## 10. Do / Don't

| ✅ Do | ❌ Don't |
|---|---|
| 留白充足，像谱面呼吸 | 用渐变、玻璃拟态、霓虹光效 |
| 衬线编号作为仪式感记号 | 界面大字全部衬线化 |
| 朱色只给"下一步行动" | 朱色当装饰色大面积铺 |
| 纸感暖灰体系 | 引入冷灰（#808080 系）或纯黑纯白 |
| 结果页让图像占屏 ≥70% | 图像周围堆功能按钮 |
| SIWA 按钮保持系统黑/白样式 | 给登录按钮套朱色或自定义皮肤 |
| 额度以文字 + 谱线安静呈现 | 倒计时动画、闪烁催促、强弹窗 |
| 不同意隐私政策仍可浏览 | 不同意就退出/卡死 App |
| 配额耗尽是休止符（禁用 + 一行说明） | 阻断式弹窗、自动跳登录页 |
| 「我的」页只放身份/权益/设置三类内容 | 运营 banner、推荐位、会员等级体系 |
| 已购余额用数字直陈（永久有效） | 给永久余额画进度条/倒计时 |
| 朱色在「我的」页只给「购买次数」 | 票券卡加渐变/烫金等装饰 |
