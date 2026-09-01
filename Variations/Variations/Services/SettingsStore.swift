//
//  SettingsStore.swift
//  Variations
//
//  设置存储：服务器地址覆盖项（仅 dev 生效）/appearance 走 UserDefaults。
//

import Foundation
import Observation

/// 外观三态（设置页 07）
enum Appearance: String, CaseIterable, Sendable {
    case system = "跟随系统"
    case light = "浅色"
    case dark = "深色"
}

/// 服务器地址校验：纯逻辑无状态，nonisolated 供非 MainActor 上下文（AppConfiguration/测试）复用
nonisolated enum ServerURLValidator {
    /// 仅允许 https 任意主机；http 限回环 + 私有网段/.local（真机局域网联调）
    static func isValid(_ string: String) -> Bool {
        guard let url = URL(string: string), let scheme = url.scheme?.lowercased(), let host = url.host else {
            return false
        }
        if scheme == "https" { return true }
        guard scheme == "http" else { return false }
        return isLoopback(host) || isPrivateHost(host)
    }

    private static func isLoopback(_ host: String) -> Bool {
        host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    /// 10/8、172.16/12、192.168/16、169.254/16 与 Bonjour .local
    private static func isPrivateHost(_ host: String) -> Bool {
        if host.hasSuffix(".local") { return true }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else { return false }
        switch (parts[0], parts[1]) {
        case (10, _), (192, 168), (169, 254): return true
        case (172, let b): return (16...31).contains(b)
        default: return false
        }
    }
}

@Observable
final class SettingsStore {
    private let defaults: UserDefaults

    /// 服务器地址覆盖原文（仅 dev 构建可在设置页编辑；生效基地址由 AppConfiguration 解析）
    var serverURLString: String {
        didSet { defaults.set(serverURLString, forKey: Self.serverURLOverrideKey) }
    }

    /// 外观
    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 清理旧版手填地址 key（App 未上架，无需迁移）
        defaults.removeObject(forKey: "serverURL")
        self.serverURLString = defaults.string(forKey: Self.serverURLOverrideKey) ?? ""
        self.appearance = Appearance(rawValue: defaults.string(forKey: Self.appearanceKey) ?? "") ?? .system
    }

    // MARK: - Keys

    private static let serverURLOverrideKey = "serverURLOverride"
    private static let appearanceKey = "appearance"
}
