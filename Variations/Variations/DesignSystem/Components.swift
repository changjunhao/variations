//
//  Components.swift
//  Variations
//
//  设计系统通用组件：主/次按钮、卡片容器、占位图。
//

import SwiftUI

/// 主按钮：朱红胶囊（圆角 26），设计稿底部 CTA
struct PrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(enabled ? Theme.primary : Theme.primary.opacity(0.4)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// 次按钮：米色卡片+描边（存为提示词模版 / 载入提示词模版）
struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.textSecondary.opacity(0.25)))
            )
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// 米色卡片容器（圆角 12）
    func cardBackground() -> some View {
        background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.card))
    }
}

/// 设计稿 Image Placeholder 灰占位；icon 非空时图标+文案纵向居中（选图引导空态）
struct ImagePlaceholder: View {
    /// 占位文案（空白传 " "）；界面文案须为中文
    var label: String
    var icon: String? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.card)
            .fill(Color.vDynamic(light: 0xE2E3E7, dark: 0x26282D))
            .overlay(
                VStack(spacing: 10) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 30))
                    }
                    Text(label)
                        .font(.system(size: 15))
                }
                .foregroundStyle(.gray)
            )
    }
}
