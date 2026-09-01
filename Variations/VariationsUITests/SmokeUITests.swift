//
//  SmokeUITests.swift
//  VariationsUITests
//
//  冒烟：启动 → 三 Tab 切换 → 直输页进入与取消。
//

import XCTest

final class SmokeUITests: XCTestCase {

    /// 启动 + 过隐私同意页（干净环境首次启动会展示同意闸门）
    @MainActor
    private func launchPastConsent() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let agree = app.buttons["同意并继续"]
        if agree.waitForExistence(timeout: 5) { agree.tap() }
        return app
    }

    @MainActor
    func testTabSwitching() throws {
        let app = launchPastConsent()

        XCTAssertTrue(app.staticTexts["变奏"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["官方模版"].exists)

        app.buttons["变奏集"].tap()
        XCTAssertTrue(app.staticTexts["共 0 号变奏"].waitForExistence(timeout: 2))

        // 设置项（服务器地址）已并入「我的」页
        app.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["服务器地址"].waitForExistence(timeout: 2))

        app.buttons["首页"].tap()
        XCTAssertTrue(app.staticTexts["官方模版"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDirectEntryOpensAndBack() throws {
        let app = launchPastConsent()

        app.staticTexts["直接输入提示词"].tap()
        XCTAssertTrue(app.staticTexts["附图（可选，无图时为文生图）"].waitForExistence(timeout: 2))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["我的模版"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDirectRowHittableAfterScroll() throws {
        let app = launchPastConsent()

        let row = app.staticTexts["直接输入提示词"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        // 滚到底，确认不被胶囊 TabBar 遮挡
        for _ in 0..<3 { app.swipeUp() }
        XCTAssertTrue(row.isHittable, "直接输入行应可点击（不被 TabBar 遮挡）")
        row.tap()
        XCTAssertTrue(app.staticTexts["附图（可选，无图时为文生图）"].waitForExistence(timeout: 2))
    }
}
