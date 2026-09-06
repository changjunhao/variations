//
//  AppServices.swift
//  Variations
//
//  依赖容器：AppConfiguration + SettingsStore + DeviceAuth + APIClient，经 environment 注入视图树。
//

import AuthenticationServices
import Foundation
import Observation
// KeychainAccess 未做 Sendable 标注；与 DeviceAuth 同口径，@preconcurrency 抑制告警
@preconcurrency import KeychainAccess

@Observable
final class AppServices {
    let config: AppConfiguration
    let settings: SettingsStore
    let deviceAuth: DeviceAuth
    let accountAuth: AccountAuth
    let consent: ConsentStore
    let quotaStore: QuotaStore
    let store: StoreModel
    let api: APIClient

    /// 会话变更计数：Apple 授权被用户停用而清会话时自增，
    /// 供「我的」页刷新登录态（否则页面停留时 UI 会停在已登录假象）
    var accountRevision = 0

    init(settings: SettingsStore = SettingsStore(), config: AppConfiguration = AppConfiguration()) {
        Self.removeLegacyManualToken()
        self.config = config
        self.settings = settings
        self.deviceAuth = DeviceAuth(
            store: KeychainCredentialStore(environment: config.environment.rawValue)
        )
        self.accountAuth = AccountAuth(
            store: KeychainAccountStore(environment: config.environment.rawValue)
        )
        self.consent = ConsentStore()
        self.quotaStore = QuotaStore()
        self.api = APIClient(settings: settings, config: config, deviceAuth: deviceAuth, accountAuth: accountAuth, consent: consent)
        self.store = StoreModel(api: self.api, quotaStore: self.quotaStore)
        self.store.start()
    }

    /// 一次性清理旧版手工 API Token 的 Keychain 残留：鉴权已切换为 DeviceAuth（设备身份令牌），
    /// 旧条目（service = cn.ifable.Variations, key = apiToken）不再被读取，直接移除
    private static func removeLegacyManualToken() {
        try? Keychain(service: "cn.ifable.Variations").remove("apiToken")
    }

    /// 测试/注入用构造器
    init(settings: SettingsStore, config: AppConfiguration, deviceAuth: DeviceAuth, accountAuth: AccountAuth, consent: ConsentStore, quotaStore: QuotaStore, store: StoreModel, api: APIClient) {
        self.config = config
        self.settings = settings
        self.deviceAuth = deviceAuth
        self.accountAuth = accountAuth
        self.consent = consent
        self.quotaStore = quotaStore
        self.store = store
        self.api = api
    }

    /// 当前生效的服务器基地址（dev 覆盖合法时取覆盖值）
    var effectiveServerURLString: String {
        config.baseURL(overrideString: settings.serverURLString).absoluteString
    }

    // MARK: - Apple 授权状态（用户可在系统设置里停用本 App 的 Apple ID）

    /// 冷启动校对：授权已被停用/不存在时本地会话必须失效。
    /// 必要性：credentialRevokedNotification 仅在 App 运行时到达，离线期间的停用只能靠此补查；
    /// 旧版本落库的会话无 appleUserID，无法查询则跳过（下次登录便会补上）。
    func syncAppleCredentialState() async {
        guard let session = await accountAuth.currentSession(),
              let userID = session.appleUserID, !userID.isEmpty else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
        switch state {
        case .revoked, .notFound:
            await downgradeToGuest()
        default:
            // authorized / transferred / 查询失败（断网）均保留会话，不能因一次查不到就踢人下线
            break
        }
    }

    /// 收到系统授权撤销通知（App 运行中用户在设置里停用）
    func handleAppleCredentialRevoked() async {
        await downgradeToGuest()
    }

    /// 清本地会话降级游客：同时尝试告知服务端吊销令牌（不可达也不阻断本地清除）
    private func downgradeToGuest() async {
        try? await api.logout()
        await accountAuth.clearSession()
        await quotaStore.refresh(api: api)
        accountRevision += 1
    }
}
