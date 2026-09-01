//
//  Store.swift
//  Variations
//
//  StoreKit 2 消耗型积分包：商品加载、购买、JWS 服务端落账、漏单补单。
//  仅服务端验签成功后 finish 票据；服务端不可达保留未 finish，启动时 Transaction.updates 补单。
//

import StoreKit
import Observation

@Observable
final class StoreModel {

    /// 商品 ID 与服务端 IAP_PRODUCT_MAP 同口径
    static let productIDs = [
        "cn.ifable.Variations.pack.small",
        "cn.ifable.Variations.pack.medium",
        "cn.ifable.Variations.pack.large",
    ]

    /// 行卡次数记号（衬线斜体，设计稿 5.12）
    static let packCounts: [String: String] = [
        "cn.ifable.Variations.pack.small": "10 次",
        "cn.ifable.Variations.pack.medium": "60 次",
        "cn.ifable.Variations.pack.large": "160 次",
    ]

    private(set) var products: [Product] = []
    private(set) var isLoadingProducts = false
    /// 购买进行中（收银台/落账），弹层行卡禁用防连点
    private(set) var isPurchasing = false
    /// 行内确认/失败文案（不上阻断式弹窗，设计稿 5.12）
    var notice: String?

    private let api: APIClient
    private let quotaStore: QuotaStore
    private var updatesTask: Task<Void, Never>?

    init(api: APIClient, quotaStore: QuotaStore) {
        self.api = api
        self.quotaStore = quotaStore
    }

    /// 启动补单监听 + 预加载商品
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                let jws = update.jwsRepresentation
                guard let tx = self?.verified(update) else { continue }
                await self?.confirm(tx, jws: jws)
            }
        }
        Task { await load() }
    }

    /// 解包 StoreKit 验签结果；未通过验真的票据不落账
    private func verified(_ result: VerificationResult<Transaction>) -> Transaction? {
        switch result {
        case .verified(let tx): return tx
        case .unverified: return nil
        }
    }

    func load() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let list = try await Product.products(for: Self.productIDs)
            products = list.sorted { $0.price < $1.price }
            if products.isEmpty {
                notice = "App Store 未返回商品（沙盒同步中或可用性未设置）"
            }
        } catch {
            notice = "商品加载失败：\(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        notice = "正在处理购买…"
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let jws = verification.jwsRepresentation
                guard let tx = verified(verification) else {
                    notice = "票据验真失败，请联系客服"
                    return
                }
                await confirm(tx, jws: jws)
            case .pending:
                notice = "购买待确认（如家庭询问），确认后将自动落账"
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            notice = "购买失败，请稍后重试"
        }
    }

    /// 落账：服务端 JWS 验签幂等；成功后 finish 并刷新配额
    private func confirm(_ transaction: Transaction, jws: String) async {
        do {
            let reply = try await api.confirmPurchase(jws: jws)
            await transaction.finish()
            await quotaStore.refresh(api: api)
            notice = reply.applied
                ? "购买成功，余 \(reply.remaining) 次"
                : "该票据已落账，余 \(reply.remaining) 次"
        } catch {
            // 服务端不可达：不 finish，启动补单重试
            notice = "网络异常，恢复后将自动落账"
        }
    }
}
