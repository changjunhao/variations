//
//  RecordWindow.swift
//  Variations
//
//  单号变奏的独立窗口内容（iPad 多窗口）。
//  按 PersistentIdentifier 从共享容器取回记录；记录已被删除时给出空态而非空白窗。
//  复用 TabStack 拿到独立 NavigationStack + Router，「再变奏一次」在本窗内 push。
//

import SwiftUI
import SwiftData

struct RecordWindow: View {
    @Environment(\.modelContext) private var modelContext

    let recordID: PersistentIdentifier?

    var body: some View {
        if let record {
            TabStack {
                ResultView(record: record)
            }
        } else {
            missing
        }
    }

    private var record: VariationRecord? {
        guard let recordID else { return nil }
        return modelContext.model(for: recordID) as? VariationRecord
    }

    private var missing: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 30))
                .foregroundStyle(Theme.textSecondary)
            Text("这号变奏已不在变奏集中")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
