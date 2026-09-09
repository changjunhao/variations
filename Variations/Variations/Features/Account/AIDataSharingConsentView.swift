//
//  AIDataSharingConsentView.swift
//  Variations
//
//  第三方 AI 数据共享授权（App Store Guideline 5.1.1(i) / 5.1.2(i)）：
//  照片与提示词离开设备前必须在应用内明示「发送什么 / 发送给谁 / 用途与期限」并取得单独授权，
//  仅写在《隐私政策》里不满足要求。同一披露内容复用于首启同意页摘要与「我的」页查看/撤回。
//

import SwiftUI

/// 披露文案单一来源：同意页摘要、授权弹窗、「我的」页查看共用，避免多处文案漂移
enum AIDataSharingDisclosure {

    static let privacyURL = URL(string: "https://variations.ifable.cn/privacy")!
    static let termsURL = URL(string: "https://variations.ifable.cn/terms")!

    /// 首启同意页摘要（一句话点明第三方 AI 与数据流向）
    static let summary = "生成变奏时，你选择的照片与提示词会发送给第三方 AI 服务（阿里云百炼 Alibaba Cloud Model Studio、火山方舟 Volcengine Ark）处理，照片临时存放于阿里云对象存储（OSS）并在 48 小时后自动删除。"

    struct Section: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let items: [String]
    }

    static let sections: [Section] = [
        Section(title: "发送什么", icon: "photo.on.rectangle", items: [
            "你为本次变奏选择的照片（压缩副本，长边不超过 2048 像素）",
            "你填写的附加指令，以及编译生成或你编辑后的提示词",
            "不发送你的姓名、邮箱、位置、通讯录，也不读取相册中的其他照片",
        ]),
        Section(title: "发送给谁", icon: "building.2", items: [
            "阿里云百炼 Alibaba Cloud Model Studio（阿里云计算有限公司）：解析照片并生成变奏图",
            "火山方舟 Volcengine Ark（北京火山引擎科技有限公司）：同上，部分模版由其承接",
            "阿里云对象存储 OSS（阿里云计算有限公司）：临时存放照片，供上述 AI 服务读取",
        ]),
        Section(title: "用途与期限", icon: "clock.arrow.circlepath", items: [
            "仅用于完成你本次发起的变奏生成，不用于广告，不出售给任何第三方",
            "照片在 48 小时后自动删除；服务端不保存照片内容，仅保留不超过 30 天的请求日志",
            "上述接收方均在中华人民共和国境内提供服务，并按与我们签订的服务条款与数据处理协议，仅按我们的指示处理数据、提供不低于本应用《隐私政策》的保护水平",
        ]),
        Section(title: "你的选择", icon: "hand.raised", items: [
            "不授权也可继续浏览应用与本机已保存的变奏图，仅无法生成新变奏",
            "授权后可随时在「我的 → 第三方 AI 数据共享」中撤回；撤回不影响此前已完成的处理",
        ]),
    ]
}

/// 授权弹窗：首次发送照片/提示词前请求授权；已授权时同一入口用于查看与撤回
struct AIDataSharingConsentSheet: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// 取得授权后继续原动作（选图、开始变奏）；查看态为 nil
    var onGranted: (() -> Void)?

    private var granted: Bool { services.consent.hasAISharingConsent }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("你的照片与提示词将发送给第三方 AI 服务处理。发送前请阅读以下说明。")
                        .font(.system(size: 15))
                        .lineSpacing(6)
                        .foregroundStyle(Theme.textSecondary)

                    ForEach(AIDataSharingDisclosure.sections) { section in
                        sectionCard(section)
                    }

                    Button {
                        openURL(AIDataSharingDisclosure.privacyURL)
                    } label: {
                        Text("查看完整《隐私政策》")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("第三方 AI 数据共享")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { footer }
        }
        .presentationDetents([.large])
    }

    // MARK: - 分节卡

    private func sectionCard(_ section: AIDataSharingDisclosure.Section) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(section.title, systemImage: section.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("·").foregroundStyle(Theme.primary)
                        Text(item)
                            .font(.system(size: 14))
                            .lineSpacing(5)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.card))
    }

    // MARK: - 底部行动（未授权：同意/暂不；已授权：撤回/关闭）

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 12) {
            if granted {
                Button {
                    services.consent.revokeAISharing()
                    dismiss()
                } label: {
                    actionLabel("撤回授权", filled: false)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("aiSharingRevoke")
                Button { dismiss() } label: {
                    Text("关闭")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    services.consent.grantAISharing()
                    dismiss()
                    onGranted?()
                } label: {
                    actionLabel("同意并继续", filled: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("aiSharingAgree")
                Button { dismiss() } label: {
                    Text("暂不发送")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(Theme.background)
    }

    private func actionLabel(_ title: String, filled: Bool) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(filled ? Theme.onPrimary : Theme.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(filled ? Theme.primary : Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(filled ? Color.clear : Theme.primary.opacity(0.4))
                    )
            )
    }
}
