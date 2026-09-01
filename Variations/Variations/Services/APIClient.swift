//
//  APIClient.swift
//  Variations
//
//  轻后端客户端：设备身份令牌（Bearer）鉴权 + 401 自愈重注册、skills ETag/304 磁盘缓存、错误中文化。
//  基地址由 AppConfiguration 构建期确定（dev 可被设置页覆盖），永不为空。
//

import Foundation

actor APIClient {

    /// 单请求超时（后端 requestTimeout=300s，客户端 180s + 可重试）
    static let requestTimeout: TimeInterval = 180

    private let settings: SettingsStore
    private let config: AppConfiguration
    private let deviceAuth: DeviceAuth
    private let accountAuth: AccountAuth?
    private let consent: ConsentStore?
    private let session: URLSession
    /// 缓存根目录注入（测试用临时目录，防 fixture 污染宿主 App 的真实缓存）；nil = 沙盒 Caches
    private let cacheRoot: URL?

    init(settings: SettingsStore, config: AppConfiguration, deviceAuth: DeviceAuth, accountAuth: AccountAuth? = nil, consent: ConsentStore? = nil, session: URLSession? = nil, cacheRoot: URL? = nil) {
        self.settings = settings
        self.config = config
        self.deviceAuth = deviceAuth
        self.accountAuth = accountAuth
        self.consent = consent
        self.cacheRoot = cacheRoot
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = Self.requestTimeout
            config.timeoutIntervalForResource = 300
            config.urlCache = nil
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - GET /api/skills（ETag/304 磁盘缓存）

    func skills() async throws -> [SkillCard] {
        try await assertConsent()
        let performOnce: () async throws -> (Data, HTTPURLResponse) = {
            var request = try await self.makeRequest(path: "/api/skills", method: "GET")
            if let etag = try? String(contentsOf: self.etagFileURL, encoding: .utf8), !etag.isEmpty {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            let (data, response) = try await self.send(request)
            guard let http = response as? HTTPURLResponse else { throw AppError.decoding }
            return (data, http)
        }
        var (data, http) = try await performOnce()
        // 401 自愈：会话失效先降级游客，再强制重注册一次并重试（仅一次，防循环）
        if http.statusCode == 401 {
            await accountAuth?.clearSession()
            try await deviceAuth.reRegister(baseURL: await currentBaseURL())
            (data, http) = try await performOnce()
        }
        if http.statusCode == 304, let cached = try? readCache() {
            return cached
        }
        try expectSuccess(http, data)
        let cards = try decode([SkillCard].self, from: data)
        try? data.write(to: skillsFileURL, options: .atomic)
        if let etag = http.value(forHTTPHeaderField: "ETag") {
            try? etag.write(to: etagFileURL, atomically: true, encoding: .utf8)
        }
        return cards
    }

    // MARK: - GET /api/upload-ticket

    /// hash 为最终上传字节的 SHA-256（小写 hex）：服务端据此生成内容寻址对象键 uploads/{hash}.{ext}。
    /// fileUrl 签名有效期 ≤2h（对象本身 48h 后由生命周期清理），超期后经 fileURL 重签，不依赖长效签名
    func uploadTicket(ext: String = "jpg", hash: String) async throws -> UploadTicket {
        let request = try await makeRequest(path: "/api/upload-ticket?ext=\(ext)&hash=\(hash)", method: "GET")
        let (data, http) = try await sendWithAuthRetry(request)
        try expectSuccess(http, data)
        return try decode(UploadTicket.self, from: data)
    }

    // MARK: - GET /api/file-url（再次变奏重签）

    /// 凭内容哈希重签新 GET 票据（签名 ≤2h）：对象还在 48h 生命周期内即可反复重签；
    /// 已被清理时服务端回 410 → AppError.sourceFileGone（调用方提示「不可变奏」，不得降级文生图）
    func fileURL(ext: String = "jpg", hash: String) async throws -> FileTicket {
        let request = try await makeRequest(path: "/api/file-url?ext=\(ext)&hash=\(hash)", method: "GET")
        let (data, http) = try await sendWithAuthRetry(request)
        try expectSuccess(http, data)
        return try decode(FileTicket.self, from: data)
    }

    /// 批量重签参考图：逐个解析 uploads/{hash}.{ext} 并重签新 GET 票据（原序返回）；
    /// 无法解析的 URL 原样保留；任一源图已被清理则抛 sourceFileGone
    func refreshReferences(_ urls: [String]) async throws -> [String] {
        var refreshed: [String] = []
        for url in urls {
            guard let ref = SourceRef.parse(url) else {
                refreshed.append(url)
                continue
            }
            refreshed.append(try await fileURL(ext: ref.ext, hash: ref.hash).fileUrl)
        }
        return refreshed
    }

    // MARK: - POST /api/compile

    /// skillId 与 inlineSkill 互斥（后端强校验）
    func compile(skillId: String? = nil, inlineSkill: InlineSkill? = nil, imageUrl: String, instruction: String = "") async throws -> String {
        struct Payload: Encodable {
            let skillId: String?
            let inlineSkill: InlineSkill?
            let imageUrl: String
            let instruction: String?
        }
        let payload = Payload(
            skillId: skillId,
            inlineSkill: inlineSkill,
            imageUrl: imageUrl,
            instruction: instruction.isEmpty ? nil : instruction
        )
        let request = try await makeRequest(path: "/api/compile", method: "POST", json: payload)
        let (data, http) = try await sendWithAuthRetry(request)
        try expectSuccess(http, data)
        return try decode(CompileResult.self, from: data).prompt
    }

    // MARK: - POST /api/image

    /// size 为生图像素串（如 "1152*1536"，星号分隔）；nil 不传，由模型默认画幅。
    /// skillId 为官方模版 id：服务端据此按混搭注册表选择生图供应商；nil（直接输入/用户模版）走服务端全局默认
    func generate(prompt: String, imageUrls: [String] = [], size: String? = nil, seed: Int? = nil, negativePrompt: String? = nil, skillId: String? = nil) async throws -> [String] {
        struct Payload: Encodable {
            let prompt: String
            let imageUrls: [String]?
            let size: String?
            let seed: Int?
            let negativePrompt: String?
            let skillId: String?
        }
        let payload = Payload(
            prompt: prompt,
            imageUrls: imageUrls.isEmpty ? nil : imageUrls,
            size: size,
            seed: seed,
            negativePrompt: negativePrompt,
            skillId: skillId
        )
        let request = try await makeRequest(path: "/api/image", method: "POST", json: payload)
        let (data, http) = try await sendWithAuthRetry(request)
        try expectSuccess(http, data)
        return try decode(ImageResult.self, from: data).urls
    }

    // MARK: - 账号（SIWA 用户系统）

    /// 登录：SIWA 系统面板凭据 → POST /api/auth/apple 换发会话令牌（公开端点，不携 Bearer）
    func loginWithApple(identityToken: String, fullName: String) async throws -> LoginReply {
        guard let accountAuth else { throw AppError.notConfigured }
        try await assertConsent()
        let base = await currentBaseURL()
        var request = URLRequest(url: URL(string: base.absoluteString + "/api/auth/apple")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        struct Payload: Encodable {
            let identityToken: String
            let fullName: String
            let deviceId: String?
        }
        let payload = Payload(
            identityToken: identityToken,
            fullName: fullName,
            deviceId: await deviceAuth.currentDeviceID()
        )
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else { throw AppError.decoding }
        try expectSuccess(http, data)
        let reply = try decode(LoginReply.self, from: data)
        await accountAuth.storeSession(token: reply.token, session: reply.user)
        return reply
    }

    /// 退出登录：吊销会话令牌后本地清会话（降级游客）
    func logout() async throws {
        let request = try await makeRequest(path: "/api/auth/logout", method: "POST")
        let (_, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else { throw AppError.decoding }
        // 401 也视为已失效：本地清会话即可
        guard (200..<300).contains(http.statusCode) || http.statusCode == 401 else {
            throw AppError(status: http.statusCode, body: nil)
        }
        await accountAuth?.clearSession()
    }

    /// 注销账号：服务端软删 + 吊销全部会话令牌（Guideline 5.1.1(v)）
    func deleteAccount() async throws {
        let request = try await makeRequest(path: "/api/account/delete", method: "POST")
        let (data, http) = try await sendWithAuthRetry(request)
        try expectSuccess(http, data)
        await accountAuth?.clearSession()
    }

    /// 今日额度摘要
    func quota() async throws -> Quota {
        let request = try await makeRequest(path: "/api/quota", method: "GET")
        let (data, http) = try await sendWithAuthRetry(request)
        try expectSuccess(http, data)
        return try decode(Quota.self, from: data)
    }

    /// IAP 落账：StoreKit 票据 JWS 上送服务端验签加余额（幂等）
    func confirmPurchase(jws: String) async throws -> (remaining: Int, applied: Bool) {
        struct Reply: Codable {
            let remaining: Int
            let applied: Bool
        }
        let request = try await makeRequest(path: "/api/billing/confirm", method: "POST", json: ["jws": jws])
        let (data, http) = try await sendWithAuthRetry(request)
        try expectSuccess(http, data)
        let reply = try decode(Reply.self, from: data)
        return (reply.remaining, reply.applied)
    }

    // MARK: - 内部

    /// 隐私同意闸门：未同意（含不同意）时所有网络操作就地拦截
    @MainActor
    private func assertConsent() throws {
        if let consent, !consent.hasConsented {
            throw AppError.consentRequired
        }
    }

    /// 令牌选择：会话令牌优先（登录态），无则设备令牌（游客）
    private func makeRequest(path: String, method: String, json: (any Encodable)? = nil) async throws -> URLRequest {
        try await assertConsent()
        let base = await currentBaseURL()
        let token: String
        if let sessionToken = await accountAuth?.currentToken() {
            token = sessionToken
        } else {
            token = try await deviceAuth.token(baseURL: base)
        }
        let url = URL(string: base.absoluteString + path)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = Self.requestTimeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(json)
        }
        return request
    }

    /// 当前生效基地址（dev 覆盖合法时取覆盖值）
    private func currentBaseURL() async -> URL {
        let override = await settings.serverURLString
        return config.baseURL(overrideString: override)
    }

    /// 401 自愈发送：仅 code=UNAUTHORIZED（会话/设备令牌失效）才降级重发；
    /// 其他 401（如 BILLING_INVALID 票据验签失败）原样返回，避免误清登录态。
    /// httpBody 为 Data 可安全重放。
    private func sendWithAuthRetry(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else { throw AppError.decoding }
        guard http.statusCode == 401 else { return (data, http) }
        let body = try? JSONDecoder().decode(APIErrorBody.self, from: data)
        guard body?.code == "UNAUTHORIZED" else { return (data, http) }
        let base = await currentBaseURL()

        // 会话令牌失效：降级游客，以设备令牌重发
        if await accountAuth?.currentToken() != nil {
            await accountAuth?.clearSession()
            var retried = request
            let deviceToken = try await deviceAuth.token(baseURL: base)
            retried.setValue("Bearer \(deviceToken)", forHTTPHeaderField: "Authorization")
            let (data2, response2) = try await send(retried)
            guard let http2 = response2 as? HTTPURLResponse else { throw AppError.decoding }
            return (data2, http2)
        }

        // 设备令牌失效：重注册一次后用新 token 重建并重发同一请求
        try await deviceAuth.reRegister(baseURL: base)
        var retried = request
        let token = try await deviceAuth.token(baseURL: base)
        retried.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data2, response2) = try await send(retried)
        guard let http2 = response2 as? HTTPURLResponse else { throw AppError.decoding }
        return (data2, http2)
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            throw AppError.network(error.localizedDescription)
        } catch {
            throw AppError.network(String(describing: error))
        }
    }

    private func expectSuccess(_ http: HTTPURLResponse, _ data: Data) throws {
        guard !(200..<300).contains(http.statusCode) else { return }
        let body = try? JSONDecoder().decode(APIErrorBody.self, from: data)
        throw AppError(status: http.statusCode, body: body)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AppError.decoding
        }
    }

    // MARK: - 缓存文件（按环境命名空间隔离，防 dev/prod 同设备 ETag 串台）

    private static let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]

    nonisolated var skillsFileURL: URL { Self.cacheDir(for: config, root: cacheRoot).appendingPathComponent("skills.json") }
    nonisolated var etagFileURL: URL { Self.cacheDir(for: config, root: cacheRoot).appendingPathComponent("skills.etag") }

    private nonisolated static func cacheDir(for config: AppConfiguration, root: URL?) -> URL {
        let dir = (root ?? cachesDir).appendingPathComponent(config.environment.rawValue, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func readCache() throws -> [SkillCard] {
        let data = try Data(contentsOf: skillsFileURL)
        return try JSONDecoder().decode([SkillCard].self, from: data)
    }
}
