//
//  ResultView.swift
//  Variations
//
//  结果舞台（设计稿 05）：衬线斜体标题 + 大图 + 下载/分享/再变奏一次 + AI 标识。
//

import SwiftUI
import SwiftData

struct ResultView: View {
    @Environment(AppServices.self) private var services
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var modelContext

    let record: VariationRecord

    @State private var busy = false
    @State private var errorMessage: String?

    private var label: String { "Variation No.\(record.no)" }

    private var resultImage: UIImage? {
        guard let rel = record.resultRelPath else { return nil }
        return UIImage(contentsOfFile: ArtifactsStore.url(relative: rel).path)
    }

    private var watermarked: UIImage? {
        resultImage.map { Watermark.burn($0, label: label) }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(label)
                .font(Theme.Fonts.serifItalic(26))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 12)

            stage

            controls

            Text("由 AI 生成 · 变奏 Variations")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
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
            } else {
                ImagePlaceholder(label: "图片文件已丢失", icon: "exclamationmark.triangle")
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

            PrimaryButton(title: "再变奏一次", enabled: !busy && !services.quotaStore.exhausted) {
                Task { await varyAgain() }
            }
            if services.quotaStore.exhausted {
                Text(services.quotaStore.exhaustedHint)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
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
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
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
