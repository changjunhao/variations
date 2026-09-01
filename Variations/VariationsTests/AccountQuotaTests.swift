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

    // MARK: - AppError 配额/注销映射

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
        // 注销
        if case .accountDeleted = AppError(status: 403, body: APIErrorBody(code: "ACCOUNT_DELETED", message: "x")) {
        } else {
            XCTFail("403 ACCOUNT_DELETED 应映射 accountDeleted")
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
        let store = ConsentStore(defaults: defaults)
        XCTAssertFalse(store.decided)
        XCTAssertFalse(store.hasConsented)

        store.decline()
        XCTAssertTrue(store.decided)
        XCTAssertFalse(store.hasConsented)

        // 持久化：新实例读取
        let reloaded = ConsentStore(defaults: defaults)
        XCTAssertEqual(reloaded.state, .declined)

        reloaded.consent()
        XCTAssertTrue(reloaded.hasConsented)
        XCTAssertTrue(ConsentStore(defaults: defaults).hasConsented)
        defaults.removeObject(forKey: "privacyConsentState")
    }
}
