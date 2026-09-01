//
//  SkillEditorView.swift
//  Variations
//
//  用户 SKILL.md 模版编辑器（设计稿 08）：名称 + 正文（frontmatter），本机存储，
//  编译时作为 inlineSkill 上传（body ≤100KB）。
//

import SwiftUI
import SwiftData

struct SkillEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// nil = 新建
    let template: UserSkillTemplate?

    @State private var name: String
    @State private var bodyText: String
    @State private var errorMessage: String?

    private static let maxBodyBytes = 100 * 1024

    private static let starterBody = """
    ---
    name: 手写笔记风
    description: 把照片变成手账里的手写笔记拼贴
    ---

    将照片转化为一页手账拼贴：保留主体人物与神态，背景替换为米色方格纸，\
    画面四角贴上半透明和纸胶带，留白处配一两句手写体中文短句，整体低饱和、暖调、纸张质感。
    """

    init(template: UserSkillTemplate? = nil) {
        self.template = template
        _name = State(initialValue: template?.name ?? "")
        _bodyText = State(initialValue: template?.body ?? Self.starterBody)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TextField("模版名称", text: $name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .cardBackground()

                TextEditor(text: $bodyText)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 380)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .fill(Theme.card)
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.textSecondary.opacity(0.2)))
                    )

                Spacer(minLength: 0)

                Text("模版仅存储在本机，生成变奏时自动上传")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle(template == nil ? "新建模版" : "编辑模版")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") { save() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .disabled(name.isEmpty)
            }
        }
        .alert("提示", isPresented: .constant(errorMessage != nil), actions: {
            Button("好") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard bodyText.data(using: .utf8)?.count ?? 0 <= Self.maxBodyBytes else {
            errorMessage = "模版内容超过 100KB 上限，请精简。"
            return
        }
        if let template {
            template.name = trimmedName
            template.body = bodyText
        } else {
            modelContext.insert(UserSkillTemplate(name: trimmedName, body: bodyText))
        }
        dismiss()
    }
}
