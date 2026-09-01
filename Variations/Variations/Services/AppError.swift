//
//  AppError.swift
//  Variations
//
//  统一错误类型：HTTP 状态 + 后端 { code, message } → 中文提示。
//

import Foundation

enum AppError: Error, LocalizedError, Sendable {
    /// 未配置服务器地址
    case notConfigured
    /// 隐私政策未同意：网络操作被闸门拦截
    case consentRequired
    /// 401
    case unauthorized
    /// 400（附后端 message）
    case badRequest(String)
    /// 404
    case notFound(String)
    /// 413
    case bodyTooLarge
    /// 410：源图已过 48h 保留期被清理，不可变奏（不得降级文生图）
    case sourceFileGone
    /// 429 QUOTA_EXCEEDED：当日积分耗尽（tier 由调用方按登录态区分文案）
    case quotaExceeded
    /// 403 ACCOUNT_DELETED：账号已注销
    case accountDeleted
    /// 502 上游错误（DASHSCOPE_ERROR / ARK_ERROR）
    case upstream(String)
    /// 其他 HTTP 错误
    case http(status: Int, message: String?)
    /// 网络/传输层
    case network(String)
    /// 响应解码失败
    case decoding
    /// 图片无法读取/编码
    case invalidImage
    /// OSS 直传失败（附状态码）
    case uploadFailed(status: Int)

    /// 由 HTTP 响应构造
    init(status: Int, body: APIErrorBody?) {
        switch status {
        case 401: self = .unauthorized
        case 400: self = .badRequest(body?.message ?? "")
        case 403: self = body?.code == "ACCOUNT_DELETED" ? .accountDeleted : .http(status: status, message: body?.message)
        case 404: self = .notFound(body?.message ?? "")
        case 410: self = .sourceFileGone
        case 413: self = .bodyTooLarge
        case 429: self = body?.code == "QUOTA_EXCEEDED" ? .quotaExceeded : .http(status: status, message: body?.message)
        case 502, 503: self = .upstream(body?.message ?? "")
        default: self = .http(status: status, message: body?.message)
        }
    }

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "尚未配置服务器地址，请到「设置」填写。"
        case .consentRequired:
            "需先同意《隐私政策》才能使用该功能。"
        case .unauthorized:
            "设备身份校验失败，请重试（将自动重新注册）。"
        case .badRequest(let message):
            message.isEmpty ? "请求参数有误。" : "请求有误：\(message)"
        case .notFound(let message):
            message.isEmpty ? "内容不存在或已下线。" : message
        case .bodyTooLarge:
            "内容过大，请精简后重试。"
        case .sourceFileGone:
            "不可变奏：源图已超过 48 小时保留期被清理。"
        case .quotaExceeded:
            "今日次数已用完，明天零点再来吧。"
        case .accountDeleted:
            "该账号已注销。"
        case .upstream(let message):
            "AI 服务暂时不可用，请稍后重试。\(message.isEmpty ? "" : "（\(message)）")"
        case .http(let status, let message):
            "服务异常（\(status)）。\(message ?? "")"
        case .network(let message):
            "网络不通：\(message)"
        case .decoding:
            "服务响应无法解析，请检查服务器地址。"
        case .invalidImage:
            "图片无法读取，请换一张试试。"
        case .uploadFailed(let status):
            "图片上传失败（\(status)），已自动重试仍失败，请检查网络后重试。"
        }
    }
}
