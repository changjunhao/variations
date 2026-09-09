//
//  ConsentGateView.swift
//  Variations
//
//  首次启动隐私同意页（设计稿 14 · ConsentGate）：同意前不发起任何网络请求。
//  不同意不退出 App——保持可浏览，网络操作就地提示。
//
//  除基础政策同意外，本页同时给出「第三方 AI 数据共享」摘要披露
//  （App Store Guideline 5.1.1(i) / 5.1.2(i)）；照片/提示词发送到第三方 AI
//  的单独授权在首次发起变奏前再请求一次，授权页与本页共享同一份披露文案。
//

import SwiftUI

struct ConsentGateView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.openURL) private var openURL

    /// 政策页地址（随备案/上架在 ifable.cn 部署）
    private static let termsURL = URL(string: "https://variations.ifable.cn/terms")!
    private static let privacyURL = URL(string: "https://variations.ifable.cn/privacy")!

    /// 展开「第三方 AI 数据共享」摘要披露
    @State private var showAISharing = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Text("Variations")
                    .font(Theme.Fonts.serifItalic(34))
                    .foregroundStyle(Theme.textPrimary)
                Text("变奏 Variations 是一款照片的艺术变奏应用。我们仅收集必要数据以提供服务，详见下方政策。")
                    .font(.system(size: 15))
                    .lineSpacing(9)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)

                aiSummaryCard

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
        .sheet(isPresented: $showAISharing) {
            AIDataSharingConsentSheet()
        }
    }

    // MARK: - 第三方 AI 摘要卡

    private var aiSummaryCard: some View {
        Button { showAISharing = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                Label("第三方 AI 数据共享", systemImage: "brain.head.profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                Text(AIDataSharingDisclosure.summary)
                    .font(.system(size: 13))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 4) {
                    Text("查看完整说明")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .strokeBorder(Theme.primary.opacity(0.25))
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("aiSharingSummary")
    }

    private func link(_ title: String, _ url: URL) -> some View {
        Button { openURL(url) } label: {
            Text(title).foregroundStyle(Theme.primary)
        }
        .buttonStyle(.plain)
    }
}
