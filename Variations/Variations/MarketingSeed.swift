//
//  MarketingSeed.swift
//  Variations
//
//  仅 DEBUG：App Store 营销截图种子。启动参数 -marketingSeed <目录>（含 art-1/2/3.jpg）
//  时向变奏集注入 No.7/8/9 演示记录（结果图直接复用目录内作品图），Release 无任何行为。
//

#if DEBUG
import Foundation
import SwiftData

enum MarketingSeed {

    static let args = ProcessInfo.processInfo.arguments

    static var seedDir: String? {
        guard let i = args.firstIndex(of: "-marketingSeed"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    /// 幂等注入：已有记录时跳过（同模拟器多次启动不重复）
    static func seedRecordsIfNeeded(context: ModelContext) {
        guard let dir = seedDir else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<VariationRecord>())) ?? 0
        guard existing == 0 else { return }

        let items: [(file: String, skillName: String, skillId: String)] = [
            ("art-1.jpg", "废片焕新 · Photo Revival", "photo-revival"),
            ("art-2.jpg", "静谧版画 · Woodcut Zine", "joy-calm-woodcut-zine"),
            ("art-3.jpg", "晶析 · Crystalize", "crystalize"),
        ]
        for (i, item) in items.enumerated() {
            let url = URL(fileURLWithPath: dir).appendingPathComponent(item.file)
            guard let data = try? Data(contentsOf: url) else { continue }
            let resultRel = try? ArtifactsStore.save(data: data, kind: .results, name: "marketing-\(i)")
            let thumbRel = try? ArtifactsStore.save(data: data, kind: .thumbs, name: "marketing-\(i)")
            context.insert(VariationRecord(
                no: 7 + i,
                skillName: item.skillName,
                skillId: item.skillId,
                prompt: "marketing seed",
                size: "3:4",
                seed: 20260824,
                resultRelPath: resultRel,
                thumbRelPath: thumbRel
            ))
        }
        try? context.save()
    }
}
#endif
