//
//  Theme.swift
//  Variations
//
//  设计令牌：对照 ardot 设计稿《变奏 Variations · iOS 界面设计》(file 715376669934949)。
//  浅色 = 日谱；深色 = 夜谱（标准 dark appearance）。
//

import SwiftUI
import UIKit

/// 语义化设计令牌（视图层禁止硬编码颜色，一律走此处）
enum Theme {

    // MARK: - 颜色

    /// 页面底
    static let background = Color.vDynamic(light: 0xFAF8F3, dark: 0x191613)
    /// Tab 容器/白卡
    static let surface = Color.vDynamic(light: 0xFDFCF9, dark: 0x2E2A24)
    /// 米色卡片（模版卡/输入容器）
    static let card = Color.vDynamic(light: 0xF4F1E9, dark: 0x221F1A)
    /// 朱红主色（主按钮/选中胶囊）
    static let primary = Color.vDynamic(light: 0xBE3E2B, dark: 0xD95740)
    /// 主色上的文字
    static let onPrimary = Color(hex24: 0xFDFCF9)
    /// 浅标记底（编号徽记/身份徽记，vermilion-100）
    static let markSurface = Color.vDynamic(light: 0xF6E3DD, dark: 0x2E2A24)
    /// 一级文字
    static let textPrimary = Color.vDynamic(light: 0x1E1B17, dark: 0xFAF8F3)
    /// 二级文字
    static let textSecondary = Color.vDynamic(light: 0x6B655A, dark: 0xA9A294)
    /// 五线谱谱线（谱写变奏页，设计稿 04）
    static let staffLine = Color.vDynamic(light: 0xDDD6C6, dark: 0x2E2A24)
    /// 未谱写音符（与 textSecondary 深浅交叉：日谱用夜谱灰，夜谱用日谱灰）
    static let notePending = Color.vDynamic(light: 0xA9A294, dark: 0x6B655A)

    // MARK: - 圆角

    enum Radius {
        /// Tab 容器
        static let container: CGFloat = 36
        /// 选中胶囊/主按钮
        static let capsule: CGFloat = 26
        /// 卡片
        static let card: CGFloat = 12
    }

    // MARK: - 阴影

    /// Tab 容器投影 rgba(31,28,23,0.08) y2 blur8
    static let containerShadowColor = Color(hex24: 0x1F1C17).opacity(0.08)
    static let containerShadowRadius: CGFloat = 8
    static let containerShadowY: CGFloat = 2

    // MARK: - 字体

    enum Fonts {
        /// 英文衬线斜体（Theme & Variations / Variation No.X）
        static func serifItalic(_ size: CGFloat) -> Font {
            Font.system(size: size, design: .serif).italic()
        }

        /// 页面大标题（变奏/变奏集/设置）
        static let pageTitle = Font.system(size: 32, weight: .bold)
        /// 区块标题（官方模版/我的模版）
        static let sectionTitle = Font.system(size: 20, weight: .bold)
    }
}

// MARK: - 动态色工具

extension Color {
    /// 仅浅色值（双主题同值时使用）
    init(hex24: UInt32) {
        self.init(uiColor: UIColor(hex24: hex24))
    }

    /// 浅/深动态色，跟随系统外观
    static func vDynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex24: dark)
                : UIColor(hex24: light)
        })
    }
}

extension UIColor {
    convenience init(hex24: UInt32) {
        self.init(
            red: CGFloat((hex24 >> 16) & 0xFF) / 255,
            green: CGFloat((hex24 >> 8) & 0xFF) / 255,
            blue: CGFloat(hex24 & 0xFF) / 255,
            alpha: 1
        )
    }
}

#Preview("令牌色板") {
    VStack(spacing: 12) {
        ForEach(0..<6, id: \.self) { i in
            let pair: (String, Color) = [
                ("background", Theme.background),
                ("surface", Theme.surface),
                ("card", Theme.card),
                ("primary", Theme.primary),
                ("textPrimary", Theme.textPrimary),
                ("textSecondary", Theme.textSecondary),
            ][i]
            HStack {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(pair.1)
                    .frame(height: 44)
                Text(pair.0).foregroundStyle(Theme.textSecondary)
            }
        }
        Text("Variation No.3")
            .font(Theme.Fonts.serifItalic(24))
            .foregroundStyle(Theme.textPrimary)
    }
    .padding()
    .background(Theme.background)
}
