//
//  SceneBridge.swift
//  Variations
//
//  窗口级能力桥接（多窗口下需要「本窗口」的 UIWindowScene，SwiftUI 无对应环境值）。
//  目前仅一项：生成进行中为所在窗口挂上关窗二次确认（iOS 27+），避免误关丢结果。
//

import SwiftUI
import UIKit

extension View {

    /// 生成进行中禁止误关窗：iOS 27+ 给所在窗口置上关窗确认，视图离场自动清除。
    /// 旧系统无此能力（关窗即断开 scene），原样返回。
    @ViewBuilder
    func sceneClosureGuard(isActive: Bool, title: String, message: String) -> some View {
        if #available(iOS 27, *) {
            if isActive {
                background(SceneClosureConfirmationBridge(title: title, message: message))
            } else {
                self
            }
        } else {
            self
        }
    }
}

/// 空视图桥：挂载时把确认配置写到宿主 window 的 scene 上，拆除时清掉。
/// scene 存在 Coordinator 里——dismantle 时 view.window 已为 nil，取不到 scene。
@available(iOS 27, *)
private struct SceneClosureConfirmationBridge: UIViewRepresentable {
    let title: String
    let message: String

    final class Coordinator {
        weak var scene: UIWindowScene?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let coordinator = context.coordinator
        let (title, message) = (self.title, self.message)
        // window 要等首帧挂载后才有，异步取一次
        Task { @MainActor in
            guard let scene = uiView.window?.windowScene else { return }
            coordinator.scene = scene
            scene.closureConfirmation = UISceneClosureConfirmation(title: title, message: message, actions: [])
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.scene?.closureConfirmation = nil
    }
}
