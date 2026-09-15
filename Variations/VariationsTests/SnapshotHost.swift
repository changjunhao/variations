//
//  SnapshotHost.swift
//  VariationsTests
//
//  快照渲染宿主：把 SwiftUI 视图挂进真实 UIWindow 后截图。
//
//  为什么必须挂 window：UIHostingController 不在 window 层级里时 SwiftUI 不会构建内容，
//  `view.layer.render(in:)` 拍出来是纯色空白（本仓早期基线即如此——HomeView 与
//  ComposingStageView 两张基线字节完全相同，等于测试恒真）。
//  另外 layer.render 不合成视觉效果层，iOS 26 起的玻璃材质也拍不出来，
//  故统一用 drawHierarchy(in:afterScreenUpdates: true)。
//

import SwiftUI
import UIKit
@testable import Variations

@MainActor
enum SnapshotHost {

    /// 渲染缩放：与设计稿 @2x 对齐，避免不同机型 scale 造成基线漂移
    private static let scale: CGFloat = 2

    /// 布局沉降窗口：等 .task 的异步加载与 onGeometryChange 回灌的宽度都落定
    private static let settleSeconds: TimeInterval = 0.6

    /// 纸色底（日谱 paper-100 / 夜谱）：视图自带 Theme.background，此处只作兜底
    private static let paperBackground = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex24: 0x191613) : UIColor(hex24: 0xFAF8F3)
    }

    static func image(of view: some View, size: CGSize, dark: Bool) -> UIImage {
        let host = UIHostingController(rootView: view)
        host.overrideUserInterfaceStyle = dark ? .dark : .light

        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.backgroundColor = Self.paperBackground
        window.rootViewController = host
        window.makeKeyAndVisible()

        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        // 跑一段 runloop：让 .task 拉取落定、onGeometryChange 把宽度回灌 @State，
        // 再补一轮布局，宽度分档（列数/页边距）才会按最终宽度生效
        RunLoop.current.run(until: Date().addingTimeInterval(settleSeconds))
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let bounds = CGRect(origin: .zero, size: size)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            host.view.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }

        window.isHidden = true
        window.rootViewController = nil
        return image
    }
}
