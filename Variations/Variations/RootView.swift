//
//  RootView.swift
//  Variations
//
//  应用骨架：iPhone 自绘胶囊 TabBar（隐藏系统 bar）；iPad regular 走 NavigationSplitView。
//

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
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @State private var selection: AppTab = .home

    var body: some View {
        Group {
            if hSize == .regular {
                splitLayout
            } else {
                compactLayout
            }
        }
        .preferredColorScheme(colorScheme)
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

    private var splitLayout: some View {
            NavigationSplitView {
                List(AppTab.allCases, selection: Binding(get: { Optional(selection) }, set: { selection = $0 ?? .home })) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
                .scrollContentBackground(.hidden)
                .background(Theme.background)
                .navigationTitle("变奏")
            } detail: {
                TabStack {
                    detail(for: selection, tabSelection: nil)
                }
            }
    }

    private var compactLayout: some View {
            TabView(selection: $selection) {
                ForEach(AppTab.allCases) { tab in
                    TabStack {
                        detail(for: tab, tabSelection: $selection)
                    }
                    .toolbar(.hidden, for: .tabBar)
                    .tag(tab)
                }
            }
    }

    @ViewBuilder
    private func detail(for tab: AppTab, tabSelection: Binding<AppTab>?) -> some View {
        switch tab {
        case .home: HomeView(tabSelection: tabSelection)
        case .collection: CollectionView(tabSelection: tabSelection)
        case .profile: ProfileView(tabSelection: tabSelection)
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
                }
                .environment(router)
        }
        .environment(router)
    }
}

/// 设计稿胶囊 Tab Bar：容器圆角 36 + 选中红胶囊圆角 26
struct CapsuleTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.snappy) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(selection == tab ? Theme.onPrimary : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selection == tab {
                            Capsule().fill(Theme.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Theme.surface)
                .shadow(color: Theme.containerShadowColor, radius: Theme.containerShadowRadius, y: Theme.containerShadowY)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
    }
}

#Preview {
    RootView()
}
