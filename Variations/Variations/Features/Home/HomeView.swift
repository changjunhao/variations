//
//  HomeView.swift
//  Variations
//
//  首页（设计稿 01）：大标题 + 官方模版双列卡 + 我的模版 + 直接输入入口。
//

import SwiftUI
import SwiftData
import NukeUI

/// 首页宽度分档（纯函数，供单测直接验证）。
/// 不用 hSize/vSize 组合判断：iPadOS 窗口化后窗口可拖成任意宽高比，
/// 「hSize regular + vSize compact」不再等价于 iPad 横屏。
/// iPhone Duo 几何：外屏 466pt（compact）→ 两列；内屏 669/951pt（regular×regular）
/// → 三/四列，均落在既有档位区间；半折书本姿态折痕（division region）激活时
/// 奇数列减一避让（HIG：sheets/alerts/工具栏由系统位移，滚动内容豁免，grid 是
/// 开发者自己的责任区——division region 存在时偏好偶数列）。
nonisolated enum HomeGrid {

    /// 宽版式阈值（页边距 32 / 大标题交给侧栏页眉）
    static let wideThreshold: CGFloat = 600

    /// 官方模版网格列数：≥900 四列、≥600 三列、否则两列
    static func skillColumnCount(width: CGFloat) -> Int {
        if width >= 900 { 4 } else if width >= wideThreshold { 3 } else { 2 }
    }

    /// 折痕感知列数：division region 激活且列数为奇时减一（下限 2 列），
    /// 避免中列骑折痕；摊平（region 非激活）不降级，保持内容密度
    static func skillColumnCount(width: CGFloat, foldDivisionActive: Bool) -> Int {
        let base = skillColumnCount(width: width)
        guard foldDivisionActive, base % 2 == 1 else { return base }
        return max(2, base - 1)
    }

    /// 宽版式：页边距 32，否则 20（设计稿 01/10）
    static func isRegular(width: CGFloat) -> Bool {
        width >= wideThreshold
    }
}

/// 首页实测几何（onGeometryChange 单通道回灌）：内容宽 + 折痕激活态
private nonisolated struct HomeGeometry: Equatable, Sendable {
    var width: CGFloat
    var foldDivisionActive: Bool
}

struct HomeView: View {
    @Environment(AppServices.self) private var services
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSkillTemplate.createdAt) private var myTemplates: [UserSkillTemplate]

    @State private var skills: [SkillCard] = []
    @State private var loadError: String?
    /// 非 nil 时全屏预览该模版样图（捏合缩放 / 双击复位）
    @State private var previewSkill: SkillCard?
    /// 实测几何：窗口化下 size class 不再等价于「宽窄」，一律按实测宽度分档；
    /// 折叠设备半折时 division region（折痕）激活，网格降偶数列避让（HomeGrid 注释）。
    /// 宽度与折痕查询走同一 onGeometryChange 回调（单通道，避免双桥每帧求值）。
    /// 首帧宽度为 0 时走紧凑默认（两列），几何下发后再升档
    @State private var homeGeometry = HomeGeometry(width: 0, foldDivisionActive: false)

    /// 实测内容宽度
    private var contentWidth: CGFloat { homeGeometry.width }

    /// 宽版式（iPad 全屏/宽窗口）：页边距 32、大标题在侧栏
    private var isRegular: Bool { HomeGrid.isRegular(width: contentWidth) }

    private var skillColumnCount: Int {
        HomeGrid.skillColumnCount(width: homeGeometry.width, foldDivisionActive: homeGeometry.foldDivisionActive)
    }

    /// 宽网格（三列及以上）：卡片改用紧凑字号与更方的样图盒
    private var isWideGrid: Bool { skillColumnCount >= 3 }

    private var skillColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: isWideGrid ? 16 : 12),
            count: skillColumnCount
        )
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 宽版式下大标题在侧栏页眉（设计稿 10 内容区直接是官方模版）
                if !isRegular { header }
                officialSection
                mySection
                directRow
            }
            .padding(.horizontal, isRegular ? 32 : 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .onGeometryChange(for: HomeGeometry.self) { proxy in
            HomeGeometry(
                width: proxy.size.width,
                foldDivisionActive: PlatformCapability.foldDivisionActive(in: proxy)
            )
        } action: { homeGeometry = $0 }
        .fullScreenCover(item: $previewSkill) { skill in
            SamplePreviewCover(skill: skill)
        }
        .task { await load() }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("变奏")
                .font(Theme.Fonts.pageTitle)
                .foregroundStyle(Theme.textPrimary)
            Text("Theme & Variations")
                .font(Theme.Fonts.serifItalic(15))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - 官方模版

    private var officialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("官方模版")
                .font(Theme.Fonts.sectionTitle)
                .foregroundStyle(Theme.textPrimary)

            if let loadError {
                VStack(spacing: 12) {
                    Text(loadError)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .cardBackground()
                    Button("重试") { Task { await load() } }
                        .foregroundStyle(Theme.primary)
                }
            } else if skills.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: skillColumns, spacing: isWideGrid ? 16 : 12) {
                    ForEach(skills) { skill in
                        NavigationLink(value: Route.officialFlow(skill)) {
                            skillCard(skill)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// 模版卡：样图满出血 + 文字区（设计稿卡片结构）；整卡点按走外层 NavigationLink
    /// 进入变奏流程（主），样图右下角小图标是放大预览的次级入口
    private func skillCard(_ skill: SkillCard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SampleThumbnail(
                url: skill.sampleImageUrl.flatMap(URL.init(string:)),
                aspect: isWideGrid ? 120.0 / 96.0 : 170.0 / 108.0
            )
            .overlay(alignment: .bottomTrailing) { previewButton(for: skill) }

            VStack(alignment: .leading, spacing: 3) {
                Text(skill.displayName.isEmpty ? skill.name : skill.displayName)
                    .font(.system(size: isWideGrid ? 15 : 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text(skill.shortDescription)
                    .font(.system(size: isWideGrid ? 12 : 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(isWideGrid ? 10 : 12)
        }
        .cardBackground()
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        // 行内顶部对齐：同行卡片高度差时，空位留在卡外
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// 放大预览次级入口：样图右下角半透明小图标，不占主点按区（主点按 = 进入变奏流程）
    private func previewButton(for skill: SkillCard) -> some View {
        Button {
            previewSkill = skill
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.black.opacity(0.45), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("放大查看样图")
        .padding(8)
    }

    // MARK: - 我的模版

    private var mySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的模版")
                .font(Theme.Fonts.sectionTitle)
                .foregroundStyle(Theme.textPrimary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(myTemplates) { template in
                    NavigationLink(value: Route.userFlow(template)) {
                        templateRow(icon: "square.3.layers.3d", title: template.name)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            router.push(.editSkill(template))
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            modelContext.delete(template)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
                NavigationLink(value: Route.newSkill) {
                    templateRow(icon: "plus", title: "新建模版")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func templateRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .cardBackground()
    }

    // MARK: - 直接输入

    private var directRow: some View {
        NavigationLink(value: Route.direct) {
            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                Text("直接输入提示词")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .cardBackground()
        }
        .buttonStyle(.plain)
    }

    // MARK: - 数据

    private func load() async {
        do {
            loadError = nil
            skills = try await services.api.skills()
        } catch {
            loadError = error.localizedDescription
        }
    }
}

/// 官方模版样图：设计稿固定比例盒（行列齐整），图片完整显示不裁切（fit 居中，
/// 盒比例与图不一致时两侧/上下留卡片底色）；盒尺寸首帧即定，异步加载不跳行高
private struct SampleThumbnail: View {
    let url: URL?
    /// 固定盒宽高比（宽/高）：iPhone/iPad竖屏 170:108，iPad横屏 120:96
    var aspect: CGFloat

    var body: some View {
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .overlay {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().scaledToFit()
                    } else {
                        ImagePlaceholder(label: " ")
                    }
                }
            }
    }
}

/// 样图全屏预览：黑底 + 双指捏合缩放（ScrollView 承载平移）、双击复位；
/// 图按 sampleImageAspect 开基础尺寸（未知按 1:1），缩放范围 1–5 倍
private struct SamplePreviewCover: View {
    let skill: SkillCard
    @Environment(\.dismiss) private var dismiss

    /// 已确认的缩放倍数
    @State private var zoom: CGFloat = 1
    /// 捏合进行中的相对倍数
    @GestureState private var pinch: CGFloat = 1

    private var aspect: CGFloat {
        let value = skill.sampleImageAspect ?? 1
        return value > 0 ? CGFloat(value) : 1
    }

    private var effectiveZoom: CGFloat {
        min(max(zoom * pinch, 1), 5)
    }

    var body: some View {
        GeometryReader { geo in
            let fitScale = min(geo.size.width, geo.size.height * aspect)
            let baseWidth = fitScale
            let baseHeight = fitScale / aspect
            let contentWidth = baseWidth * effectiveZoom
            let contentHeight = baseHeight * effectiveZoom

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                LazyImage(url: skill.sampleImageUrl.flatMap(URL.init(string:))) { state in
                    if let image = state.image {
                        image.resizable().scaledToFit()
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .frame(width: contentWidth, height: contentHeight)
                // 小于屏幕时居中，大于屏幕时留给 ScrollView 平移
                .frame(minWidth: geo.size.width, minHeight: geo.size.height)
            }
            .gesture(doubleTapToReset)
            .simultaneousGesture(pinchToZoom)
        }
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { closeButton }
        .overlay(alignment: .bottom) { caption }
    }

    /// 双击复位到 1 倍
    private var doubleTapToReset: some Gesture {
        TapGesture(count: 2).onEnded {
            withAnimation(.spring(duration: 0.3)) { zoom = 1 }
        }
    }

    /// 双指捏合：进行中实时更新，抬手时落到 [1, 5] 区间
    private var pinchToZoom: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                zoom = min(max(zoom * value.magnification, 1), 5)
            }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.4), in: Circle())
        }
        .accessibilityLabel("关闭预览")
        .padding(.trailing, 20)
        .padding(.top, 12)
    }

    private var caption: some View {
        Text(skill.displayName.isEmpty ? skill.name : skill.displayName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(.black.opacity(0.4), in: Capsule())
            .padding(.bottom, 24)
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environment(AppServices())
        .environment(Router())
}
