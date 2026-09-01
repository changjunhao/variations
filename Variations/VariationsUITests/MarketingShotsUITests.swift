//
//  MarketingShotsUITests.swift
//  VariationsUITests
//
//  App Store 营销截图采集：DEBUG 种子注入演示变奏，逐屏截原生分辨率图。
//  运行：MARKETING_PREFIX=iphone xcodebuild test -destination '<sim>' -only-testing:VariationsUITests/MarketingShotsUITests
//  产物：<repo>/Variations/AppStore/out/sim/<prefix>-{home,collection,result}.png
//

import XCTest

final class MarketingShotsUITests: XCTestCase {

    private static let seedDir = "/Users/ifable/Desktop/repositories/variations/Variations/AppStore/assets"
    private static let outDir = "/Users/ifable/Desktop/repositories/variations/Variations/AppStore/out/sim"

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 启动 + 过隐私同意页
    private func startApp(extraArgs: [String] = []) {
        app = XCUIApplication()
        app.launchArguments += extraArgs
        app.launch()

        let agree = app.buttons["同意并继续"]
        if agree.waitForExistence(timeout: 5) {
            agree.tap()
        }
    }

    // MARK: - 三屏采集

    func testMarketingShots() throws {
        let prefix = ProcessInfo.processInfo.environment["MARKETING_PREFIX"] ?? "shot"
        startApp(extraArgs: [
            "-marketingSeed", Self.seedDir,
            "-StoreKitConfigurationFileURL", "file://" + Self.seedDir + "/paywall.storekit",
            "-marketingPaywall",
        ])

        // 1) 首页：等官方模版网格与样图加载
        XCTAssertTrue(
            app.staticTexts["晶析 · Crystalize"].waitForExistence(timeout: 15),
            "官方模版未加载（后端是否已起？）"
        )
        Thread.sleep(forTimeInterval: 8) // 样图异步解码（本地后端，留足余量防占位块）
        shot("\(prefix)-home")

        // 2) 变奏集：胶囊 Tab（iPhone）或侧栏行（iPad）
        tapTab("变奏集")
        XCTAssertTrue(app.staticTexts["No.9"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.0)
        shot("\(prefix)-collection")

        // 3) 结果舞台：竖幅猫作品（No.7）更撑竖屏舞台
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS 'No.7'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.staticTexts["Variation No.7"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.5) // 结果图解码
        shot("\(prefix)-result")

        // 4) IAP 审核信息截屏：我的页 DEBUG 参数自动拉起 PaywallSheet
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3), "结果页导航栏")
        app.navigationBars.firstMatch.buttons.firstMatch.tap() // 返回
        tapTab("我的")
        XCTAssertTrue(app.staticTexts["轻享包"].waitForExistence(timeout: 10), "StoreKit 配置未生效")
        Thread.sleep(forTimeInterval: 1.0)
        shot("\(prefix)-paywall")
    }

    // MARK: - 工具

    private func tapTab(_ title: String) {
        if app.buttons[title].waitForExistence(timeout: 3) {
            app.buttons[title].tap()
        } else {
            app.staticTexts[title].firstMatch.tap()
        }
    }

    private func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let dir = URL(fileURLWithPath: Self.outDir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(name).png")
        do {
            try png.write(to: url, options: .atomic)
            print("[marketing-shot] saved \(url.path)")
        } catch {
            XCTFail("截图写盘失败 \(url.path): \(error)")
        }
    }
}
