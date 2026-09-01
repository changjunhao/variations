//
//  CollectionView.swift
//  Variations
//
//  变奏集（设计稿 06）：共 N 号变奏 + 双列缩略图 + No.X 标签 + 占位卡。
//

import SwiftUI
import SwiftData

struct CollectionView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VariationRecord.no, order: .reverse) private var records: [VariationRecord]

    /// 待确认删除的记录（长按菜单触发）
    @State private var pendingDelete: VariationRecord?

    /// 非 nil 时（iPhone compact）底部显示胶囊 TabBar
    var tabSelection: Binding<AppTab>? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("变奏集")
                        .font(Theme.Fonts.pageTitle)
                        .foregroundStyle(Theme.textPrimary)
                    Text("共 \(records.count) 号变奏")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(records) { record in
                        Button {
                            router.push(.result(record))
                        } label: {
                            recordCard(record)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                pendingDelete = record
                            } label: {
                                Label("删除变奏", systemImage: "trash")
                            }
                        }
                        // 挂在卡片上：iPad 确认气泡指向被删卡片；挂整页会丢失锚点漂移
                        .confirmationDialog(
                            "删除这号变奏？",
                            isPresented: Binding(
                                get: { pendingDelete === record },
                                set: { if !$0 { pendingDelete = nil } }
                            ),
                            titleVisibility: .visible
                        ) {
                            Button("删除", role: .destructive) {
                                VariationRecord.delete(record, in: modelContext)
                                pendingDelete = nil
                            }
                            Button("取消", role: .cancel) { pendingDelete = nil }
                        } message: {
                            Text("No.\(record.no) 的结果图与缩略图将一并删除，不可恢复。")
                        }
                    }
                    nextPlaceholder
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            if let tabSelection {
                CapsuleTabBar(selection: tabSelection)
            }
        }
    }

    private func recordCard(_ record: VariationRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Color.clear 先占满“列宽×150”锁定格子尺寸，任何原图比例都不会撞破格子；
            // overlay 内 scaledToFit 完整展示整幅作品
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .overlay {
                    if let rel = record.thumbRelPath, let image = UIImage(contentsOfFile: ArtifactsStore.url(relative: rel).path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        ImagePlaceholder(label: " ")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

            Text("No.\(record.no)")
                .font(Theme.Fonts.serifItalic(13))
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))

            Text("\(record.skillName) · \(Self.dateLabel(record.createdAt))")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
    }

    private var nextPlaceholder: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.textSecondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5]))
                .frame(height: 150)
                .overlay(
                    Text("下一号变奏")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                )
            Text("No.\((records.first?.no ?? 0) + 1)?")
                .font(Theme.Fonts.serifItalic(13))
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
        }
    }

    static func dateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(.dateTime.hour().minute())
        if calendar.isDateInToday(date) { return "今天 \(time)" }
        if calendar.isDateInYesterday(date) { return "昨天 \(time)" }
        return date.formatted(.dateTime.month(.defaultDigits).day())
    }
}
