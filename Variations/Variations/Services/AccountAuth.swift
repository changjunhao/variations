//
//  AccountAuth.swift
//  Variations
//
//  SIWA 账号会话存储：系统面板凭据经 APIClient 换发会话令牌（var_u_）后落 Keychain，
//  与 DeviceAuth 同构。401 时由 APIClient 清会话降级游客。
//

import Foundation
// KeychainAccess 未做 Sendable 标注；与 DeviceAuth 同口径，@preconcurrency 抑制告警
@preconcurrency import KeychainAccess

/// 账号档案（服务端 user 摘要）
nonisolated struct AccountSession: Codable, Sendable, Equatable {
    let name: String
    let email: String
    let isPrivateEmail: Bool
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
