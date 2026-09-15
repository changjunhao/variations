//
//  SmokeUITests.swift
//  VariationsUITests
//
//  冒烟：启动 → 三 Tab 切换 → 直输页进入与取消。
//  Tab 切换走系统控件：compact 是 tabBars，regular（iPad/宽窗口）经 sidebarAdaptable
//  升为侧栏，命中的是 collectionViews 里的 cell，故按容器分支查找。
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

    /// 点 Tab：优先系统 TabBar（compact），侧栏形态下回退到任意可点的同名元素
    @MainActor
    private func selectTab(_ name: String, in app: XCUIApplication) {
        let tabBarButton = app.tabBars.buttons[name]
        if tabBarButton.waitForExistence(timeout: 2), tabBarButton.isHittable {
            tabBarButton.tap()
            return
        }
        let anyMatch = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", name))
            .firstMatch
        XCTAssertTrue(anyMatch.waitForExistence(timeout: 3), "找不到 Tab「\(name)」")
        anyMatch.tap()
    }

    @MainActor
    func testTabSwitching() throws {
        let app = launchPastConsent()

        XCTAssertTrue(app.staticTexts["官方模版"].waitForExistence(timeout: 5))

        selectTab("变奏集", in: app)
        XCTAssertTrue(app.staticTexts["共 0 号变奏"].waitForExistence(timeout: 3))

        // 设置项（服务器地址）已并入「我的」页
        selectTab("我的", in: app)
        XCTAssertTrue(app.staticTexts["服务器地址"].waitForExistence(timeout: 3))

        selectTab("首页", in: app)
        XCTAssertTrue(app.staticTexts["官方模版"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testDirectEntryOpensAndBack() throws {
        let app = launchPastConsent()

        app.staticTexts["直接输入提示词"].tap()
        XCTAssertTrue(app.staticTexts["附图（可选，无图时为文生图）"].waitForExistence(timeout: 2))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["我的模版"].waitForExistence(timeout: 2))
    }

    /// 滚到底后「直接输入」行仍可点：原先防的是自绘胶囊 TabBar 遮挡，
    /// 现为系统 TabBar（iOS 26+ 下滑会最小化），断言语义不变——底部行不被 chrome 吃掉
    @MainActor
    func testDirectRowHittableAfterScroll() throws {
        let app = launchPastConsent()

        let row = app.staticTexts["直接输入提示词"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        for _ in 0..<3 { app.swipeUp() }
        XCTAssertTrue(row.isHittable, "直接输入行应可点击（不被系统 TabBar 遮挡）")
        row.tap()
        XCTAssertTrue(app.staticTexts["附图（可选，无图时为文生图）"].waitForExistence(timeout: 2))
    }
}
