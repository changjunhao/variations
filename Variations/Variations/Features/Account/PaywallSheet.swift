//
//  PaywallSheet.swift
//  Variations
//
//  购买次数弹层（设计稿 5.12）：medium detent + 三档 pack 行卡 + 行内确认文案。
//

import SwiftUI
import StoreKit

struct PaywallSheet: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Theme.staffLine)
                .frame(width: 36, height: 4)

            Text("购买次数")
                .font(Theme.Fonts.sectionTitle)
                .foregroundStyle(Theme.textPrimary)
            Text("永久有效 · 不退换")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)

            if services.store.isLoadingProducts {
                ProgressView()
                    .padding(.vertical, 24)
            } else if services.store.products.isEmpty {
                // 空列表诊断：协议未生效/沙盒传播延迟/账户区域不符
                VStack(spacing: 12) {
                    Text("商品暂未就绪")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("请确认付费 App 协议已生效，或稍候待沙盒同步后重试")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await services.store.load() }
                    } label: {
                        Text("重试")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 16)
            } else {
                ForEach(services.store.products, id: \.id) { product in
                    packRow(product)
                }
            }

            if let notice = services.store.notice {
                Text(notice)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 32)
        .presentationDetents([.medium])
        .presentationBackground(Theme.surface)
        .task { await services.store.load() }
    }

    /// pack 行卡：名称 + 衬线斜体次数记号 + 右端价格；整行按压 scale 0.97；
    /// 购买进行中全卡禁用防连点（收银台拉起有延迟，连点会重复购买）
    private func packRow(_ product: Product) -> some View {
        let busy = services.store.isPurchasing
        return Button {
            Task { await services.store.purchase(product) }
        } label: {
            HStack {
                HStack(spacing: 8) {
                    Text(product.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(StoreModel.packCounts[product.id] ?? "")
                        .font(Theme.Fonts.serifItalic(17))
                        .foregroundStyle(Theme.primary)
                }
                Spacer()
                if busy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(product.displayPrice)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.card))
            .opacity(busy ? 0.6 : 1)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(busy)
    }
}

/// 通用按压缩放（scale 0.97 / 150ms，设计稿第 7 节）
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
