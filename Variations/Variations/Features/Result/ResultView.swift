//
//  ResultView.swift
//  Variations
//
//  结果舞台（设计稿 05）：衬线斜体标题 + 大图 + 下载/分享/再变奏一次 + AI 标识。
//

import SwiftUI
import SwiftData
import Photos

struct ResultView: View {
    @Environment(AppServices.self) private var services
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var modelContext

    let record: VariationRecord

    @State private var busy = false
    @State private var errorMessage: String?
    /// 存相册后的轻提示（与设计“安静反馈”一致，自动消失，不上阻断式弹窗）
    @State private var saveToast: String?

    private var label: String { "Variation No.\(record.no)" }

    /// 结果图与水印成品：task 异步装载 + 缓存。
    /// 原实现为计算属性，每次 body 求值都同步装载全尺寸图并重烧水印——折叠设备
    /// 折/展连续 resize 提高求值频率，RecordWindow 多窗并存放大内存与 CPU 占用。
    /// 以 persistentModelID 为键：varyAgain push 新记录页时重新装载。
    @State private var resultImage: UIImage?
    @State private var watermarked: UIImage?
    /// 装载流程已结束（区分「装载中」与「文件缺失」两种舞台态）
    @State private var loadFinished = false

    var body: some View {
        VStack(spacing: 16) {
            Text(label)
                .font(Theme.Fonts.serifItalic(26))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 12)

            stage
                .overlay(alignment: .bottom) {
                    if let saveToast {
                        Text(saveToast)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Theme.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.textSecondary.opacity(0.15)))
                            .padding(.bottom, 12)
                            .transition(.opacity)
                    }
                }

            controls

            Text("由 AI 生成 · 变奏 Variations")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        // 内容列限宽 720pt 居中（DESIGN.md §6 结果舞台既有规定）：
        // Duo 内屏横屏 951pt 与 iPad 宽窗口下标题/控制行不拉满全宽；背景照旧满出血
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle(label)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if busy {
                ProgressView()
                    .padding(24)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
        }
        .alert("提示", isPresented: .constant(errorMessage != nil), actions: {
            Button("好") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .animation(.easeInOut(duration: 0.2), value: saveToast)
        .task(id: record.persistentModelID) { await loadImages() }
    }

    /// 异步装载结果图并烧水印（IO + 渲染 CPU 均在后台线程）；记录切换由 task(id:) 重建
    private func loadImages() async {
        resultImage = nil
        watermarked = nil
        loadFinished = false
        let rel = record.resultRelPath
        let label = self.label
        let pair = await Task.detached(priority: .userInitiated) { () -> (UIImage, UIImage)? in
            guard let rel,
                  let image = UIImage(contentsOfFile: ArtifactsStore.url(relative: rel).path) else { return nil }
            return (image, Watermark.burn(image, label: label))
        }.value
        resultImage = pair?.0
        watermarked = pair?.1
        loadFinished = true
    }

    // MARK: - 舞台

    private var stage: some View {
        Group {
            if let image = resultImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(alignment: .bottomTrailing) {
                        Text(label)
                            .font(Theme.Fonts.serifItalic(12))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
                            .padding(10)
                    }
            } else if loadFinished {
                ImagePlaceholder(label: "图片文件已丢失", icon: "exclamationmark.triangle")
            } else {
                // 装载中：占位保持舞台骨架稳定（本地 IO，极短）
                ImagePlaceholder(label: " ")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 操作

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                saveToAlbum()
            } label: {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.card))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("存到相册")

            if let share = watermarked {
                ShareLink(item: Image(uiImage: share), preview: SharePreview(label, image: Image(uiImage: share))) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.card))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("分享")
            }

            PrimaryButton(title: "再变奏一次", size: .compact, enabled: !busy && !services.quotaStore.exhausted) {
                Task { await varyAgain() }
            }
            if services.quotaStore.exhausted {
                Text(services.quotaStore.exhaustedHint)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 动作

    /// 落库 size → API 像素串：旧记录存比例文本（如 "3:4"）需映射；
    /// 新记录存像素串直接用；空串 = 自动（不传）
    private static func apiSize(_ stored: String) -> String? {
        if stored.isEmpty { return nil }
        return SizeOption(rawValue: stored)?.apiValue ?? stored
    }

    private func saveToAlbum() {
        guard let image = watermarked else { return }
        Task { await persistToAlbum(image) }
    }

    /// 仅申请「添加到相册」权限，落盘后给一次轻提示；权限被拒或写入失败均有可读反馈
    @MainActor
    private func persistToAlbum(_ image: UIImage) async {
        var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        }
        guard status == .authorized || status == .limited else {
            showSaveToast("无法保存：请在设置中允许「添加到相册」")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            showSaveToast("已存到相册")
        } catch {
            showSaveToast("保存失败，请稍后重试")
        }
    }

    /// 轻提示 2 秒后淡出；重复点击以最后一次为准（token 防串场）
    @MainActor
    private func showSaveToast(_ text: String) {
        saveToast = text
        let shown = text
        Task {
            try? await Task.sleep(for: .seconds(2))
            if saveToast == shown { saveToast = nil }
        }
    }

    private func varyAgain() async {
        busy = true
        defer { busy = false }
        do {
            let seed = Int.random(in: 1...2_147_483_647)
            // 再次变奏以源图还在为前提：凭内容哈希重签新 GET 票据（签名 ≤2h，对象 48h 内可反复重签）；
            // 源图已被生命周期清理时抛 sourceFileGone → 提示「不可变奏」，不降级纯文生图
            let refs = try await services.api.refreshReferences(record.referenceUrls)
            let urls = try await services.api.generate(
                prompt: record.prompt,
                imageUrls: refs,
                size: Self.apiSize(record.size),
                seed: seed,
                skillId: record.skillId
            )
            guard let first = urls.first, let url = URL(string: first) else {
                throw AppError.decoding
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            let resultRel = try ArtifactsStore.save(data: data, kind: .results)
            let thumb = try await ImageCompressor.compress(data: data, maxPixelSize: 480)
            let thumbRel = try ArtifactsStore.save(data: thumb.data, kind: .thumbs)

            let newRecord = VariationRecord(
                no: ComposingView.nextNo(context: modelContext),
                skillName: record.skillName,
                skillId: record.skillId,
                prompt: record.prompt,
                size: record.size,
                seed: seed,
                resultRelPath: resultRel,
                thumbRelPath: thumbRel,
                referenceUrls: refs
            )
            modelContext.insert(newRecord)
            services.quotaStore.consume()
            router.push(.result(newRecord))
        } catch {
            if case AppError.quotaExceeded = error {
                services.quotaStore.markExhausted()
            }
            errorMessage = error.localizedDescription
        }
    }
}
