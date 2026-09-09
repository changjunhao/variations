//
//  ConsentStore.swift
//  Variations
//
//  首次启动隐私同意闸门（中国区合规）三态：未决定（弹同意页）/ 同意 / 不同意。
//  不同意不退出 App——保持可浏览，网络操作（含设备注册）就地提示需先同意。
//
//  另存「第三方 AI 数据共享」独立授权（App Store Guideline 5.1.1(i) / 5.1.2(i)）：
//  照片/提示词离开设备前必须单独取得授权，与基础政策同意分离，可随时撤回。
//

import Foundation
import Observation

enum ConsentState: String, Sendable {
    case undecided
    case consented
    case declined
}

@Observable
final class ConsentStore {
    private let defaults: UserDefaults

    private(set) var state: ConsentState {
        didSet { defaults.set(state.rawValue, forKey: Self.consentKey) }
    }

    /// 已授权的第三方 AI 共享披露版本（0 = 未授权/已撤回）；披露内容变更时提升 currentAISharingVersion 以重新征询
    private(set) var aiSharingVersion: Int {
        didSet { defaults.set(aiSharingVersion, forKey: Self.aiSharingVersionKey) }
    }

    /// 授权时间（合规追溯用；撤回后清空）
    private(set) var aiSharingGrantedAt: Date? {
        didSet { defaults.set(aiSharingGrantedAt?.timeIntervalSince1970 ?? 0, forKey: Self.aiSharingDateKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.state = ConsentState(rawValue: defaults.string(forKey: Self.consentKey) ?? "") ?? .undecided
        self.aiSharingVersion = defaults.integer(forKey: Self.aiSharingVersionKey)
        let stamp = defaults.double(forKey: Self.aiSharingDateKey)
        self.aiSharingGrantedAt = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    var hasConsented: Bool { state == .consented }

    /// 已做出选择（同意或不同意）→ 进入主界面；未决定 → 同意页
    var decided: Bool { state != .undecided }

    func consent() { state = .consented }

    func decline() { state = .declined }

    // MARK: - 第三方 AI 数据共享授权

    /// 当前披露版本：文案中「发送什么 / 发送给谁 / 用途与期限」有实质变更时 +1
    static let currentAISharingVersion = 1

    /// 已就当前披露版本取得授权——照片/提示词发送到第三方 AI 的前置条件
    var hasAISharingConsent: Bool {
        hasConsented && aiSharingVersion >= Self.currentAISharingVersion
    }

    func grantAISharing() {
        aiSharingVersion = Self.currentAISharingVersion
        aiSharingGrantedAt = Date()
    }

    func revokeAISharing() {
        aiSharingVersion = 0
        aiSharingGrantedAt = nil
    }

    private static let consentKey = "privacyConsentState"
    private static let aiSharingVersionKey = "aiSharingConsentVersion"
    private static let aiSharingDateKey = "aiSharingConsentGrantedAt"
}
