//
//  HomeSnapshotTests.swift
//  VariationsTests
//
//  设计还原快照：HomeView 浅/深双态 + 窗口化宽度分档（700pt 三列 / 1024pt 四列）。
//
//  渲染必须挂真实 UIWindow：UIHostingController 脱离 window 层级时 SwiftUI 不构建内容，
//  layer.render 只能拍到纯色空白（此前入库的基线即是全空图，两个不同页面字节完全相同）。
//  现改为 window + drawHierarchy(afterScreenUpdates:)，玻璃等视觉效果层也能正确合成。
//
//  确定性：官方模版需先过隐私同意闸门，干净容器下必然落到「需先同意隐私政策」提示态；
//  服务器地址另指向恒拒连端口做双保险（本机起了后端也不影响基线）；
//  「我的模版」由内存容器预置两条，保证网格有内容。
//
//  基线按 OS 大版本分文件（named: "iOS27"）——玻璃/系统 chrome 换代后新旧基线不互相覆盖。
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

    /// 基线按 OS 大版本分文件：同一用例在 iOS 26/27 各留一份
    private var osTag: String {
        "iOS\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"
    }

    /// 基线以 iPhone idiom 为准：同一像素尺寸在 iPad 上的控件度量与玻璃外观不同，
    /// 两套 idiom 各留基线只会翻倍二进制维护量。iPad 的宽版式已由
    /// 1024pt 宽度用例与 HomeGridTests 覆盖，故在 iPad 上显式跳过而非默默失败。
    private func skipUnlessPhoneIdiom() throws {
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .phone,
            "设计快照基线以 iPhone idiom 为准；iPad 请只跑非快照用例"
        )
    }

    @MainActor
    private func render(dark: Bool, size: CGSize = CGSize(width: 393, height: 852)) -> UIImage {
        let container = try! ModelContainer(
            for: UserSkillTemplate.self, PromptPreset.self, VariationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        container.mainContext.insert(UserSkillTemplate(name: "夏日胶片", body: "# skill"))
        container.mainContext.insert(UserSkillTemplate(name: "水墨小景", body: "# skill"))

        let settings = SettingsStore(defaults: UserDefaults(suiteName: "snapshot")!)
        // 端口 1 恒拒连：即使后续放开同意闸门，官方模版也不会受本机后端影响
        settings.serverURLString = "http://127.0.0.1:1"

        let root = HomeView()
            .environment(AppServices(settings: settings))
            .environment(Router())
            .modelContainer(container)

        return SnapshotHost.image(of: root, size: size, dark: dark)
    }

    @MainActor
    func testHomeLight() throws {
        try skipUnlessPhoneIdiom()
        assertSnapshot(of: render(dark: false), as: .image, named: osTag)
    }

    @MainActor
    func testHomeDark() throws {
        try skipUnlessPhoneIdiom()
        assertSnapshot(of: render(dark: true), as: .image, named: osTag)
    }

    /// iPad 全屏宽版式（1024pt）：锁住 32pt 页边距与「大标题交给侧栏页眉」。
    /// 官方模版网格的列数不在此图覆盖范围（同意闸门下不渲染网格），
    /// 分档逻辑由 HomeGridTests 直接锁定
    @MainActor
    func testHomeRegularWidth() throws {
        try skipUnlessPhoneIdiom()
        let image = render(dark: false, size: CGSize(width: 1024, height: 1366))
        assertSnapshot(of: image, as: .image, named: osTag)
    }

    /// 窗口化中等宽度（700pt）：锁住宽版式在中间宽度也生效（旧启发式在此会误判为紧凑）
    @MainActor
    func testHomeWindowedWidth() throws {
        try skipUnlessPhoneIdiom()
        let image = render(dark: false, size: CGSize(width: 700, height: 1000))
        assertSnapshot(of: image, as: .image, named: osTag)
    }
}
