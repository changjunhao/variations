//
//  AppAppearance.swift
//  Variations
//
//  UIKit 外观收口：导航栏标题色跟随日谱/夜谱动态色。
//  iOS 26+ 导航栏背景是系统玻璃，**不可**再赋不透明背景（会整片盖掉玻璃），
//  故新系统只覆盖标题字色/字重；旧系统维持原纸色实心背景。
//  TabBar 不再定制：自绘胶囊 TabBar 已移除，交由系统绘制（玻璃/最小化由系统接管）。
//

import UIKit

enum AppAppearance {

    /// 墨色标题：日谱 ink-900，夜谱 paper-100（与 Theme.textPrimary 同口径）
    private static let titleColor = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex24: 0xFAF8F3) : UIColor(hex24: 0x1E1B17)
    }

    private static let titleFont = UIFont.systemFont(ofSize: 17, weight: .semibold)

    static func configure() {
        if #available(iOS 26, *) {
            // 取系统默认外观（已含玻璃背景）就地改标题，背景与阴影一概不碰
            let nav = UINavigationBar.appearance().standardAppearance
            nav.titleTextAttributes = [.foregroundColor: titleColor, .font: titleFont]
            UINavigationBar.appearance().standardAppearance = nav
            return
        }

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex24: 0x191613) : UIColor(hex24: 0xFAF8F3)
        }
        nav.titleTextAttributes = [.foregroundColor: titleColor, .font: titleFont]
        nav.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }
}
