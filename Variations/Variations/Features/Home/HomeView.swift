//
//  HomeView.swift
//  Variations
//
//  首页（设计稿 01）：大标题 + 官方模版双列卡 + 我的模版 + 直接输入入口。
//

import SwiftUI
import SwiftData
import NukeUI

struct HomeView: View {
    @Environment(AppServices.self) private var services
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSkillTemplate.createdAt) private var myTemplates: [UserSkillTemplate]
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    /// 非 nil 时（iPhone compact）底部显示胶囊 TabBar
    var tabSelection: Binding<AppTab>? = nil

    @State private var skills: [SkillCard] = []
    @State private var loadError: String?
    /// 非 nil 时全屏预览该模版样图（捏合缩放 / 双击复位）
    @State private var previewSkill: SkillCard?

    private var isRegular: Bool { hSize == .regular }

    /// 宽网格（iPad 横屏）：hSize/vSize 同为 regular 时 iPad 竖屏 hSize 也是 regular，
    /// 必须加 vSize == .compact 才能区分横屏；iPhone 与 iPad 竖屏走紧凑规范
    private var isWideGrid: Bool { hSize == .regular && vSize == .compact }

    /// 官方模版网格：iPad 横屏 4 列间距 16（设计稿 10）；iPhone / iPad 竖屏 2 列间距 12（设计稿 01）
    private var skillColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: isWideGrid ? 16 : 12),
            count: isWideGrid ? 4 : 2
        )
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // iPad 大标题在侧栏（设计稿 10 内容区直接是官方模版）
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
        .safeAreaInset(edge: .bottom) {
            if let tabSelection {
                CapsuleTabBar(selection: tabSelection)
            }
        }
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
