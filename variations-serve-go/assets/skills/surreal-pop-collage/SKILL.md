---
name: surreal-pop-collage
description: 把照片变成超现实波普拼贴画(surreal pop collage)——主体去色保留为"现实锚"，背景替换为巨大平涂色形，全图只有一个"不可能的巨物"。画幅跟随源图朝向（横版 4:3 / 竖版与方图 3:4）。用于把风景/人物/城市照做成黑白现实+平涂色块梦境感的超现实海报。
---

# 超现实波普拼贴 Surreal Pop Collage

**黑白现实、平涂梦境、一物不对劲、元素源于图、色从图中来。**

照片还是那张照片，但世界被换掉了：主体去色成黑白保留为"现实锚"，背景被 2–3 个巨大平涂色形替换，全图只有**一个**不可能的巨物——超现实的全部力量在于"只有一处不对劲"。

## 画幅

画布跟随源图朝向：横版源图 → 4:3 横版画布；竖版或方图源图 → 3:4 竖版画布。若系统提供了服务端测定的源图尺寸与朝向，以其为准，不得自行目测判断朝向。

## 决策优先级(冲突时按此顺序)

1. 锚点可识别——3 秒内认出原图主体，脸部核心区不许压元素
2. **只有一个不对劲**——巨物唯一；出现第二个不可能元素就删
3. 元素源于场景——巨物和色形都要能从原图/场景典故里指出处
4. 平涂纪律——色形无渐变、无立体阴影，这是和照片真实感对撞的关键
5. 明亮度——整体保持亮，禁止暗黑恐怖

## 第一步：场景卡

读原图，逐项写下：

- **锚点主体**：最有识别度的主体(人/物/景)，位置与占比
- **区域边界**：天空/地面/水面/墙面等可被平涂替换的区域
- **原生色**：2–3 个主色(色形颜色的来源)
- **主导动势**：最强方向线(对角/纵深/视线)
- **场景典故**：若为文化地标，它最出名的一句话知识(巨物的首选来源)

## 第二步：色形推导(禁止默认红日蓝天)

- **形状**：圆(日/月)、拱、地平线色块、整面天空，选 2–3 个，贴合场景原有区域边界
- **颜色三选一策略**：①场景已有色提纯(草绿→翠绿) ②互补色对撞(暖橙场景→群青) ③情绪反转色(阴郁场景→明黄)
- 平涂无渐变

## 第三步：巨物选择(禁止默认海豚鲸鱼)

按优先级选**一个**：

0. **典故巨物(文化地标首选)**：从景点最出名的典故里选，但先翻译成"可见的物件或动作"——运石→船队拖石、渔隐→巨网罩园、贴水→离水漂浮、以壁为纸→真山从纸里晕出、碑刻→刻线流成真河。只取大众记忆点(3 秒要懂)。自检：能写出"白居易的灯笼升成月亮"这种一句话配文才算焊上
1. **场景元素荒诞化**：把图里已有的小东西放大到不合常理(咖啡杯大过楼房)
2. **语义最远物**：和场景距离最远的东西(沙漠里游泳的人)
3. **尺度颠倒**：人小物大或反之

## 第四步：小元素与涂鸦

- 成群小元素(飞鸟/落叶/纸船)3–5 个，大小梯度 100/60/30，沿一条弧线分布
- 白色手绘涂鸦线条 2–3 条(刷痕/波浪线/星星)，做手工痕迹
- 禁止孤立单个装饰

## Prompt 编译器(四段式)

只写能变成像素的指令：

1. **风格定位**：竖版 `surreal pop collage, vertical 3:4`；横版 `surreal pop collage, horizontal 4:3`
2. **现实锚**：`keep the [主体] clearly recognizable but desaturated to black and white, preserving its texture`
3. **平涂世界与巨物**：`the background replaced by huge flat matte color shapes: [色形+颜色，按推导规则], one impossible giant element: [巨物，按选择规则], flat matte colors, no gradients`
4. **小元素与约束**：`[小元素群] in graduated sizes following an arc, a few white hand-drawn graffiti strokes, the black-and-white reality collides with the flat color world, no text, no watermark`

**范例**(纽约街景，竖版)：`surreal pop collage, vertical 3:4, keep this city street canyon recognizable but desaturated to black and white, the sky replaced by one huge flat lemon-yellow plane purified from the taxis, the street replaced by a flat brick-red plane, one impossible giant element: a giant traffic light hanging between the towers like a chandelier, a flock of small pigeons in graduated sizes following an arc, a few white hand-drawn graffiti strokes, flat matte colors, no gradients, no text, no watermark`

## 写入提示词的预防性约束

以下失败模式没有二次重来的机会，必须在提示词里提前封死：

- 渐变/立体阴影 → 必写 `flat matte colors, no gradients, no shadows on the color shapes`
- 出现第二个不可能巨物 → 只描述一个巨物，措辞用 `one impossible giant element`
- 装饰和场景两张皮 → 每个元素写明与原图的源形关系(extend into / becomes / continues as)
- 太满发闷 → 保留大面积平涂安静区，元素宁少勿多
- 照搬参考图俗套(红日/海豚/鲸鱼) → 色形与巨物一律走上面的推导规则，从原图指出处
- 文字乱码 → 提示词只写 `no text`，中文一律不进提示词

## 硬禁忌

第二个不可能的巨物；色形渐变；立体阴影；进口素材；暗黑恐怖基调；装饰压脸；相框式整圈包围；满版纹理覆盖；中文文字进 prompt(必乱码)；水印。

## 质量门(交付前逐项过)

- 画幅朝向与源图一致（横版 4:3 / 竖版与方图 3:4）？
- 3 秒内认出锚点？
- **全图只有一个"不对劲"？**
- 巨物能说出出处(场景元素/典故)？
- 色形颜色能从原图主色指出处？
- 平涂无渐变、无明暗立体？
- 小元素成群有梯度、沿弧线？
- 眯眼看：画面明亮，黑白现实与平涂梦境对撞清晰？
