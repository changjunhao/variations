//
//  DirectPromptView.swift
//  Variations
//
//  直接输入（设计稿 09）：提示词 + 载入提示词模版 + 附图≤3（无图=文生图）。
//  附图压缩后直传 OSS，生成时以 bucket 签名 URL 作参考图。
//

import SwiftUI
import SwiftData
import PhotosUI
import CryptoKit

struct DirectPromptView: View {
    @Environment(AppServices.self) private var services
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PromptPreset.createdAt, order: .reverse) private var presets: [PromptPreset]

    @State private var flow = FlowState(kind: .direct)
    @State private var text = ""
    @State private var sizeSelection: SizeOption? // nil = 自动（不传 size）
    @State private var showPresets = false
    @State private var showSavePreset = false
    @State private var presetName = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var attachments: [Attachment] = []
    @State private var errorMessage: String?

    struct Attachment: Identifiable {
        let id = UUID()
        let image: UIImage
        var url: String?
        var failed = false
    }

    private var isBusy: Bool { attachments.contains { $0.url == nil && !$0.failed } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                promptSection
                HStack(spacing: 12) {
                    SecondaryButton(title: "载入提示词模版", icon: "bookmark") {
                        showPresets = true
                    }
                    SecondaryButton(title: "存为提示词模版", icon: "square.and.arrow.down") {
                        presetName = ""
                        showSavePreset = true
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                }
                attachmentSection
                sizeSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if services.quotaStore.exhausted {
                    Text(services.quotaStore.exhaustedHint)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                PrimaryButton(title: "开始变奏", enabled: !text.isEmpty && !isBusy && !services.quotaStore.exhausted) {
                    start()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.background)
        }
        .navigationTitle("直接输入")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPresets) { presetSheet }
        .sheet(isPresented: $showSavePreset) { savePresetSheet }
        .onChange(of: pickerItems) { _, items in
            Task { await ingest(items) }
        }
        .alert("提示", isPresented: .constant(errorMessage != nil), actions: {
            Button("好") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    // MARK: - 提示词

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("提示词")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            TextEditor(text: $text)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 220)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .fill(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.textSecondary.opacity(0.2)))
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("写下你想要的画面：主题、风格、光线、氛围…")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary.opacity(0.7))
                            .padding(.top, 18)
                            .padding(.leading, 15)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - 附图

    private var attachmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("附图（可选，无图时为文生图）")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 12) {
                ForEach(attachments) { attachment in
                    Image(uiImage: attachment.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            if attachment.url == nil && !attachment.failed {
                                ProgressView().controlSize(.small)
                            }
                        }
                }
                if attachments.count < 3 {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 3 - attachments.count, matching: .images) {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Theme.textSecondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .frame(width: 64, height: 64)
                            .overlay(Image(systemName: "plus").foregroundStyle(Theme.textSecondary))
                    }
                }
            }
        }
    }

    // MARK: - 画幅（自动 / 三档胶囊，默认自动）

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("画幅")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 8) {
                sizeCapsule(title: "自动", isSelected: sizeSelection == nil) {
                    sizeSelection = nil
                }
                ForEach(SizeOption.allCases, id: \.self) { option in
                    sizeCapsule(title: option.rawValue, isSelected: sizeSelection == option) {
                        sizeSelection = option
                    }
                }
            }
        }
    }

    private func sizeCapsule(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Theme.onPrimary : Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Theme.primary : Theme.card)
                        .overlay(
                            Capsule().strokeBorder(
                                isSelected ? Color.clear : Theme.textSecondary.opacity(0.25)
                            )
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 模版选择

    private var presetSheet: some View {
        NavigationStack {
            List {
                ForEach(presets) { preset in
                    Button {
                        text = preset.prompt
                        showPresets = false
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name).foregroundStyle(Theme.textPrimary)
                            Text(preset.prompt)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }
                if presets.isEmpty {
                    Text("暂无提示词模版")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("载入提示词模版")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 存为模版

    private var savePresetSheet: some View {
        VStack(spacing: 16) {
            Text("存为提示词模版")
                .font(.system(size: 16, weight: .semibold))
            TextField("模版名称", text: $presetName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { showSavePreset = false }
                Spacer()
                Button("保存") {
                    let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    modelContext.insert(PromptPreset(name: name, prompt: text))
                    showSavePreset = false
                }
                .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .presentationDetents([.height(220)])
        .presentationBackground(Theme.surface)
    }

    // MARK: - 动作

    private func ingest(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let output = try? await ImageCompressor.compress(data: data),
                  let image = UIImage(data: output.data)
            else {
                errorMessage = "图片无法读取，请换一张试试。"
                continue
            }
            let attachment = Attachment(image: image)
            attachments.append(attachment)
            let id = attachment.id
            do {
                // 内容寻址：对最终上传字节算 SHA-256，服务端生成 uploads/{hash}.jpg 对象键
                let hash = SHA256.hash(data: output.data).map { String(format: "%02x", $0) }.joined()
                let ticket = try await services.api.uploadTicket(hash: hash)
                let final = try await OSSUploader.upload(
                    jpeg: output.data,
                    ticket: ticket,
                    progress: { _ in },
                    refetchTicket: { try await services.api.uploadTicket(hash: hash) }
                )
                if let index = attachments.firstIndex(where: { $0.id == id }) {
                    attachments[index].url = final.fileUrl
                }
            } catch {
                if let index = attachments.firstIndex(where: { $0.id == id }) {
                    attachments[index].failed = true
                }
            }
        }
        pickerItems = []
    }

    private func start() {
        let urls = attachments.compactMap(\.url)
        if urls.count != attachments.filter({ !$0.failed }).count { return }
        flow.editedPrompt = String(text.prefix(16000))
        flow.referenceUrls = urls
        flow.size = sizeSelection?.apiValue // 未选 = 自动，不传 size
        router.push(.composing(flow))
    }
}
