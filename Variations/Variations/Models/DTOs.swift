//
//  DTOs.swift
//  Variations
//
//  四接口 Codable 契约，字段逐一对齐 variations-serve-go/internal/handlers/ 的响应 DTO。
//

import Foundation

// 纯值类型显式 nonisolated：工程默认 MainActor 隔离下，Codable 合成实现
// 会被隔离到 MainActor，actor APIClient 解码时不可用。

/// GET /api/skills 的风格卡片
nonisolated struct SkillCard: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let displayName: String
    let shortDescription: String
    let defaultPrompt: String
    let sampleImageUrl: String?
    /// 样图宽高比（宽/高）：按此开固定比例盒完整显示样图，无异步尺寸跳变；nil = 未知（按 4:3 占位、图完整居中）
    let sampleImageAspect: Double?
    /// 模版画幅：像素串（"960*1600"）固定画布；比例串（"3:5"）编译后按原图朝向换算成像素；加倍串（"x2"）原图短边加倍（拼接类模版）；源比例串（"src"）画幅严格保持原图宽高比；nil = 不限制，由模型自动推荐
    let size: String?
    /// 附加指令的结构化模板（【标签】：值）；nil = 回退自由文本框
    let instructionTemplate: [InstructionField]?
}

/// 附加指令模板的单个字段：options 为枚举值域（单选胶囊，缺省“自动”即不下发该标签）；placeholder 为自由文本输入提示
nonisolated struct InstructionField: Codable, Hashable, Sendable {
    let label: String
    let options: [String]?
    let placeholder: String?
}

/// GET /api/upload-ticket 的票据（对象键内容寻址 uploads/{hash}.{ext}；
/// fileUrl 签名有效期 ≤2h，对象本身 48h 后由生命周期清理，超期前可走 /api/file-url 重签）
nonisolated struct UploadTicket: Codable, Sendable {
    let uploadUrl: String
    let fileUrl: String
    /// 客户端 PUT 必须携带的同值 Content-Type（已绑入签名）
    let contentType: String
    /// 上传签名失效时间（ISO 8601）
    let expiresAt: String
}

/// GET /api/file-url 的重签票据（再次变奏：对象还在 → 新 GET 预签名 ≤2h；已被清理 → 410 不可变奏）
nonisolated struct FileTicket: Codable, Sendable {
    let fileUrl: String
    /// GET 签名失效时间（ISO 8601）
    let expiresAt: String
}

/// 内容寻址源图引用：从预签名 URL 解析 uploads/{hash}.{ext} 对象键，供 /api/file-url 重签新票据
nonisolated struct SourceRef: Sendable {
    let hash: String
    let ext: String

    private static let fileNamePattern = /^[0-9a-f]{64}\.(jpg|jpeg|png|webp|bmp)$/

    /// 解析预签名 URL 中的对象键；非 uploads/{hash}.{ext} 形态返回 nil
    static func parse(_ urlString: String) -> SourceRef? {
        guard let comps = URLComponents(string: urlString) else { return nil }
        guard let name = comps.path.split(separator: "/").last.map(String.init),
              name.wholeMatch(of: fileNamePattern) != nil
        else { return nil }
        let dot = name.lastIndex(of: ".")!
        return SourceRef(hash: String(name[..<dot]), ext: String(name[name.index(after: dot)...]))
    }
}

/// POST /api/compile 的用户自建模版（inlineSkill 路径）
nonisolated struct InlineSkill: Codable, Sendable {
    var body: String
    var files: [String: String]? = nil
}

/// POST /api/compile 响应
nonisolated struct CompileResult: Codable, Sendable {
    let prompt: String
}

/// POST /api/image 响应
nonisolated struct ImageResult: Codable, Sendable {
    let urls: [String]
}

/// 统一错误体 { code, message }
nonisolated struct APIErrorBody: Codable, Sendable {
    let code: String
    let message: String
}

/// GET /api/quota 与登录响应中的配额摘要（次数口径三态：trial/privilege/paid）
nonisolated struct Quota: Codable, Sendable, Equatable {
    let tier: String            // guest | user | admin
    let source: String?         // 429 时附耗尽来源：trial_exhausted / privilege_exhausted / paid_exhausted
    let trial: Trial?
    let privilege: Privilege?
    let paid: Paid?
    let resetsAt: String

    nonisolated struct Trial: Codable, Sendable, Equatable {
        let remaining: Int
        let limit: Int
    }

    nonisolated struct Privilege: Codable, Sendable, Equatable {
        let active: Bool
        let daysLeft: Int
        let remainingToday: Int
        let limitToday: Int
    }

    nonisolated struct Paid: Codable, Sendable, Equatable {
        let remaining: Int
    }
}

/// POST /api/auth/apple 响应：会话令牌 + 账号档案 + 额度
nonisolated struct LoginReply: Codable, Sendable {
    let token: String
    let user: AccountSession
    let quota: Quota
}

/// 画幅尺寸（设计稿 03 三档胶囊，仅直接输入流程可选；模版流程由 skill 元数据决定）
nonisolated enum SizeOption: String, CaseIterable, Codable, Sendable {
    case square = "1:1"
    case portrait = "3:4"
    case wide = "9:16"

    /// 生图 size 参数（像素串）
    var apiValue: String {
        switch self {
        case .square: "1280*1280"
        case .portrait: "1152*1536"
        case .wide: "896*1600"
        }
    }
}
