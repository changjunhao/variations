//
//  AppServices.swift
//  Variations
//
//  依赖容器：AppConfiguration + SettingsStore + DeviceAuth + APIClient，经 environment 注入视图树。
//

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
}
