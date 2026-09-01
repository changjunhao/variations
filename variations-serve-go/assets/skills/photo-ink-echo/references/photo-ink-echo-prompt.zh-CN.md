# Photo Ink Echo 中文 Production Prompt

使用用户提供的一张照片，创建一张摄影编辑作品。画面采用严格的 1:1 等分结构，版式跟随源图方向：横版或近方图采用上下结构（照片在上，面板在下）；竖版图采用左右结构（照片在左，面板在右）。两个区域等大，画布恰好是照片沿拼接轴加倍。

## 目录

- 最高优先级视觉参考
- 照片区域：原始照片
- 记忆选择逻辑
- 面板区域：Very Small Watercolor Memory Motif
- 主次层级与 Fragmented
- 图形尺寸、水彩语言与严格禁止
- 标题与最终删除检查

## 最高优先级视觉参考

生成前检查 assets/examples 中的全部示例图。

把示例图作为水彩层级、轻淡程度、未完成感、图形尺度和留白关系的最高优先级视觉参考。

示例图只提供风格依据。不要复制其中的主体、构图、配色或标题。用户上传的照片仍是唯一内容来源。

## 照片区域：原始照片

照片区域必须严格使用用户上传的原始照片。横版或近方图时照片区域在上、面板在下；竖版图时照片区域在左、面板在右。不得为给定方向选择另一种排布。

只允许 crop 或 reframe。

禁止 repaint、stylize、reconstruct、retouch、extend、replace 或改变照片中的任何真实内容。不要新增、删除或重画人物、物体、建筑、光线和环境。

## 记忆选择逻辑

不要问：

> “这张照片里有什么？”

必须问：

> “视线最先记住的唯一事物是什么？”

> “保留这段场景记忆所需的最少次要线索是什么？”

每张照片只选择 1 个最明确的 primary subject。

再选择 2 至 4 个 supporting cues。Supporting cues 可以是一条地平线、一段倒影、一个动作、一小块色彩、一处阴影、一段岸线、几根桅杆或一个邻近物体关系。

总视觉关系控制在约 3 至 5 个。除此之外的场景信息全部删除。

一个紧密连接、在照片中被读作整体的小群体可以算作一个 primary subject；不要借此保留大量人物。

## 面板区域：Very Small Watercolor Memory Motif

面板区域与照片区域等大，使用干净、温暖的象牙白或柔和米白色背景，并仅保留极轻微的优质水彩纸纹理。

面板不是原照片的缩小重画，也不是第二张完整插画。

它只能呈现一个 very small watercolor memory motif：

- one clear primary subject
- two to four quiet supporting traces
- large areas of silence around them

先画 primary subject，使它成为最清楚、最有识别度、局部对比最高的部分。

Supporting cues 必须明显更轻、更淡、更软、更少细节并且更不完整。

背景只能保留极微弱的颜色、水迹、局部轮廓、倒影或正在消失的边缘提示。不要保留完整环境。

## 主次层级

- Primary subject 必须一眼可辨。
- Primary subject 可以拥有唯一一个克制的深色或高饱和强调。
- Supporting cues 必须降低透明度、对比度、边缘完整度和细节量。
- 不允许多个元素拥有相同视觉重量。
- 不允许 supporting cues 与 primary subject 竞争。
- 不允许背景成为完整场景。

## Fragmented 的正确含义

Fragmented 是局部断裂和选择性缺失，不是模糊、散乱或失去主体识别度。

正确表现：

- 局部轮廓断开
- 次要边缘逐渐消失
- 控制性的空缺
- 未完成的淡色层
- 少量聚拢在主体附近的水彩残片

错误表现：

- 主体模糊不清
- 随机散点
- 装饰性飞溅
- 互不相关的物体散落
- 杂乱噪点
- 为制造碎片感而降低主体识别度

Primary subject 始终必须清楚。

## 图形尺寸与大留白

水彩主体必须非常小。把示例图视为可接受信息密度的上限，而不是放大或补全场景的许可。

建议 motif 的紧凑外包络约占面板宽度的 25% 至 38%，约占面板高度的 16% 至 28%。实际着色面积应更加稀疏。

让面板约 82% 至 90% 的区域在视觉上保持安静、未被占用。

将 motif 与标题作为一个小型整体放在面板视觉中心附近。不要为了填满空间而放大。

When in doubt, make the motif smaller and remove more information.

## 水彩语言

强化以下特征：

- light
- fragmented
- pale
- airy
- delicate
- unfinished
- transparent watercolor
- soft disappearing edges
- large negative space
- quiet editorial composition

使用透明水彩、稀释颜料、柔和晕染、局部淡墨、消散边缘、不完整色层和极少量干笔质感。

颜色必须来自原照片。使用约 2 至 4 个主要色系。大部分颜色保持低饱和、低对比和高透明度。

## 严格禁止

禁止生成：

- full-scene watercolor rendering
- miniature complete painting
- large watercolor motif
- too many objects
- equal visual importance between elements
- dense environment detail
- heavy rendering
- hard borders
- rectangular illustration blocks
- oval vignette
- poster-like composition
- realistic scene reconstruction
- thick or opaque paint masses
- harsh black outlines
- decorative splatter or scattered filler
- auxiliary lines, perspective guides, grids, or annotations
- cartoon treatment

面板区域不得出现矩形插画块、椭圆晕影、徽章式构图、边框或完整背景底形。

## 标题

在 motif 正下方紧密放置一行原创英文标题，长度为 2 至 5 个单词。

使用极小、极细、现代、克制的 minimalist sans-serif 字体，并略微增加字距。

标题颜色使用炭灰、柔和深褐或来自照片的克制深色。

除了这行标题，不允许出现任何其他文字、乱码、副标题、标签、说明、签名或水印。

## 最终删除检查

输出前逐项确认：

1. 照片区域是否只使用原始照片，只做了 crop 或 reframe，并且排布方向与源图方向一致？
2. 面板区域是否只有 1 个清楚的 primary subject？
3. Supporting cues 是否只有 2 至 4 个？
4. 总视觉关系是否控制在约 3 至 5 个？
5. Supporting cues 是否明显比主体更轻、更淡、更不完整？
6. 背景是否只剩微弱痕迹？
7. Primary subject 是否在 fragmented 边缘中仍然清楚？
8. Motif 是否非常小，并被大面积暖象牙白留白包围？
9. 是否完全避开所有完整场景、矩形块、椭圆晕影和海报式构图？

如果它看起来像一张缩小的完整水彩插画，说明信息过多：继续删除、淡化并缩小。

如果它看起来像一个清楚但不完整的记忆片段，说明结果正确。

只返回最终作品。
