//
//  Persistence.swift
//  Variations
//
//  SwiftData 三类本地数据：用户 SKILL 模版 / 提示词模版 / 变奏历史。
//  结果图与缩略图存 Application Support 文件，DB 仅存相对路径。
//

import Foundation
import SwiftData

/// 用户自建 SKILL.md 模版（编译时走 inlineSkill 上传，本机存储）
@Model
final class UserSkillTemplate {
    var name: String
    /// SKILL.md 全文（含 frontmatter），≤100KB（后端 validateInlineSkill）
    var body: String
    var createdAt: Date

    init(name: String, body: String, createdAt: Date = .now) {
        self.name = name
        self.body = body
        self.createdAt = createdAt
    }
}

/// 提示词模版（直接输入页可载入复用）
@Model
final class PromptPreset {
    var name: String
    var prompt: String
    var createdAt: Date

    init(name: String, prompt: String, createdAt: Date = .now) {
        self.name = name
        self.prompt = prompt
        self.createdAt = createdAt
    }
}

/// 变奏历史（变奏集页数据源）
@Model
final class VariationRecord {
    /// 变奏编号 Variation No.X
    var no: Int
    var skillName: String
    /// 官方模版 id（再变奏一次时透传给服务端选择生图供应商）；用户模版/直接输入/旧记录为 nil
    var skillId: String?
    var prompt: String
    var size: String
    var seed: Int?
    /// 结果图相对路径（Application Support 内）
    var resultRelPath: String?
    /// 缩略图相对路径
    var thumbRelPath: String?
    /// 生成参考图 URL（再变奏一次用；签名 ≤2h，再变奏时凭 uploads/{hash}.{ext} 内容哈希重签，源图被清理则不可变奏）
    var referenceUrls: [String]
    var createdAt: Date

    init(no: Int, skillName: String, skillId: String? = nil, prompt: String, size: String, seed: Int? = nil, resultRelPath: String? = nil, thumbRelPath: String? = nil, referenceUrls: [String] = [], createdAt: Date = .now) {
        self.no = no
        self.skillName = skillName
        self.skillId = skillId
        self.prompt = prompt
        self.size = size
        self.seed = seed
        self.resultRelPath = resultRelPath
        self.thumbRelPath = thumbRelPath
        self.referenceUrls = referenceUrls
        self.createdAt = createdAt
    }

    /// 删除记录并连带产物文件（结果图/缩略图）；编号不复用（nextNo 取 max+1 不受影响）
    static func delete(_ record: VariationRecord, in context: ModelContext) {
        ArtifactsStore.remove(relative: record.resultRelPath)
        ArtifactsStore.remove(relative: record.thumbRelPath)
        context.delete(record)
    }
}
