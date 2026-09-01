//
//  ComposingView.swift
//  Variations
//
//  谱写变奏（设计稿 04）：四音符五线谱谱写循环 + 齐跳收尾；生成成功落库并替换栈顶为结果舞台。
//

import SwiftUI
import SwiftData

struct ComposingView: View {
    @Environment(AppServices.self) private var services
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State var flow: FlowState
    @State private var variationNo = 0
    @State private var status = ""
    @State private var errorMessage: String?
    @State private var staffPhase: StaffPhase = .composing

    var body: some View {
        ComposingStageView(
            status: status,
            phase: staffPhase,
            errorMessage: errorMessage,
            onRetry: { Task { await run() } },
            onCancel: { dismiss() }
        )
        .background(Theme.background)
        // 设计稿无导航栏；「取消」承担返回
        .toolbar(.hidden, for: .navigationBar)
        .task {
            variationNo = Self.nextNo(context: modelContext)
            status = flow.editedPrompt.isEmpty
                ? "正在读懂你的照片…"
                : "第 \(variationNo) 号变奏排练中…"
            await run()
        }
    }

    // MARK: - 生成

    private func run() async {
        errorMessage = nil
        staffPhase = .composing
        do {
            if flow.editedPrompt.isEmpty {
                let prompt = try await flow.compile(services: services)
                flow.editedPrompt = prompt
                status = "第 \(variationNo) 号变奏排练中…"
            } else if !flow.referenceUrls.isEmpty {
                // 复用已编译提示词（含重试）：参考图签名 ≤2h 可能已过期，生成前凭内容哈希重签；
                // 源图已被 48h 生命周期清理时抛 sourceFileGone → 提示「不可变奏」
                flow.referenceUrls = try await services.api.refreshReferences(flow.referenceUrls)
            }
            let urls = try await services.api.generate(
                prompt: flow.editedPrompt,
                imageUrls: flow.referenceUrls,
                size: flow.size,
                skillId: flow.skillId
            )
            guard let first = urls.first, let url = URL(string: first) else {
                throw AppError.decoding
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            let resultRel = try ArtifactsStore.save(data: data, kind: .results)
            let thumb = try await ImageCompressor.compress(data: data, maxPixelSize: 480)
            let thumbRel = try ArtifactsStore.save(data: thumb.data, kind: .thumbs)

            let no = Self.nextNo(context: modelContext)
            let record = VariationRecord(
                no: no,
                skillName: flow.title,
                skillId: flow.skillId,
                prompt: flow.editedPrompt,
                size: flow.size ?? "", // 空串 = 自动（未指定画幅）
                resultRelPath: resultRel,
                thumbRelPath: thumbRel,
                referenceUrls: flow.referenceUrls
            )
            modelContext.insert(record)

            // 生图成功：本地递减今日额度
            services.quotaStore.consume()

            // 收尾齐跳：finale 播完再进结果舞台；期间被取消（返回/取消）则静默放弃导航
            staffPhase = .finale
            try await Task.sleep(for: .milliseconds(reduceMotion ? StaffMotion.finaleHoldReduced : StaffMotion.finaleHold))
            guard !Task.isCancelled else { return }
            router.replaceLast(.result(record))
        } catch is CancellationError {
            // 视图消失时取消，静默
        } catch {
            if case AppError.quotaExceeded = error {
                services.quotaStore.markExhausted()
            }
            errorMessage = error.localizedDescription
            staffPhase = .composing
        }
    }

    static func nextNo(context: ModelContext) -> Int {
        var descriptor = FetchDescriptor<VariationRecord>(sortBy: [SortDescriptor(\.no, order: .reverse)])
        descriptor.fetchLimit = 1
        let top = (try? context.fetch(descriptor))?.first
        return (top?.no ?? 0) + 1
    }
}

// MARK: - 舞台（纯展示，供快照测试复用）

/// 谱写变奏舞台：衬线斜体标题 + 五线谱谱写循环 + 状态文案 + 取消。
/// fixedBeat 非 nil 时五线谱定格（快照用）；entranceEnabled 关闭入场动画（快照确定性）。
struct ComposingStageView: View {
    let status: String
    let phase: StaffPhase
    var errorMessage: String? = nil
    var fixedBeat: Int? = nil
    var entranceEnabled = true
    var onRetry: () -> Void = {}
    var onCancel: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            if let errorMessage {
                VStack(spacing: 16) {
                    Text(errorMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button("重试", action: onRetry)
                        .foregroundStyle(Theme.primary)
                }
            } else {
                // 中心组：标题 → 五线谱 → 状态，间距 40（设计稿量取）
                VStack(spacing: 40) {
                    Text("谱写变奏…")
                        .font(Theme.Fonts.serifItalic(30))
                        .foregroundStyle(Theme.textPrimary)
                        .entrance(appeared: appeared, enabled: entranceEnabled, reduceMotion: reduceMotion, index: 0)

                    ComposingStaffView(phase: phase, fixedBeat: fixedBeat)
                        .entrance(appeared: appeared, enabled: entranceEnabled, reduceMotion: reduceMotion, index: 1)

                    Text(status)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .id(status)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: StaffMotion.statusFade), value: status)
                        .entrance(appeared: appeared, enabled: entranceEnabled, reduceMotion: reduceMotion, index: 2)
                }
            }
            Spacer()
            Button("取消", action: onCancel)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appeared = true }
    }
}

private extension View {
    /// 入场编排：淡入 + 上移（Reduce Motion 仅淡入），按 index 阶梯延迟；
    /// 位移用 transformEffect（渲染层），避免 offset 参与 VStack 布局引发布局跳动
    func entrance(appeared: Bool, enabled: Bool, reduceMotion: Bool, index: Int) -> some View {
        let shown = appeared || !enabled
        return self
            .opacity(shown ? 1 : 0)
            .transformEffect(.init(translationX: 0, y: shown || reduceMotion ? 0 : StaffMotion.entranceRise))
            .animation(
                .easeOut(duration: StaffMotion.entranceDuration).delay(Double(index) * StaffMotion.entranceStagger),
                value: appeared
            )
    }
}
