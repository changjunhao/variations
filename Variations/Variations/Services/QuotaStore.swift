//
//  QuotaStore.swift
//  Variations
//
//  配额状态（次数口径三态）：游客终身体验 / 新用户 7 日特权 / 已购余额。
//  与服务端扣减同序：特权每日额度优先，已购余额兜底。
//

import Foundation
import Observation

@Observable
final class QuotaStore {
    private(set) var quota: Quota?

    /// 拉取服务端配额（失败保留旧值，静默）
    func refresh(api: APIClient) async {
        if let fresh = try? await api.quota() {
            quota = fresh
        }
    }

    /// 以服务端摘要覆盖（登录/落账响应直接带回）
    func apply(_ quota: Quota) {
        self.quota = quota
    }

    /// 是否已耗尽：游客→体验 0；用户→特权不可用且已购 0
    var exhausted: Bool {
        guard let quota else { return false }
        switch quota.tier {
        case "guest":
            return (quota.trial?.remaining ?? 0) <= 0
        case "user":
            let privilegeAvailable = (quota.privilege?.active == true) && (quota.privilege?.remainingToday ?? 0) > 0
            return !privilegeAvailable && (quota.paid?.remaining ?? 0) <= 0
        default:
            return false
        }
    }

    /// 生图成功后本地递减（与服务端同序；下次进入以服务端刷新为准）
    func consume() {
        guard let quota else { return }
        switch quota.tier {
        case "guest":
            guard let trial = quota.trial else { return }
            self.quota = Quota(
                tier: quota.tier, source: nil,
                trial: .init(remaining: max(0, trial.remaining - 1), limit: trial.limit),
                privilege: nil, paid: nil, resetsAt: quota.resetsAt)
        case "user":
            if let priv = quota.privilege, priv.active, priv.remainingToday > 0 {
                self.quota = Quota(
                    tier: quota.tier, source: nil, trial: nil,
                    privilege: .init(active: priv.active, daysLeft: priv.daysLeft,
                                     remainingToday: priv.remainingToday - 1, limitToday: priv.limitToday),
                    paid: quota.paid, resetsAt: quota.resetsAt)
            } else if let paid = quota.paid {
                self.quota = Quota(
                    tier: quota.tier, source: nil, trial: nil,
                    privilege: quota.privilege,
                    paid: .init(remaining: max(0, paid.remaining - 1)), resetsAt: quota.resetsAt)
            }
        default:
            break
        }
    }

    /// 429 后本地置满（其余界面同步禁用）
    func markExhausted() {
        guard let quota else { return }
        switch quota.tier {
        case "guest":
            guard let trial = quota.trial else { return }
            self.quota = Quota(tier: quota.tier, source: quota.source,
                               trial: .init(remaining: 0, limit: trial.limit),
                               privilege: nil, paid: nil, resetsAt: quota.resetsAt)
        case "user":
            let priv = quota.privilege.map {
                Quota.Privilege(active: $0.active, daysLeft: $0.daysLeft, remainingToday: 0, limitToday: $0.limitToday)
            }
            self.quota = Quota(tier: quota.tier, source: quota.source, trial: nil,
                               privilege: priv, paid: .init(remaining: 0), resetsAt: quota.resetsAt)
        default:
            break
        }
    }

    /// 权益行主文案（设计稿 5.9 三态）
    var quotaLabel: String {
        guard let quota else { return "今日额度" }
        switch quota.tier {
        case "guest": return "体验额度"
        case "staff": return "创作者模式"
        case "user":
            if quota.privilege?.active == true { return "今日额度" }
            return "已购次数"
        default: return "今日额度"
        }
    }

    /// 权益行右侧文案
    var quotaValueText: String {
        guard let quota else { return "—" }
        switch quota.tier {
        case "guest":
            return "余 \(quota.trial?.remaining ?? 0) 次"
        case "staff":
            return "不限次数"
        case "user":
            if let priv = quota.privilege, priv.active {
                return "余 \(priv.remainingToday) / \(priv.limitToday) 次 · 特权剩 \(priv.daysLeft) 天"
            }
            return "\(quota.paid?.remaining ?? 0) 次"
        default:
            return "—"
        }
    }

    /// 权益行是否画谱线轨（仅特权态；永久余额不画进度条）
    var showsTrack: Bool {
        quota?.tier == "user" && quota?.privilege?.active == true
    }

    /// 是否显示「购买次数」入口（创作者模式不限次数，隐藏购买入口）
    var showsPurchaseEntry: Bool {
        quota?.tier != "staff"
    }

    /// 谱线填充比例（特权态剩余/上限）
    var trackFraction: Double {
        guard let priv = quota?.privilege, priv.limitToday > 0 else { return 0 }
        return Double(priv.remainingToday) / Double(priv.limitToday)
    }

    /// 耗尽提示文案（设计稿 5.11：按主体选 CTA）
    var exhaustedHint: String {
        guard let quota else { return "次数已用完" }
        switch quota.tier {
        case "guest":
            return "体验 1 次已用完，登录 Apple 享 7 日每日 10 次"
        case "user":
            if quota.privilege?.active == true {
                return "今日 10 次已用完，明天零点再来"
            }
            return "次数已用完，购买次数继续"
        default:
            return "次数已用完"
        }
    }
}
