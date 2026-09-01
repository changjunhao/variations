//
//  StaffConductorTests.swift
//  VariationsTests
//
//  五线谱谱写循环纯函数单测：拍序推进 / 齐亮停顿 / 淡出重置 / 循环与负拍边界。
//

import XCTest
@testable import Variations

final class StaffConductorTests: XCTestCase {

    func testComposeBeatsProgressLeftToRight() {
        // 拍 0：音符 1 跳跃，其余未谱写
        XCTAssertEqual(StaffConductor.phase(beat: 0, index: 0), .jumping)
        XCTAssertEqual(StaffConductor.phase(beat: 0, index: 1), .pending)
        XCTAssertEqual(StaffConductor.phase(beat: 0, index: 3), .pending)
        // 拍 2：左两个已谱写，音符 3 跳跃，音符 4 未谱写
        XCTAssertEqual(StaffConductor.phase(beat: 2, index: 0), .composed)
        XCTAssertEqual(StaffConductor.phase(beat: 2, index: 1), .composed)
        XCTAssertEqual(StaffConductor.phase(beat: 2, index: 2), .jumping)
        XCTAssertEqual(StaffConductor.phase(beat: 2, index: 3), .pending)
        // 拍 3：最后一个音符跳跃
        XCTAssertEqual(StaffConductor.phase(beat: 3, index: 2), .composed)
        XCTAssertEqual(StaffConductor.phase(beat: 3, index: 3), .jumping)
    }

    func testHoldBeatAllComposed() {
        for index in 0..<StaffMotion.noteCount {
            XCTAssertEqual(StaffConductor.phase(beat: 4, index: index), .composed)
        }
    }

    func testResetBeatAllPending() {
        for index in 0..<StaffMotion.noteCount {
            XCTAssertEqual(StaffConductor.phase(beat: 5, index: index), .pending)
        }
    }

    func testCycleWraps() {
        // 拍 6 = 拍 0；拍 10 = 拍 4（齐亮停顿）
        XCTAssertEqual(StaffConductor.phase(beat: 6, index: 0), .jumping)
        XCTAssertEqual(StaffConductor.phase(beat: 10, index: 3), .composed)
    }

    func testNegativeBeatWraps() {
        // -1 → 拍 5（淡出重置）
        XCTAssertEqual(StaffConductor.phase(beat: -1, index: 0), .pending)
    }
}
