//
//  VariationsApp.swift
//  Variations
//
//  入口：SwiftData schema（三类本地数据）+ AppServices 注入。
//  两个 scene 共用同一 ModelContainer；iPad 多窗口下单号变奏可独立成窗。
//

import SwiftUI
import SwiftData

@main
struct VariationsApp: App {
    /// App 层 @State：每进程一份，跨 scene 共享（见 AppServices 注释）
    @State private var services = AppServices()

    init() {
        ImagePipelineBootstrap.configure()
        AppAppearance.configure()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserSkillTemplate.self,
            PromptPreset.self,
            VariationRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // 隐私同意闸门：未决定 → 同意页；已决定 → 主界面（不同意仅可浏览，网络操作就地拦截）
            Group {
                if services.consent.decided {
                    RootView()
                } else {
                    ConsentGateView()
                }
            }
            .environment(services)
            .tint(Theme.primary)
            .bridgeReducedResourceUsage()
        }
        .modelContainer(sharedModelContainer)

        // 单号变奏独立窗口（iPad 多窗口：变奏集长按 →「在新窗口打开」）。
        // 只读本机产物，不过同意闸门；「再变奏一次」的网络调用仍由 APIClient 就地拦截。
        WindowGroup(for: PersistentIdentifier.self) { $recordID in
            RecordWindow(recordID: recordID)
                .environment(services)
                .tint(Theme.primary)
                .bridgeReducedResourceUsage()
        }
        .modelContainer(sharedModelContainer)
    }
}
