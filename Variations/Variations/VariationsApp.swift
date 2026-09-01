//
//  VariationsApp.swift
//  Variations
//
//  入口：SwiftData schema（三类本地数据）+ AppServices 注入。
//

import SwiftUI
import SwiftData

@main
struct VariationsApp: App {
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
        }
        .modelContainer(sharedModelContainer)
    }
}
