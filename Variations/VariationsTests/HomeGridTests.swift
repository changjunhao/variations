//
//  HomeGridTests.swift
//  VariationsTests
//
//  首页宽度分档：窗口化下 size class 不再等价于「宽窄」，分档改按实测容器宽度。
//  纯函数直测（不依赖布局时序），锁住 2/3/4 列的档位边界。
//

import XCTest
@testable import Variations

final class HomeGridTests: XCTestCase {

    /// iPhone 与窄窗口：两列
    func testCompactWidthsUseTwoColumns() {
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 0), 2, "首帧宽度未知时应走紧凑默认")
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 320), 2)
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 393), 2, "iPhone 竖屏")
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 599), 2, "宽版式阈值下沿")
    }

    /// 窗口化中等宽度：三列
    func testMediumWidthsUseThreeColumns() {
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 600), 3, "宽版式阈值上沿")
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 700), 3)
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 899), 3)
    }

    /// iPad 全屏/宽窗口：四列
    func testWideWidthsUseFourColumns() {
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 900), 4)
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 1024), 4, "iPad 竖屏")
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 1366), 4, "iPad 横屏")
    }

    /// 页边距档位与列数档位共用同一阈值，避免两套口径
    func testRegularLayoutSharesWideThreshold() {
        XCTAssertFalse(HomeGrid.isRegular(width: HomeGrid.wideThreshold - 1))
        XCTAssertTrue(HomeGrid.isRegular(width: HomeGrid.wideThreshold))
        XCTAssertEqual(
            HomeGrid.isRegular(width: 700),
            HomeGrid.skillColumnCount(width: 700) >= 3,
            "宽版式与宽网格应同时生效"
        )
    }

    /// iPad 竖屏曾被旧启发式（hSize regular + vSize compact）误判为窄档，
    /// 此处钉住：竖屏 1024pt 必须是宽版式四列
    func testIPadPortraitIsWideDespiteRegularVerticalSizeClass() {
        XCTAssertTrue(HomeGrid.isRegular(width: 1024))
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 1024), 4)
    }
}
