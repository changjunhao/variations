//
//  AppAppearance.swift
//  Variations
//
//  UIKit 外观收口：导航栏背景/标题色跟随日谱/夜谱动态色。
//

import UIKit

enum AppAppearance {

    static func configure() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex24: 0x191613) : UIColor(hex24: 0xFAF8F3)
        }
        nav.titleTextAttributes = [
            .foregroundColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? UIColor(hex24: 0xFAF8F3) : UIColor(hex24: 0x1E1B17)
            },
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        ]
        nav.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
