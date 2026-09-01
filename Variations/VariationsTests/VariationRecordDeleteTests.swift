//
//  VariationRecordDeleteTests.swift
//  VariationsTests
//
//  变奏集删除：记录删除时连带结果图/缩略图文件；缺文件/空路径容错；不误删其他记录。
//
//  注意：ModelContainer 必须活到测试结束（实例变量持有）——helper 返回 mainContext 后
//  局部 container 提前释放，后续上下文操作会 SIGTRAP（本环境实测）。
//

import SwiftData
import XCTest
@testable import Variations

final class VariationRecordDeleteTests: XCTestCase {

    private var container: ModelContainer?
    private var storeURL: URL?

    override func tearDown() {
        container = nil
        if let storeURL { try? FileManager.default.removeItem(at: storeURL) }
        storeURL = nil
        super.tearDown()
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("delete-test-\(UUID().uuidString).store")
        storeURL = url
        let container = try ModelContainer(
            for: UserSkillTemplate.self, PromptPreset.self, VariationRecord.self,
            configurations: ModelConfiguration(url: url)
        )
        self.container = container
        return container.mainContext
    }

    @MainActor
    func testDeleteRemovesRecordAndArtifactFiles() throws {
        let context = try makeContext()
        let resultRel = try ArtifactsStore.save(data: Data([0xFF, 0xD8]), kind: .results)
        let thumbRel = try ArtifactsStore.save(data: Data([0xFF, 0xD8]), kind: .thumbs)
        let record = VariationRecord(no: 1, skillName: "油画变奏", prompt: "p", size: "", resultRelPath: resultRel, thumbRelPath: thumbRel)
        context.insert(record)
        try context.save()

        VariationRecord.delete(record, in: context)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<VariationRecord>()).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ArtifactsStore.url(relative: resultRel).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: ArtifactsStore.url(relative: thumbRel).path))
    }

    @MainActor
    func testDeleteToleratesMissingArtifactFiles() throws {
        let context = try makeContext()
        // 无产物文件 + 指向已不存在路径，两种缺省都不能阻塞删除
        let orphan = VariationRecord(no: 1, skillName: "s", prompt: "p", size: "", resultRelPath: "results/gone.jpg", thumbRelPath: nil)
        context.insert(orphan)
        try context.save()

        VariationRecord.delete(orphan, in: context)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<VariationRecord>()).isEmpty)
    }

    @MainActor
    func testDeleteKeepsOtherRecordsAndFiles() throws {
        let context = try makeContext()
        let victimThumb = try ArtifactsStore.save(data: Data([0x01]), kind: .thumbs)
        let survivorThumb = try ArtifactsStore.save(data: Data([0x02]), kind: .thumbs)
        let victim = VariationRecord(no: 1, skillName: "s", prompt: "p", size: "", thumbRelPath: victimThumb)
        let survivor = VariationRecord(no: 2, skillName: "s", prompt: "p", size: "", thumbRelPath: survivorThumb)
        context.insert(victim)
        context.insert(survivor)
        try context.save()

        VariationRecord.delete(victim, in: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<VariationRecord>())
        XCTAssertEqual(remaining.map(\.no), [2])
        XCTAssertFalse(FileManager.default.fileExists(atPath: ArtifactsStore.url(relative: victimThumb).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: ArtifactsStore.url(relative: survivorThumb).path))
        ArtifactsStore.remove(relative: survivorThumb)
    }
}
