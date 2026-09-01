//
//  DeviceAuth.swift
//  Variations
//
//  设备身份令牌：首次启动自助注册（POST /api/auth/device）换取长期 token，存 Keychain；
//  业务请求携带 Authorization: Bearer；401 时强制重注册一次（自愈，防循环）。
//  注册受服务端 App Secret 软门槛保护（proof = HMAC-SHA256(secret, deviceId)）。
//

import CryptoKit
import Foundation
// KeychainAccess 未做 Sendable 标注；Keychain 仅经其内部串行队列访问，@preconcurrency 抑制告警
@preconcurrency import KeychainAccess

/// 设备凭据存储抽象：真机用 Keychain（service 按环境命名空间隔离），单测注入内存版
/// nonisolated：工程默认 MainActor 隔离下，DeviceAuth actor 内需同步调用
nonisolated protocol DeviceCredentialStoring: Sendable {
    func read(_ key: String) throws -> String?
    func write(_ value: String?, key: String) throws
}

/// Keychain 实现：service 带环境后缀（与 skills 缓存同口径），防 dev/prod 同设备串台
nonisolated struct KeychainCredentialStore: DeviceCredentialStoring {
    private let keychain: Keychain

    init(environment: String) {
        keychain = Keychain(service: "cn.ifable.Variations.device.\(environment)")
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
nonisolated final class InMemoryCredentialStore: DeviceCredentialStoring, @unchecked Sendable {
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

/// 设备身份令牌管理（actor）：token 明文只经 HTTPS 下发一次，本地存 Keychain
actor DeviceAuth {

    static let deviceIDKey = "deviceId"
    static let tokenKey = "deviceToken"

    private let store: any DeviceCredentialStoring
    private let session: URLSession
    private var cachedToken: String?

    init(store: any DeviceCredentialStoring, session: URLSession = .shared) {
        self.store = store
        self.session = session
    }

    /// 取当前有效 token：缓存/Keychain 无则先注册（baseURL 由调用方按当前生效地址传入）
    func token(baseURL: URL) async throws -> String {
        if let cachedToken { return cachedToken }
        if let stored = try? store.read(Self.tokenKey), !stored.isEmpty {
            cachedToken = stored
            return stored
        }
        let fresh = try await register(baseURL: baseURL)
        cachedToken = fresh
        return fresh
    }

    /// 401 自愈：作废当前 token 并强制重注册（服务端幂等：同 deviceId 吊销旧 token 签发新 token）
    func reRegister(baseURL: URL) async throws {
        cachedToken = nil
        try? store.write(nil, key: Self.tokenKey)
        let fresh = try await register(baseURL: baseURL)
        cachedToken = fresh
    }

    /// 当前 deviceId（Apple 登录请求随带；nil = 尚未注册）
    func currentDeviceID() -> String? {
        (try? store.read(Self.deviceIDKey)) ?? nil
    }

    // MARK: - 内部

    private struct RegisterReply: Decodable {
        let token: String
        let deviceId: String
    }

    private func register(baseURL: URL) async throws -> String {
        let deviceID = try ensureDeviceID()
        var request = URLRequest(url: baseURL.appendingPathComponent("api/auth/device"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let payload = ["deviceId": deviceID, "proof": try proof(for: deviceID)]
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw AppError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw AppError.decoding }
        guard (200..<300).contains(http.statusCode) else {
            let body = try? JSONDecoder().decode(APIErrorBody.self, from: data)
            throw AppError(status: http.statusCode, body: body)
        }
        guard let reply = try? JSONDecoder().decode(RegisterReply.self, from: data) else {
            throw AppError.decoding
        }
        try? store.write(reply.token, key: Self.tokenKey)
        return reply.token
    }

    private func ensureDeviceID() throws -> String {
        if let existing = try store.read(Self.deviceIDKey), !existing.isEmpty {
            return existing
        }
        // 自生成 UUID（不用 identifierForVendor）：重装 App 视为新设备，语义明确
        let fresh = UUID().uuidString.lowercased()
        try store.write(fresh, key: Self.deviceIDKey)
        return fresh
    }

    /// proof = HMAC-SHA256(secret, deviceId) 十六进制（与服务端 RegisterGate 契约一致）
    /// secret 缺失（Secrets.xcconfig 未配置）时注册直接失败，不发无效请求
    private func proof(for deviceID: String) throws -> String {
        guard let secret = Self.registerSecret else { throw AppError.notConfigured }
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(deviceID.utf8), using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - App Secret 软门槛
    //
    // secret 构建期注入：Configurations/Secrets.xcconfig（gitignore 不入库）
    // → Info.plist $(REGISTER_SECRET) → 运行时读取；源码仓库不含明文值。
    // 明确：这是「门槛」不是「安全边界」——iOS 二进制可被脱壳逆向提取密钥，认真攻击者仍可注册；
    // 纵深防御依赖服务端限频/吊销/审计（见服务端 auth/gate.go 注释）。
    // 轮换：新值写入 Secrets.xcconfig 并发版，服务端 REGISTER_SECRET 同步（需新旧双 secret 过渡窗口）。
    private static var registerSecret: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "RegisterSecret") as? String,
              !value.isEmpty else { return nil }
        return value
    }
}
