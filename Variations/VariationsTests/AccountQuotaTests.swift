//
//  AccountQuotaTests.swift
//  VariationsTests
//
//  用户系统客户端单测：AccountAuth 会话存储 / AppError 配额映射 / QuotaStore 状态机 / ConsentStore 三态。
//

import XCTest
@testable import Variations

final class AccountQuotaTests: XCTestCase {

    // MARK: - AccountAuth 会话存储

    func testAccountSessionRoundtrip() async throws {
        let auth = AccountAuth(store: InMemoryAccountStore())
        var token: String? = await auth.currentToken()
        var session: AccountSession? = await auth.currentSession()
        XCTAssertNil(token)
        XCTAssertNil(session)

        let expected = AccountSession(name: "常 君豪", email: "r@privaterelay.appleid.com", isPrivateEmail: true)
        await auth.storeSession(token: "var_u_test", session: expected)

        token = await auth.currentToken()
        XCTAssertEqual(token, "var_u_test")
        session = await auth.currentSession()
        XCTAssertEqual(session, expected)

        await auth.clearSession()
        token = await auth.currentToken()
        session = await auth.currentSession()
        XCTAssertNil(token)
        XCTAssertNil(session)
    }

    // MARK: - SIWA nonce 跨端契约

    /// 摘要算法必须与服务端 auth.NonceDigest 逐字节一致，否则登录全部 401。
    /// 期望值为 sha256("raw-nonce-abc123")，与 Go 端单测取同一常量。
    func testAppleNonceDigestMatchesServerContract() {
        XCTAssertEqual(
            AppleNonce.digest("raw-nonce-abc123"),
            "835b1ca706560c781e760c508e48479d1d65bff56b7c4ef1551fc1ac222c7e33")
    }

    /// raw nonce 需为 URL 安全字符（+/= 会在传输与摘要环节埋雷）且每次不同
    func testAppleNonceRawIsURLSafeAndUnique() {
        let a = AppleNonce.makeRaw()
        let b = AppleNonce.makeRaw()
        XCTAssertNotEqual(a, b, "nonce 必须每次重新生成，否则失去防重放意义")
        XCTAssertFalse(a.contains("+") || a.contains("/") || a.contains("="))
        XCTAssertFalse(a.isEmpty)
    }

    /// 会话编码兼容：旧版本落库的 JSON 无 appleUserID 键，必须能解码为 nil
    func testAccountSessionDecodesLegacyPayloadWithoutAppleUserID() throws {
        let legacy = #"{"name":"常 君豪","email":"a@b.c","isPrivateEmail":true}"#
        let session = try JSONDecoder().decode(AccountSession.self, from: Data(legacy.utf8))
        XCTAssertNil(session.appleUserID)
        XCTAssertEqual(session.name, "常 君豪")
    }

    // MARK: - AppError 配额映射

    func testQuotaExceededMapping() {
        let body = APIErrorBody(code: "QUOTA_EXCEEDED", message: "今日次数已用完")
        if case .quotaExceeded = AppError(status: 429, body: body) {
        } else {
            XCTFail("429 QUOTA_EXCEEDED 应映射 quotaExceeded")
        }
        // 其他 429 不映射
        if case .http = AppError(status: 429, body: APIErrorBody(code: "RATE_LIMITED", message: "x")) {
        } else {
            XCTFail("普通 429 应映射 http")
        }
    }

    func testQuotaExceededMessage() {
        let error = AppError(status: 429, body: APIErrorBody(code: "QUOTA_EXCEEDED", message: ""))
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - QuotaStore 状态机

    func testQuotaStoreConsumeAndExhaust() {
        let store = QuotaStore()
        XCTAssertFalse(store.exhausted) // 未知不阻断

        // 游客：体验 1 次
        store.apply(Quota(tier: "guest", source: nil,
                          trial: .init(remaining: 1, limit: 1),
                          privilege: nil, paid: nil, resetsAt: "t"))
        XCTAssertFalse(store.exhausted)
        store.consume()
        XCTAssertTrue(store.exhausted)
        XCTAssertTrue(store.exhaustedHint.contains("登录"))

        // 用户：特权期内当日满但已购有余额 → 不耗尽，扣已购
        store.apply(Quota(tier: "user", source: nil, trial: nil,
                          privilege: .init(active: true, daysLeft: 3, remainingToday: 0, limitToday: 10),
                          paid: .init(remaining: 5), resetsAt: "t"))
        XCTAssertFalse(store.exhausted)
        store.consume()
        XCTAssertEqual(store.quota?.paid?.remaining, 4)

        // 用户：特权过期且已购 0 → 耗尽，引导购买
        store.apply(Quota(tier: "user", source: nil, trial: nil,
                          privilege: .init(active: false, daysLeft: 0, remainingToday: 0, limitToday: 10),
                          paid: .init(remaining: 0), resetsAt: "t"))
        XCTAssertTrue(store.exhausted)
        XCTAssertTrue(store.exhaustedHint.contains("购买"))
        XCTAssertFalse(store.showsTrack) // 永久余额不画谱线
    }

    func testQuotaStorePrivilegeTrack() {
        let store = QuotaStore()
        store.apply(Quota(tier: "user", source: nil, trial: nil,
                          privilege: .init(active: true, daysLeft: 5, remainingToday: 9, limitToday: 10),
                          paid: .init(remaining: 0), resetsAt: "t"))
        XCTAssertTrue(store.showsTrack)
        XCTAssertEqual(store.trackFraction, 0.9, accuracy: 0.001)
        XCTAssertEqual(store.quotaLabel, "今日额度")
        XCTAssertTrue(store.quotaValueText.contains("特权剩 5 天"))
        store.consume()
        XCTAssertEqual(store.quota?.privilege?.remainingToday, 8)
    }

    // MARK: - ConsentStore 三态

    func testConsentStateTransitions() {
        let defaults = UserDefaults(suiteName: "consent-test")!
        defaults.removeObject(forKey: "privacyConsentState")
        defaults.removeObject(forKey: "aiSharingConsentVersion")
        defaults.removeObject(forKey: "aiSharingConsentGrantedAt")
        let store = ConsentStore(defaults: defaults)
        XCTAssertFalse(store.decided)
        XCTAssertFalse(store.hasConsented)
        XCTAssertFalse(store.hasAISharingConsent)

        store.decline()
        XCTAssertTrue(store.decided)
        XCTAssertFalse(store.hasConsented)
        XCTAssertFalse(store.hasAISharingConsent)

        // 持久化：新实例读取
        let reloaded = ConsentStore(defaults: defaults)
        XCTAssertEqual(reloaded.state, .declined)

        reloaded.consent()
        XCTAssertTrue(reloaded.hasConsented)
        XCTAssertTrue(ConsentStore(defaults: defaults).hasConsented)
        // 基础同意 ≠ AI 共享授权：必须显式 grantAISharing 才允许照片/提示词离开设备
        XCTAssertFalse(ConsentStore(defaults: defaults).hasAISharingConsent)

        store.grantAISharing()
        // 基础同意尚未取得：AI 共享授权不能单独生效
        XCTAssertFalse(store.hasAISharingConsent)
        store.consent()
        XCTAssertTrue(store.hasAISharingConsent)
        XCTAssertNotNil(store.aiSharingGrantedAt)
        // 持久化：新实例读取 AI 共享授权版本与时间戳
        let reloaded2 = ConsentStore(defaults: defaults)
        XCTAssertTrue(reloaded2.hasAISharingConsent)
        XCTAssertNotNil(reloaded2.aiSharingGrantedAt)

        store.revokeAISharing()
        XCTAssertFalse(store.hasAISharingConsent)
        XCTAssertNil(store.aiSharingGrantedAt)
        XCTAssertTrue(ConsentStore(defaults: defaults).hasConsented) // 基础同意不受撤回影响

        defaults.removeObject(forKey: "privacyConsentState")
        defaults.removeObject(forKey: "aiSharingConsentVersion")
        defaults.removeObject(forKey: "aiSharingConsentGrantedAt")
    }
}
