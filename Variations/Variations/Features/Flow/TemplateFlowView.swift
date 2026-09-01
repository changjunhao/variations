//
//  TemplateFlowView.swift
//  Variations
//
//  模版流程（设计稿 02）：1 选图 → 2 编译 → 3 编辑；压缩→直传 OSS（进度/已上传态）。
//

import SwiftUI
import PhotosUI

struct TemplateFlowView: View {
    @Environment(AppServices.self) private var services
    @Environment(Router.self) private var router
    @State var flow: FlowState
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 官方模版完整简介（首页卡片单行截断，此处不限行完整展示）
                if let desc = skillDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                pickCard
                instructionSection
                Text("AI 会根据你的照片与附加指令生成风格变奏")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
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
                PrimaryButton(title: "开始变奏", enabled: flow.isUploaded && !services.quotaStore.exhausted) {
                    // 立即进入过渡动画；编译在 ComposingView 内完成
                    router.push(.composing(flow))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.background)
        }
        .navigationTitle(flow.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItem) { _, item in
            Task { await flow.handlePicked(item, services: services) }
        }
    }

    // MARK: - 选图卡

    private var pickCard: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Group {
                    if let image = flow.previewImage {
                        // 完整展示原比例，不裁剪
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                    } else {
                        ImagePlaceholder(label: "点击选择照片", icon: "photo.badge.plus")
                            .frame(maxWidth: .infinity)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                    }
                }
            }

            statusRow
        }
        .padding(10)
        .cardBackground()
    }

    @ViewBuilder
    private var statusRow: some View {
        switch flow.stage {
        case .pick:
            Text("选择一张照片开始")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        case .compressing:
            Label("压缩中…", systemImage: "arrow.down.circle")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        case .uploading(let fraction):
            HStack(spacing: 8) {
                ProgressView(value: fraction)
                Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit()
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.textSecondary)
        case .uploaded:
            let bytes = flow.compressedData?.count ?? 0
            Label("已上传云端 · \(flow.fileName) · \(Self.megabytes(bytes))", systemImage: "checkmark")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        case .failed(let message):
            VStack(spacing: 6) {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.primary)
                Button("重试") { Task { await flow.startUpload(services: services) } }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.primary)
            }
        }
    }

    // MARK: - 附加指令

    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("附加指令（可选）")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            if let template = instructionTemplate, !template.isEmpty {
                structuredFields(template)
            } else {
                freeEditor
            }
        }
    }

    /// 官方模版的结构化附加指令模板；用户模版无模板，回退自由文本
    private var instructionTemplate: [InstructionField]? {
        if case .official(let card) = flow.kind { return card.instructionTemplate }
        return nil
    }

    /// 官方模版的完整简介；用户模版/直接输入无简介
    private var skillDescription: String? {
        if case .official(let card) = flow.kind { return card.shortDescription }
        return nil
    }

    // MARK: 结构化模板（标签行：枚举值域单选胶囊 / 自由文本输入）

    private func structuredFields(_ template: [InstructionField]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(template, id: \.label) { field in
                VStack(alignment: .leading, spacing: 8) {
                    Text(field.label)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    if let options = field.options {
                        optionCapsules(field: field, options: options)
                    } else {
                        freeField(field)
                    }
                }
            }
        }
    }

    /// 枚举标签：自动（缺省，不下发该标签）+ 值域单选胶囊
    private func optionCapsules(field: InstructionField, options: [String]) -> some View {
        HStack(spacing: 8) {
            optionCapsule(field: field, title: "自动", value: nil)
            ForEach(options, id: \.self) { option in
                optionCapsule(field: field, title: option, value: option)
            }
        }
    }

    private func optionCapsule(field: InstructionField, title: String, value: String?) -> some View {
        let selected = (flow.instructionValues[field.label] ?? "") == (value ?? "")
        return Button {
            flow.instructionValues[field.label] = value
        } label: {
            Text(title)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.onPrimary : Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selected ? Theme.primary : Theme.card)
                        .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.textSecondary.opacity(0.25)))
                )
        }
        .buttonStyle(.plain)
    }

    /// 自由文本标签
    private func freeField(_ field: InstructionField) -> some View {
        TextField(field.placeholder ?? "", text: Binding(
            get: { flow.instructionValues[field.label] ?? "" },
            set: { flow.instructionValues[field.label] = $0 }
        ))
        .font(.system(size: 14))
        .foregroundStyle(Theme.textPrimary)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.background)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.textSecondary.opacity(0.25)))
        )
    }

    // MARK: 自由文本（用户模版等无结构化模板时）

    private var freeEditor: some View {
        TextEditor(text: $flow.instruction)
            .font(.system(size: 14))
            .foregroundStyle(Theme.textPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 96)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Theme.background)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.textSecondary.opacity(0.25)))
            )
            .overlay(alignment: .topLeading) {
                if flow.instruction.isEmpty {
                    Text("告诉 AI 想要的氛围、光线或构图…")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))
                        .padding(.top, 18)
                        .padding(.leading, 15)
                        .allowsHitTesting(false)
                }
            }
    }

    private static func megabytes(_ bytes: Int) -> String {
        String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
    }
}
