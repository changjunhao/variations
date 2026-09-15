//
//  ComposingSnapshotTests.swift
//  VariationsTests
//
//  设计还原快照：谱写变奏舞台（设计稿 04）浅/深双态，固定拍 2（音符 3 跳跃定格）。
//  渲染经 SnapshotHost（真实 window + drawHierarchy），基线按 OS 大版本分文件；重录基线：
//  SNAPSHOT_RECORD=1 xcodebuild test ... -only-testing:VariationsTests/ComposingSnapshotTests
//

import SnapshotTesting
import SwiftUI
import UIKit
import XCTest
@testable import Variations

final class ComposingSnapshotTests: XCTestCase {

    override func invokeTest() {
        if ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1" {
            isRecording = true
        }
        super.invokeTest()
    }

    /// 基线按 OS 大版本分文件：同一用例在 iOS 26/27 各留一份
    private var osTag: String {
        "iOS\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"
    }

    /// 基线以 iPhone idiom 为准（同 HomeSnapshotTests）
    private func skipUnlessPhoneIdiom() throws {
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .phone,
            "设计快照基线以 iPhone idiom 为准；iPad 请只跑非快照用例"
        )
    }

    @MainActor
    private func render(dark: Bool) -> UIImage {
        let root = ComposingStageView(
            status: "第 3 号变奏排练中…",
            phase: .composing,
            fixedBeat: 2,
            entranceEnabled: false
        )
        .background(Theme.background)

        return SnapshotHost.image(of: root, size: CGSize(width: 393, height: 852), dark: dark)
    }

    @MainActor
    func testComposingLight() throws {
        try skipUnlessPhoneIdiom()
        assertSnapshot(of: render(dark: false), as: .image, named: osTag)
    }

    @MainActor
    func testComposingDark() throws {
        try skipUnlessPhoneIdiom()
        assertSnapshot(of: render(dark: true), as: .image, named: osTag)
    }
}
