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

    // MARK: - iPhone Duo 折痕避让

    /// Duo 外屏 466pt（compact）与内屏 669/951pt（regular）落在既有档位区间：
    /// 摊平态不降级，列数与宽度档位一致
    func testDuoWidthsUseExistingTiersWhenFlat() {
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 466, foldDivisionActive: false), 2, "Duo 外屏宽度两列")
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 669, foldDivisionActive: false), 3, "Duo 内屏竖屏三列")
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 951, foldDivisionActive: false), 4, "Duo 内屏横屏四列")
    }

    /// 半折书本姿态（division region 激活）：奇数列减一，中列不骑折痕
    func testFoldDivisionDropsOddColumnCount() {
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 669, foldDivisionActive: true), 2, "半折 669pt 三列降两列")
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 599, foldDivisionActive: true), 2, "两列已为偶数，保持")
    }

    /// 折痕激活不影响偶数高档，且减列下限为 2
    func testFoldDivisionKeepsEvenCountAndFloor() {
        XCTAssertEqual(HomeGrid.skillColumnCount(width: 951, foldDivisionActive: true), 4, "四列已为偶数，保持")
        XCTAssertGreaterThanOrEqual(HomeGrid.skillColumnCount(width: 0, foldDivisionActive: true), 2, "列数下限 2")
    }
}
