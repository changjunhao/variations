//
//  APIClientTests.swift
//  VariationsTests
//
//  URLProtocol stub 覆盖 200/304/401（含重注册自愈）/400/502 与请求头/请求体契约。
//

import XCTest
@testable import Variations

/// 拦截全部请求的 stub protocol
final class StubURLProtocol: URLProtocol {
    struct Reply {
        var status: Int
        var data: Data
        var headers: [String: String] = [:]
    }

    nonisolated(unsafe) static var handler: ((URLRequest) -> Reply)?
    nonisolated(unsafe) static var recorded: [URLRequest] = []
    private static let lock = NSLock()

    static func reset(handler: ((URLRequest) -> Reply)?) {
        lock.lock(); defer { lock.unlock() }
        self.handler = handler
        recorded = []
    }

    static func record(_ request: URLRequest) {
        lock.lock(); defer { lock.unlock() }
        recorded.append(request)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let reply = Self.handler?(request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        // URLSession 经 URLProtocol 投递时 body 在 httpBodyStream，读出后随记录暴露给断言
        var recorded = request
        if recorded.httpBody == nil, let stream = recorded.httpBodyStream {
            stream.open()
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: 4096)
                if read <= 0 { break }
                body.append(buffer, count: read)
            }
            stream.close()
            recorded.httpBody = body
        }
        Self.record(recorded)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: reply.status,
            httpVersion: "HTTP/1.1",
            headerFields: reply.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class APIClientTests: XCTestCase {

    private var client: APIClient!
    /// 测试专用缓存根目录：与宿主 App 的真实 Caches 隔离，防 fixture 污染应用缓存
    private var cacheRoot: URL!

    override func setUp() {
        super.setUp()
        cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("apiclienttests-cache-\(UUID().uuidString)", isDirectory: true)
        let defaults = UserDefaults(suiteName: "apiclienttests")!
        defaults.removePersistentDomain(forName: "apiclienttests")
        let settings = SettingsStore(defaults: defaults)
        // 预置设备 token：DeviceAuth 直接读凭据，不触发注册请求
        let credentialStore = InMemoryCredentialStore()
        try? credentialStore.write("device-token", key: DeviceAuth.tokenKey)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        client = APIClient(
            settings: settings,
            config: AppConfiguration(environment: .dev),
            deviceAuth: DeviceAuth(store: credentialStore, session: session),
            session: session,
            cacheRoot: cacheRoot
        )
        try? FileManager.default.removeItem(at: client.skillsFileURL)
        try? FileManager.default.removeItem(at: client.etagFileURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheRoot)
        client = nil
        cacheRoot = nil
        super.tearDown()
    }

    private static let skillsJSON = Data("""
    [{"id":"oil","name":"oil","description":"d","displayName":"油画变奏","shortDescription":"s","defaultPrompt":"p","sampleImageUrl":null}]
    """.utf8)

    func testSkills200SendsBearerTokenAndDecodes() async throws {
        StubURLProtocol.reset { _ in .init(status: 200, data: Self.skillsJSON, headers: ["ETag": "\"v1\""]) }
        let cards = try await client.skills()
        XCTAssertEqual(cards[0].displayName, "油画变奏")
        let request = StubURLProtocol.recorded[0]
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer device-token")
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Api-Token"), "旧鉴权头不应再出现")
        XCTAssertNil(request.value(forHTTPHeaderField: "If-None-Match"))
    }

    func testSkills304ReturnsDiskCache() async throws {
        StubURLProtocol.reset { _ in .init(status: 200, data: Self.skillsJSON, headers: ["ETag": "\"v1\""]) }
        _ = try await client.skills()
        StubURLProtocol.reset { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "If-None-Match"), "\"v1\"")
            return .init(status: 304, data: Data())
        }
        let cached = try await client.skills()
        XCTAssertEqual(cached[0].id, "oil")
        XCTAssertEqual(StubURLProtocol.recorded[0].value(forHTTPHeaderField: "If-None-Match"), "\"v1\"")
    }

    /// 401 自愈：重注册后重试仍 401 → 最终抛 unauthorized，且发生过一次设备注册
    func testUnauthorized401AfterReRegister() async throws {
        StubURLProtocol.reset { request in
            if request.url!.path == "/api/auth/device" {
                return .init(status: 200, data: Data(#"{"token":"var_new","deviceId":"d-1"}"#.utf8))
            }
            return .init(status: 401, data: Data(#"{"code":"UNAUTHORIZED","message":"token"}"#.utf8))
        }
        do {
            _ = try await client.skills()
            XCTFail("should throw")
        } catch let error as AppError {
            guard case .unauthorized = error else { return XCTFail("wrong case") }
        }
        // 恰好一次重注册（防循环）
        let registrations = StubURLProtocol.recorded.filter { $0.url!.path == "/api/auth/device" }
        XCTAssertEqual(registrations.count, 1)
    }

    /// 401 自愈成功：重注册后重试返回 200
    func testUnauthorized401SelfHealsWithReRegister() async throws {
        var skillsCalls = 0
        StubURLProtocol.reset { request in
            if request.url!.path == "/api/auth/device" {
                return .init(status: 200, data: Data(#"{"token":"var_new","deviceId":"d-1"}"#.utf8))
            }
            skillsCalls += 1
            return skillsCalls == 1
                ? .init(status: 401, data: Data(#"{"code":"UNAUTHORIZED","message":"expired"}"#.utf8))
                : .init(status: 200, data: Self.skillsJSON, headers: [:])
        }
        let cards = try await client.skills()
        XCTAssertEqual(cards[0].id, "oil")
        XCTAssertEqual(skillsCalls, 2)
        // 重试请求携带新 token
        let last = StubURLProtocol.recorded.last!
        XCTAssertEqual(last.value(forHTTPHeaderField: "Authorization"), "Bearer var_new")
    }

    func testBadRequest400CarriesMessage() async throws {
        StubURLProtocol.reset { _ in .init(status: 400, data: Data(#"{"code":"BAD_REQUEST","message":"prompt 必填"}"#.utf8)) }
        do {
            _ = try await client.generate(prompt: "x")
            XCTFail("should throw")
        } catch let error as AppError {
            guard case .badRequest(let message) = error else { return XCTFail("wrong case") }
            XCTAssertEqual(message, "prompt 必填")
        }
    }

    func testUpstream502() async throws {
        StubURLProtocol.reset { _ in .init(status: 502, data: Data(#"{"code":"ARK_ERROR","message":"boom"}"#.utf8)) }
        do {
            _ = try await client.generate(prompt: "x")
            XCTFail("should throw")
        } catch let error as AppError {
            guard case .upstream = error else { return XCTFail("wrong case") }
        }
    }

    func testCompilePayloadMutualExclusion() async throws {
        StubURLProtocol.reset { _ in .init(status: 200, data: Data(#"{"prompt":"compiled"}"#.utf8)) }
        let prompt = try await client.compile(skillId: "oil", imageUrl: "https://oss.example.com/a.jpg")
        XCTAssertEqual(prompt, "compiled")
        let body = try JSONSerialization.jsonObject(with: StubURLProtocol.recorded[0].httpBody!) as! [String: Any]
        XCTAssertEqual(body["skillId"] as? String, "oil")
        XCTAssertNil(body["inlineSkill"])
        XCTAssertNil(body["instruction"], "空 instruction 应省略")
    }

    func testSkillsUsesEnvironmentBaseURL() async throws {
        StubURLProtocol.reset { _ in .init(status: 200, data: Self.skillsJSON, headers: [:]) }
        _ = try await client.skills()
        let url = StubURLProtocol.recorded[0].url!
        XCTAssertEqual(url.scheme, "http")
        XCTAssertEqual(url.host, "localhost")
        XCTAssertEqual(url.path, "/api/skills")
    }

    @MainActor
    func testDevOverrideChangesBaseURL() async throws {
        let defaults = UserDefaults(suiteName: "apiclienttests3")!
        defaults.removePersistentDomain(forName: "apiclienttests3")
        let settings = SettingsStore(defaults: defaults)
        settings.serverURLString = "http://192.168.1.10:8787"
        let credentialStore = InMemoryCredentialStore()
        try? credentialStore.write("device-token", key: DeviceAuth.tokenKey)
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        let overridden = APIClient(
            settings: settings,
            config: AppConfiguration(environment: .dev),
            deviceAuth: DeviceAuth(store: credentialStore, session: session),
            session: session,
            cacheRoot: cacheRoot
        )
        StubURLProtocol.reset { _ in .init(status: 200, data: Self.skillsJSON, headers: [:]) }
        _ = try await overridden.skills()
        XCTAssertEqual(StubURLProtocol.recorded[0].url?.host, "192.168.1.10")
    }

    @MainActor
    func testProdIgnoresOverride() async throws {
        let defaults = UserDefaults(suiteName: "apiclienttests4")!
        defaults.removePersistentDomain(forName: "apiclienttests4")
        let settings = SettingsStore(defaults: defaults)
        settings.serverURLString = "http://192.168.1.10:8787"
        let credentialStore = InMemoryCredentialStore()
        try? credentialStore.write("device-token", key: DeviceAuth.tokenKey)
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        let prod = APIClient(
            settings: settings,
            config: AppConfiguration(environment: .prod),
            deviceAuth: DeviceAuth(store: credentialStore, session: session),
            session: session,
            cacheRoot: cacheRoot
        )
        StubURLProtocol.reset { _ in .init(status: 200, data: Self.skillsJSON, headers: [:]) }
        _ = try await prod.skills()
        XCTAssertEqual(StubURLProtocol.recorded[0].url?.host, "variations.ifable.cn")
    }
}
