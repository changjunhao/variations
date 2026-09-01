//
//  ComposingSnapshotTests.swift
//  VariationsTests
//
//  设计还原快照：谱写变奏舞台（设计稿 04）浅/深双态，固定拍 2（音符 3 跳跃定格）。
//  渲染方式同 HomeSnapshotTests；重录基线：
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

    @MainActor
    private func render(dark: Bool) -> UIImage {
        let root = ComposingStageView(
            status: "第 3 号变奏排练中…",
            phase: .composing,
            fixedBeat: 2,
            entranceEnabled: false
        )
        .background(Theme.background)

        let host = UIHostingController(rootView: root)
        host.overrideUserInterfaceStyle = dark ? .dark : .light
        host.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        host.view.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex24: 0x191613) : UIColor(hex24: 0xFAF8F3)
        }
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: host.view.bounds.size, format: format).image { _ in
            host.view.layer.render(in: UIGraphicsGetCurrentContext()!)
        }
    }

    @MainActor
    func testComposingLight() {
        assertSnapshot(of: render(dark: false), as: .image)
    }

    @MainActor
    func testComposingDark() {
        assertSnapshot(of: render(dark: true), as: .image)
    }
}
