//
//  ConsentGateView.swift
//  Variations
//
//  首次启动隐私同意页（设计稿 14 · ConsentGate）：同意前不发起任何网络请求。
//  不同意不退出 App——保持可浏览，网络操作就地提示。
//

import SwiftUI

struct ConsentGateView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.openURL) private var openURL

    /// 政策页地址（随备案/上架在 ifable.cn 部署）
    private static let termsURL = URL(string: "https://variations.ifable.cn/terms")!
    private static let privacyURL = URL(string: "https://variations.ifable.cn/privacy")!

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Text("Variations")
                    .font(Theme.Fonts.serifItalic(34))
                    .foregroundStyle(Theme.textPrimary)
                Text("变奏 Variations 是一款照片的艺术变奏应用。我们仅收集必要数据以提供服务，详见下方政策。")
                    .font(.system(size: 15))
                    .lineSpacing(9)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    link("《用户协议》", Self.termsURL)
                    Text("·").foregroundStyle(Theme.textSecondary)
                    link("《隐私政策》", Self.privacyURL)
                }
                .font(.system(size: 15))
            }
            .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    services.consent.consent()
                } label: {
                    Text("同意并继续")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.primary))
                }
                .buttonStyle(.plain)
                Button {
                    // 不同意：保持可浏览（网络操作被闸门拦截，就地提示）
                    services.consent.decline()
                } label: {
                    Text("不同意")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Theme.background)
    }

    private func link(_ title: String, _ url: URL) -> some View {
        Button { openURL(url) } label: {
            Text(title).foregroundStyle(Theme.primary)
        }
        .buttonStyle(.plain)
    }
}
