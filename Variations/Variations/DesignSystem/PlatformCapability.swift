//
//  PlatformCapability.swift
//  Variations
//
//  系统能力门控收口。部署目标 18.0，故新外观一律降级可用：
//  - Liquid Glass 家族（.buttonStyle(.glass)/scrollEdgeEffectStyle/tabBarMinimizeBehavior）自 **iOS 26** 起；
//  - 弹层放置/工具栏最小化/资源节流自 **iOS 27** 起。
//  玻璃只上 chrome（TabBar/导航栏/工具栏/弹层/吸底条边缘），纸面卡片保持哑光（见 DESIGN.md 4.6）。
//  视图层调用此处的语义 modifier，不各自散写 #available。
//

import SwiftUI

enum PlatformCapability {

    /// Liquid Glass 可用（iOS 26 起）
    static var liquidGlass: Bool {
        if #available(iOS 26, *) { true } else { false }
    }

    /// iOS 27 精修可用（presentationPlacement / toolbarMinimizationBehavior / 资源节流）
    static var sceneRefinements: Bool {
        if #available(iOS 27, *) { true } else { false }
    }
}

// MARK: - chrome 层语义 modifier

extension View {

    /// 系统 TabBar：iOS 26+ 下滑时最小化为胶囊，让作品占满视野
    @ViewBuilder
    func chromeTabBarMinimize() -> some View {
        if #available(iOS 26, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// 弹层放置：iOS 27+ 在宽窗口下居中浮出，避免固定高度 sheet 贴底突兀
    @ViewBuilder
    func chromeCenteredPresentation() -> some View {
        if #available(iOS 27, *) {
            presentationPlacement(.center)
        } else {
            self
        }
    }

    /// 根视图挂一次：把 iOS 27 的 systemPrefersReducedResourceUsage 桥到自有环境键，
    /// 使下游视图无需 @available 就能读到（旧系统恒为 false）
    @ViewBuilder
    func bridgeReducedResourceUsage() -> some View {
        if #available(iOS 27, *) {
            modifier(ReducedResourceUsageBridge())
        } else {
            self
        }
    }
}

// MARK: - 资源节流意图（iOS 27 系统值的降级封装）

private struct ReducedResourceUsageKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// 系统请求降低资源占用（低电量/热压力等）。
    /// 生图类 App 应据此停掉持续动画与预取，iOS 27 以下恒为 false。
    var prefersReducedResourceUsage: Bool {
        get { self[ReducedResourceUsageKey.self] }
        set { self[ReducedResourceUsageKey.self] = newValue }
    }
}

@available(iOS 27, *)
private struct ReducedResourceUsageBridge: ViewModifier {
    @Environment(\.systemPrefersReducedResourceUsage) private var systemValue

    func body(content: Content) -> some View {
        content.environment(\.prefersReducedResourceUsage, systemValue)
    }
}
