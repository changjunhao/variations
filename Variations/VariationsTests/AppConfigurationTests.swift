//
//  AppConfigurationTests.swift
//  VariationsTests
//
//  构建期环境解析与基地址决议：覆盖生效/回落默认/未知值 fail-safe。
//

import XCTest
@testable import Variations

final class AppConfigurationTests: XCTestCase {

    // MARK: - 环境解析

    func testParsesEnvironmentFromBundle() {
        let bundle = Bundle(info: ["AppEnvironment": "dev"])!
        XCTAssertEqual(AppConfiguration(bundle: bundle).environment, .dev)
    }

    func testUnknownEnvironmentFallsBackToProd() {
        let bundle = Bundle(info: ["AppEnvironment": "staging"])!
        XCTAssertEqual(AppConfiguration(bundle: bundle).environment, .prod)
    }

    func testMissingEnvironmentFallsBackToProd() {
        let bundle = Bundle(info: [:])!
        XCTAssertEqual(AppConfiguration(bundle: bundle).environment, .prod)
    }

    // MARK: - 基地址决议

    func testDevDefaultBaseURL() {
        let config = AppConfiguration(environment: .dev)
        XCTAssertEqual(config.baseURL(overrideString: nil).absoluteString, AppConfiguration.devBaseURLString)
        XCTAssertEqual(config.baseURL(overrideString: "").absoluteString, AppConfiguration.devBaseURLString)
        XCTAssertEqual(config.baseURL(overrideString: "   ").absoluteString, AppConfiguration.devBaseURLString)
    }

    func testDevValidOverrideWins() {
        let config = AppConfiguration(environment: .dev)
        let url = config.baseURL(overrideString: "http://192.168.1.10:8787")
        XCTAssertEqual(url.absoluteString, "http://192.168.1.10:8787")
    }

    func testDevInsecureOverrideFallsBackToDefault() {
        let config = AppConfiguration(environment: .dev)
        // http 公网地址非法 → 回落内置默认
        XCTAssertEqual(
            config.baseURL(overrideString: "http://8.8.8.8:8787").absoluteString,
            AppConfiguration.devBaseURLString
        )
    }

    func testProdAlwaysUsesBuildTimeURL() {
        let config = AppConfiguration(environment: .prod)
        // prod 忽略一切覆盖（含看似合法的 dev 地址）
        XCTAssertEqual(
            config.baseURL(overrideString: "http://localhost:8787").absoluteString,
            AppConfiguration.prodBaseURLString
        )
        XCTAssertEqual(config.baseURL(overrideString: nil).absoluteString, AppConfiguration.prodBaseURLString)
    }

    // MARK: - 展示

    func testDisplayName() {
        XCTAssertEqual(AppConfiguration(environment: .dev).displayName, "开发环境")
        XCTAssertEqual(AppConfiguration(environment: .prod).displayName, "正式环境")
    }
}

/// 经临时目录生成最小 bundle，注入指定 infoDictionary（测试环境解析用）
private extension Bundle {
    convenience init?(info: [String: Any]) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppConfigurationTests-\(UUID().uuidString).bundle")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            try plist.write(to: dir.appendingPathComponent("Info.plist"))
        } catch {
            return nil
        }
        self.init(path: dir.path)
    }
}
