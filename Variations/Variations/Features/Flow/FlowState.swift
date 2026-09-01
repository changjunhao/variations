//
//  FlowState.swift
//  Variations
//
//  模版流程状态机：选图 → 压缩 → 直传 → 附加指令 → 编译。
//  官方模版走 skillId；用户模版走 inlineSkill。
//

import SwiftUI
import PhotosUI
import CryptoKit

@Observable
final class FlowState: Hashable {

    enum Kind: Sendable {
        case official(SkillCard)
        case userTemplate(name: String, body: String)
        case direct
    }

    enum Stage {
        case pick
        case compressing
        case uploading(Double)
        case uploaded
        case failed(String)
    }

    let kind: Kind

    /// 选图预览
    var previewImage: UIImage?
    /// 压缩后 JPEG
    var compressedData: Data?
    /// 原图像素尺寸（EXIF 摆正后），供朝向跟随画幅判定
    var sourcePixelWidth = 0
    var sourcePixelHeight = 0
    /// 原始文件名/大小（展示用）
    var fileName = "photo.jpg"
    var stage: Stage = .pick
    /// 上传成功后的 bucket 签名 URL（compile 的 imageUrl；签名 ≤2h，编译前凭 sourceHash 重签）
    var fileUrl: String?
    /// 上传内容的 SHA-256（内容寻址对象键 uploads/{hash}.jpg）：签名过期后凭它重签新 GET 票据；
    /// 对象本身 48h 后由生命周期清理，清理后重签返回「不可变奏」
    var sourceHash: String?
    /// 附加指令（可选，自由文本；官方模版带 instructionTemplate 时由结构化取值拼装替代）
    var instruction = ""
    /// 结构化附加指令取值（标签 → 值）；空值/未选的标签不下发
    var instructionValues: [String: String] = [:]
    /// 编译结果原文（供 PromptEditor 恢复原文）
    var compiledOriginal: String?
    /// 编辑后最终提示词（开始变奏时写回）
    var editedPrompt = ""
    /// 画幅尺寸（生图像素串）；nil = 不传，由模型默认画幅。
    /// 模版流程由 skill 元数据决定（不可选）：比例串（如 "3:5"）编译后按原图朝向换算成像素；加倍串（"x2"）原图短边加倍；
    /// 源比例串（"src"）画幅严格保持原图宽高比；直接输入由用户选择（默认自动）
    var size: String?
    /// 生成参考图 URL（模版流程=上传图；直接输入=附图）
    var referenceUrls: [String] = []

    private var uploadTask: Task<Void, Never>?

    /// 比例串/加倍串换算时的长边像素（服务端只收像素串，如 "3:5" → 960*1600 / 1600*960）
    private static let ratioLongSide = 1600
    /// 加倍串标记：原图短边加倍（拼接类模版：竖版宽加倍→横版画布，横版/方图高加倍→竖版画布）
    private static let doubleToken = "x2"
    /// 源比例串标记：画幅严格保持原图宽高比（长边缩放至 1600），用于「保留原图比例」类模版
    private static let sourceRatioToken = "src"

    init(kind: Kind) {
        self.kind = kind
        // 官方模版画幅跟随 skill 元数据；用户模版/直接输入默认自动
        if case .official(let card) = kind {
            size = card.size
        }
    }

    var title: String {
        switch kind {
        case .official(let card): card.displayName.isEmpty ? card.name : card.displayName
        case .userTemplate(let name, _): name
        case .direct: "直接输入"
        }
    }

    /// 官方模版 id：生图时透传给服务端（按混搭注册表选择生图供应商）；用户模版/直接输入为 nil
    var skillId: String? {
        if case .official(let card) = kind { return card.id }
        return nil
    }

    var isUploaded: Bool {
        if case .uploaded = stage { return true }
        return false
    }

    // MARK: - 选图

    func handlePicked(_ item: PhotosPickerItem?, services: AppServices) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            stage = .failed("图片无法读取，请换一张试试。")
            return
        }
        stage = .compressing
        do {
            let output = try await ImageCompressor.compress(data: data)
            compressedData = output.data
            sourcePixelWidth = output.pixelWidth
            sourcePixelHeight = output.pixelHeight
            previewImage = UIImage(data: output.data)
            // 新图就绪，旧图的派生状态全部作废：提示词需重新编译，参考图/画幅回到待解析态；
            // 否则下一轮开始变奏时 ComposingView 发现 editedPrompt 非空会跳过编译，按旧图生成
            fileUrl = nil
            sourceHash = nil
            compiledOriginal = nil
            editedPrompt = ""
            referenceUrls = []
            if case .official(let card) = kind { size = card.size }
            await startUpload(services: services)
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    // MARK: - 直传

    func startUpload(services: AppServices) async {
        guard let jpeg = compressedData else { return }
        stage = .uploading(0)
        // 对最终上传字节（压缩后）计算 SHA-256：服务端据此生成内容寻址对象键 uploads/{hash}.jpg
        // （同图去重、幂等覆盖）；fileUrl 签名 ≤2h，对象 48h 生命周期内编译/变奏前凭哈希重签，
        // 对象被清理后重签返回「不可变奏」
        let hash = SHA256.hash(data: jpeg).map { String(format: "%02x", $0) }.joined()
        sourceHash = hash
        uploadTask = Task { [weak self] in
            do {
                let ticket = try await services.api.uploadTicket(hash: hash)
                let final = try await OSSUploader.upload(
                    jpeg: jpeg,
                    ticket: ticket,
                    progress: { fraction in
                        self?.stage = .uploading(fraction)
                    },
                    refetchTicket: { try await services.api.uploadTicket(hash: hash) }
                )
                self?.fileUrl = final.fileUrl
                self?.stage = .uploaded
            } catch {
                self?.stage = .failed(error.localizedDescription)
            }
        }
        await uploadTask?.value
    }

    func cancelUpload() {
        uploadTask?.cancel()
        uploadTask = nil
        if case .uploading = stage { stage = .pick }
    }

    /// 发送给编译的附加指令：官方模版带结构化模板时按「【标签】：值」逐行拼装（跳过空值），否则用自由文本
    var assembledInstruction: String {
        guard case .official(let card) = kind,
              let template = card.instructionTemplate, !template.isEmpty
        else { return instruction }
        return template.compactMap { field in
            let value = instructionValues[field.label]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? nil : "【\(field.label)】：\(value)"
        }.joined(separator: "\n")
    }

    // MARK: - 编译

    func compile(services: AppServices) async throws -> String {
        guard fileUrl != nil else { throw AppError.notConfigured }
        // 签名有效期 ≤2h：编译前凭内容哈希重签新票据，避免 VL 拉到过期签名；
        // 源图已被 48h 生命周期清理时抛 sourceFileGone（「不可变奏」）
        if let sourceHash {
            fileUrl = try await services.api.fileURL(hash: sourceHash).fileUrl
        }
        guard let imageUrl = fileUrl else { throw AppError.notConfigured }
        let prompt: String
        switch kind {
        case .official(let card):
            prompt = try await services.api.compile(skillId: card.id, imageUrl: imageUrl, instruction: assembledInstruction)
        case .userTemplate(_, let body):
            prompt = try await services.api.compile(inlineSkill: InlineSkill(body: body), imageUrl: imageUrl, instruction: assembledInstruction)
        case .direct:
            throw AppError.notConfigured
        }
        compiledOriginal = prompt
        referenceUrls = [imageUrl]
        resolveOrientationSize()
        return prompt
    }

    /// 编译后按原图朝向解析画幅：skill 元数据 size 为比例串（如 "3:5"）时，
    /// 竖版/方图 → 短:长，横版 → 长:短（换算成像素串）；"x2" 时原图短边加倍；"src" 时严格保持原图宽高比；
    /// 像素串 / nil / 未识别值原样保留
    private func resolveOrientationSize() {
        guard case .official(let card) = kind else { return }
        guard sourcePixelWidth > 0, sourcePixelHeight > 0 else { return }
        if card.size == Self.doubleToken {
            size = Self.doubledSize(width: sourcePixelWidth, height: sourcePixelHeight)
            return
        }
        if card.size == Self.sourceRatioToken {
            size = Self.sourceRatioSize(width: sourcePixelWidth, height: sourcePixelHeight)
            return
        }
        guard let ratio = Self.parseRatio(card.size) else { return }
        let long = Self.ratioLongSide
        let short = long * ratio.short / ratio.long
        // 方图按竖版处理
        size = sourcePixelWidth > sourcePixelHeight ? "\(long)*\(short)" : "\(short)*\(long)"
    }

    /// "x2" 加倍换算：竖版 → 宽加倍（左右拼接横版画布）；横版/方图 → 高加倍（上下拼接竖版画布），整体按长边 1600 缩放
    private static func doubledSize(width: Int, height: Int) -> String {
        // 方图按上下拼接处理（高加倍）
        var w = width, h = height
        if width >= height { h *= 2 } else { w *= 2 }
        let scale = Double(ratioLongSide) / Double(max(w, h))
        return "\(Int((Double(w) * scale).rounded()))*\(Int((Double(h) * scale).rounded()))"
    }

    /// "src" 源比例换算：画幅严格保持原图宽高比，整体按长边 1600 缩放
    private static func sourceRatioSize(width: Int, height: Int) -> String {
        let scale = Double(ratioLongSide) / Double(max(width, height))
        return "\(Int((Double(width) * scale).rounded()))*\(Int((Double(height) * scale).rounded()))"
    }

    /// 解析 "3:5" 这类比例串（不区分短长边书写顺序）；像素串或 nil 返回 nil
    private static func parseRatio(_ size: String?) -> (short: Int, long: Int)? {
        let parts = size?.split(separator: ":") ?? []
        guard parts.count == 2, let a = Int(parts[0]), let b = Int(parts[1]), a > 0, b > 0, a != b else { return nil }
        return a < b ? (a, b) : (b, a)
    }

    // MARK: - Hashable（按身份，供 NavigationStack value）

    static func == (lhs: FlowState, rhs: FlowState) -> Bool { lhs === rhs }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
