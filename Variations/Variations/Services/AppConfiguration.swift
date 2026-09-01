//
//  AppConfiguration.swift
//  Variations
//
//  构建期环境配置：xcconfig(APP_ENVIRONMENT) → Info.plist → 此类型化解析。
//  基地址映射的单一事实源；正式地址上线前替换 prodBaseURLString 一处即可。
//

import Foundation

/// 构建期环境：Debug 构建 → dev，Release 构建 → prod
nonisolated enum AppEnvironment: String, Sendable {
    case dev
    case prod
}

nonisolated struct AppConfiguration: Sendable {

    let environment: AppEnvironment

    var isDev: Bool { environment == .dev }

    var displayName: String { isDev ? "开发环境" : "正式环境" }

    /// 环境默认基地址
    var defaultBaseURLString: String {
        isDev ? Self.devBaseURLString : Self.prodBaseURLString
    }

    /// 生效基地址：dev 且覆盖合法时用覆盖值，否则环境默认；永不为 nil
    func baseURL(overrideString: String?) -> URL {
        if isDev,
           let override = overrideString?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty,
           ServerURLValidator.isValid(override),
           let url = URL(string: override) {
            return url
        }
        return URL(string: defaultBaseURLString)!
    }

    // MARK: - 环境默认地址

    /// dev 内置默认（模拟器开箱即用；真机联调在设置页覆盖为 Mac 局域网 IP）
    static let devBaseURLString = "http://localhost:8787"

    /// prod 正式环境地址
    static let prodBaseURLString = "https://variations.ifable.cn"

    // MARK: - 解析

    /// environment 显式注入（测试用）；缺省读 Bundle Info.plist 的 AppEnvironment，
    /// 缺失/未知值 fail-safe 回退 .prod（宁指正式也不误连开发）
    init(environment: AppEnvironment? = nil, bundle: Bundle = .main) {
        if let environment {
            self.environment = environment
            return
        }
        let raw = bundle.infoDictionary?["AppEnvironment"] as? String ?? ""
        self.environment = AppEnvironment(rawValue: raw) ?? .prod
    }
}
