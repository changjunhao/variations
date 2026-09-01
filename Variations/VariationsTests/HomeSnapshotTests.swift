//
//  HomeSnapshotTests.swift
//  VariationsTests
//
//  设计还原快照：HomeView 浅/深双态。视图经 layer.render 离屏渲染为 UIImage，
//  再由 swift-snapshot-testing 管理基线与比对。基线入库；
//  重录基线：SNAPSHOT_RECORD=1 xcodebuild test ... -only-testing:VariationsTests/HomeSnapshotTests
//

import SnapshotTesting
import SwiftData
import SwiftUI
import UIKit
import XCTest
@testable import Variations

final class HomeSnapshotTests: XCTestCase {

    override func invokeTest() {
        if ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1" {
            isRecording = true
        }
        super.invokeTest()
    }

    @MainActor
    private func render(dark: Bool) -> UIImage {
        let container = try! ModelContainer(
            for: UserSkillTemplate.self, PromptPreset.self, VariationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let services = AppServices(
            settings: SettingsStore(defaults: UserDefaults(suiteName: "snapshot")!)
        )
        let root = HomeView()
            .environment(services)
            .environment(Router())
            .modelContainer(container)

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
    func testHomeLight() {
        assertSnapshot(of: render(dark: false), as: .image)
    }

    @MainActor
    func testHomeDark() {
        assertSnapshot(of: render(dark: true), as: .image)
    }
}
