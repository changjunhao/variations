//
//  ConsentStore.swift
//  Variations
//
//  首次启动隐私同意闸门（中国区合规）三态：未决定（弹同意页）/ 同意 / 不同意。
//  不同意不退出 App——保持可浏览，网络操作（含设备注册）就地提示需先同意。
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.state = ConsentState(rawValue: defaults.string(forKey: Self.consentKey) ?? "") ?? .undecided
    }

    var hasConsented: Bool { state == .consented }

    /// 已做出选择（同意或不同意）→ 进入主界面；未决定 → 同意页
    var decided: Bool { state != .undecided }

    func consent() { state = .consented }

    func decline() { state = .declined }

    private static let consentKey = "privacyConsentState"
}
