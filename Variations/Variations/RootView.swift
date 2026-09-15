//
//  RootView.swift
//  Variations
//
//  应用骨架：单一 TabView + sidebarAdaptable —— compact 走系统底部 TabBar，
//  regular 自动升为侧栏，窗口拖拽 resize 时由系统在同一棵树内切换形态。
//

import AuthenticationServices
import SwiftUI
import SwiftData

enum AppTab: String, CaseIterable, Identifiable {
    case home = "首页"
    case collection = "变奏集"
    case profile = "我的"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: "house"
        case .collection: "square.3.layers.3d"
        case .profile: "person.crop.circle"
        }
    }
}

struct RootView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @State private var selection: AppTab = .home

    var body: some View {
        tabs
            .preferredColorScheme(colorScheme)
            // Apple 授权可被用户在系统设置里停用：启动补查一次（覆盖离线期间的停用），
            // 运行中则由系统通知触发，两路均降级为游客
            .task { await services.syncAppleCredentialState() }
            .onReceive(NotificationCenter.default.publisher(
                for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { _ in
                Task { await services.handleAppleCredentialRevoked() }
            }
            #if DEBUG
            .task { MarketingSeed.seedRecordsIfNeeded(context: modelContext) }
            #endif
    }

    private var colorScheme: ColorScheme? {
        switch services.settings.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// 不按 horizontalSizeClass 手切两套布局：窗口化下拖拽 resize 会跨越 size class
    /// 阈值，整棵树被替换会连带重建 TabStack，各 Tab 的导航栈随之清空。
    /// sidebarAdaptable 由系统在同一棵树内做 TabBar ↔ 侧栏切换，状态不丢。
    private var tabs: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.rawValue, systemImage: tab.icon, value: tab) {
                    TabStack {
                        detail(for: tab)
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .chromeTabBarMinimize()
        .tabViewSidebarHeader { sidebarWordmark }
    }

    /// 侧栏页眉：承接原 NavigationSplitView 侧栏的「变奏」标题
    private var sidebarWordmark: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("变奏")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Theme & Variations")
                .font(Theme.Fonts.serifItalic(13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func detail(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .collection: CollectionView()
        case .profile: ProfileView()
        }
    }
}

/// 每个 Tab 独立的 NavigationStack + Router。
/// router 由 @State 直接持有并显式注入 content 与每个 destination：
/// 仅靠 NavigationStack 外层的 .environment 传播在 TabView/NavigationSplitView
/// 嵌套下可能到不了被 push 的目标页，导致 @Environment(Router.self) 访问时崩溃。
struct TabStack<Content: View>: View {
    @State private var router = Router()
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack(path: Binding(get: { router.path }, set: { router.path = $0 })) {
            content
                .navigationDestination(for: Route.self) { route in
                    RouteView(route: route)
                        .environment(router)
                        // 次级（push 进入）页隐藏底部 Tab 栏：只在三个根页展示，
                        // 流程/结果等详情页不再被系统 Tab 栏（含最小化胶囊）干扰
                        .toolbar(.hidden, for: .tabBar)
                }
                .environment(router)
        }
        .environment(router)
    }
}

#Preview {
    RootView()
}
