//
//  AccountAuth.swift
//  Variations
//
//  SIWA 账号会话存储：系统面板凭据经 APIClient 换发会话令牌（var_u_）后落 Keychain，
//  与 DeviceAuth 同构。401 时由 APIClient 清会话降级游客。
//

import CryptoKit
import Foundation
// KeychainAccess 未做 Sendable 标注；与 DeviceAuth 同口径，@preconcurrency 抑制告警
@preconcurrency import KeychainAccess

/// SIWA 防重放 nonce：request.nonce 放 SHA-256 摘要，raw 值随登录上传由服务端重算比对
/// （服务端同口径实现见 internal/auth/apple.go 的 NonceDigest）
nonisolated enum AppleNonce {
    /// 32 字节 crypto 随机 → base64url（无填充，避开 nonce 中的 +/=）
    static func makeRaw() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// SHA-256 十六进制摘要（置入 request.nonce）
    static func digest(_ raw: String) -> String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// 账号档案（服务端 user 摘要 + 本地记录的 Apple 用户标识）
nonisolated struct AccountSession: Codable, Sendable, Equatable {
    let name: String
    let email: String
    let isPrivateEmail: Bool
    /// Apple sub（credential.user）：用于冷启动时 getCredentialState 查授权是否被用户停用。
    /// 可选：服务端不返回此字段，且旧版本落库的会话无此键（解码为 nil，跳过检查）
    var appleUserID: String?
}

/// 账号凭据存储抽象：真机用 Keychain（service 按环境隔离），单测注入内存版
nonisolated protocol AccountCredentialStoring: Sendable {
    func read(_ key: String) throws -> String?
    func write(_ value: String?, key: String) throws
}

/// Keychain 实现：service 带环境后缀，防 dev/prod 同设备串台
nonisolated struct KeychainAccountStore: AccountCredentialStoring {
    private let keychain: Keychain

    init(environment: String) {
        keychain = Keychain(service: "cn.ifable.Variations.account.\(environment)")
    }

    func read(_ key: String) throws -> String? {
        try keychain.get(key)
    }

    func write(_ value: String?, key: String) throws {
        if let value, !value.isEmpty {
            try keychain.set(value, key: key)
        } else {
            try keychain.remove(key)
        }
    }
}

/// 单测用内存实现
nonisolated final class InMemoryAccountStore: AccountCredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func read(_ key: String) throws -> String? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }

    func write(_ value: String?, key: String) throws {
        lock.lock(); defer { lock.unlock() }
        values[key] = (value?.isEmpty == false) ? value : nil
    }
}

/// SIWA 账号会话管理（actor）：会话令牌明文只经 HTTPS 下发一次，本地存 Keychain
actor AccountAuth {

    static let tokenKey = "accountToken"
    static let sessionKey = "accountSession"

    private let store: any AccountCredentialStoring
    private var cachedToken: String?

    init(store: any AccountCredentialStoring) {
        self.store = store
    }

    /// 换发成功后落库：会话令牌 + 档案（内存缓存同步更新）
    func storeSession(token: String, session: AccountSession) {
        cachedToken = token
        try? store.write(token, key: Self.tokenKey)
        if let data = try? JSONEncoder().encode(session) {
            try? store.write(String(data: data, encoding: .utf8), key: Self.sessionKey)
        }
    }

    /// 当前会话令牌（缓存/Keychain；nil = 未登录）
    func currentToken() -> String? {
        if let cachedToken { return cachedToken }
        if let stored = try? store.read(Self.tokenKey), !stored.isEmpty {
            cachedToken = stored
            return stored
        }
        return nil
    }

    /// 当前账号档案（nil = 未登录）
    func currentSession() -> AccountSession? {
        guard let raw = try? store.read(Self.sessionKey),
              let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AccountSession.self, from: data)
    }

    /// 本地清除会话（401 降级游客 / 退出登录 / 注销账号后调用）
    func clearSession() {
        cachedToken = nil
        try? store.write(nil, key: Self.tokenKey)
        try? store.write(nil, key: Self.sessionKey)
    }
}
