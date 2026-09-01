//
//  StaffProgressView.swift
//  Variations
//
//  五线谱谱写动效（设计稿 04）：音符三态（未谱写/跳跃中/已谱写），
//  6 拍一循环（4 拍谱写 → 齐亮停顿 → 淡出重置），成功收尾四音符齐跳。
//

import SwiftUI

// MARK: - 状态

/// 音符状态：颜色/符尾/位移均为其纯函数
nonisolated enum NotePhase: Equatable {
    case pending   // 未谱写（灰）
    case jumping   // 跳跃中（朱红八分音符）
    case composed  // 已谱写（主文色四分音符）
}

/// 五线谱整体阶段：谱写循环 / 收尾齐跳
nonisolated enum StaffPhase: Equatable {
    case composing
    case finale
}

// MARK: - 动效与布局常量

nonisolated enum StaffMotion {
    /// 拍长（≈107 BPM）
    static let beatDuration: Double = 0.56
    /// 一循环拍数：0-3 谱写，4 齐亮停顿，5 淡出重置
    static let beatsPerCycle = 6
    static let noteCount = 4

    /// 跳跃幅度（设计稿定格：跳跃音符顶到容器上缘，13pt）
    static let jumpAmplitude: CGFloat = 13
    static let riseDuration: Double = 0.22
    static let landSpring = Animation.spring(response: 0.30, dampingFraction: 0.55)
    /// 落地弹簧的视觉稳定耗时（触发挤压的时机）
    static let landSettle: Double = 0.26
    static let squashScale: CGFloat = 0.86
    static let squashSpring = Animation.spring(response: 0.18, dampingFraction: 0.5)

    /// 落地变色（jumping→composed）
    static let landColorFade: Double = 0.15
    /// 整轮重置（composed→pending）
    static let resetFade: Double = 0.3
    static let flagFade: Double = 0.10
    static let statusFade: Double = 0.25

    static let entranceDuration: Double = 0.35
    static let entranceStagger: Double = 0.08
    static let entranceRise: CGFloat = 8

    /// 收尾齐跳时长（毫秒）；Reduce Motion 仅变色
    static let finaleHold = 550
    static let finaleHoldReduced = 300

    // 布局（设计稿容器 220×72，clipsContent）
    static let staffWidth: CGFloat = 220
    static let staffHeight: CGFloat = 72
    /// 3 条谱线 y
    static let lineYs: [CGFloat] = [42, 54, 66]
    /// 4 个音符左缘 x（间距 56）
    static let noteXs: [CGFloat] = [24, 80, 136, 192]
    /// 音符休止音高 y：符头依次落在谱线 3/2/1/2（拱形旋律线）
    static let noteRestYs: [CGFloat] = [37, 25, 13, 25]
}

// MARK: - 指挥（纯函数，可单测）

nonisolated enum StaffConductor {
    /// beat 拍时第 index 个音符的状态；beat 取模循环，负数安全
    static func phase(beat: Int, index: Int) -> NotePhase {
        let cycle = StaffMotion.beatsPerCycle
        let b = ((beat % cycle) + cycle) % cycle
        if b >= StaffMotion.noteCount {
            // 拍 4 齐亮停顿（保持已谱写）；拍 5 淡出重置（全部未谱写）
            return b == StaffMotion.noteCount ? .composed : .pending
        }
        if index < b { return .composed }
        return index == b ? .jumping : .pending
    }
}

// MARK: - 字形

/// 四分音符（符头+符杆）：按设计稿导出 SVG 换算，设计盒 18×34（glyph 占左 16pt）
struct NoteShape: Shape {
    func path(in rect: CGRect) -> Path {
        // 符头：椭圆 rx5.5 ry4.2，圆心 (6, 29)，旋转 -18°
        var path = Path(ellipseIn: CGRect(x: -5.5, y: -4.2, width: 11, height: 8.4))
            .applying(CGAffineTransform(rotationAngle: -.pi / 10))
            .applying(CGAffineTransform(translationX: 6, y: 29))
        // 符杆：圆角矩形 (10.2, 4) 1.8×25.5 r0.9
        path.addPath(Path(roundedRect: CGRect(x: 10.2, y: 4, width: 1.8, height: 25.5), cornerRadius: 0.9))
        return path.applying(Self.scale(to: rect))
    }

    static func scale(to rect: CGRect) -> CGAffineTransform {
        CGAffineTransform(scaleX: rect.width / 18, y: rect.height / 34)
    }
}

/// 八分音符符尾（仅跳跃中显示，独立透明度动画避免形状闪变）：设计盒同 NoteShape
struct NoteFlagShape: Shape {
    func path(in rect: CGRect) -> Path {
        var flag = Path()
        flag.move(to: CGPoint(x: 12, y: 4.5))
        flag.addCurve(to: CGPoint(x: 16.8, y: 12.3), control1: CGPoint(x: 15.2, y: 5.9), control2: CGPoint(x: 17, y: 8.5))
        flag.addCurve(to: CGPoint(x: 12, y: 6.1), control1: CGPoint(x: 14.2, y: 10.1), control2: CGPoint(x: 12.2, y: 8.4))
        flag.closeSubpath()
        return flag.applying(NoteShape.scale(to: rect))
    }
}

// MARK: - 五线谱谱写视图

struct ComposingStaffView: View {
    let phase: StaffPhase
    /// 固定拍（预览/快照）：非 nil 时停用时间轴，音符呈静态姿势
    var fixedBeat: Int? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()
    @State private var frozenBeat: Int?

    var body: some View {
        Group {
            if let fixedBeat {
                staff(beat: fixedBeat, staticPose: true)
            } else {
                TimelineView(.periodic(from: startDate, by: StaffMotion.beatDuration)) { context in
                    let liveBeat = frozenBeat ?? Int(context.date.timeIntervalSince(startDate) / StaffMotion.beatDuration)
                    staff(beat: liveBeat, staticPose: false)
                        .onChange(of: phase) { _, new in
                            switch new {
                            // 齐跳时冻结循环拍，音符状态改由 finale 统一驱动
                            case .finale: frozenBeat = liveBeat
                            case .composing: frozenBeat = nil
                            }
                        }
                }
            }
        }
        .frame(width: StaffMotion.staffWidth, height: StaffMotion.staffHeight)
        .clipped()
        .accessibilityHidden(true)
    }

    /// 谱线用 VStack+padding 定位、音符用 overlay+HStack+padding 定位，
    /// 跳跃位移走 transformEffect（渲染层变换）：全程不用 .offset 布局，
    /// 避免 iOS 17+ 起 offset 参与容器尺寸计算带来的定位不确定性
    private func staff(beat: Int, staticPose: Bool) -> some View {
        VStack(spacing: 11) {
            ForEach(0..<StaffMotion.lineYs.count, id: \.self) { _ in
                Rectangle()
                    .fill(Theme.staffLine)
                    .frame(width: StaffMotion.staffWidth, height: 1)
            }
        }
        .padding(.top, StaffMotion.lineYs[0])
        .frame(width: StaffMotion.staffWidth, height: StaffMotion.staffHeight, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            HStack(alignment: .top, spacing: 38) {
                ForEach(0..<StaffMotion.noteCount, id: \.self) { index in
                    NoteView(
                        phase: phase == .finale ? .jumping : StaffConductor.phase(beat: beat, index: index),
                        isFinale: phase == .finale,
                        reduceMotion: reduceMotion,
                        staticPose: staticPose
                    )
                    .padding(.top, StaffMotion.noteRestYs[index])
                    .padding(.leading, index == 0 ? StaffMotion.noteXs[0] : 0)
                }
            }
        }
    }
}

// MARK: - 单个音符

private struct NoteView: View {
    let phase: NotePhase
    let isFinale: Bool
    let reduceMotion: Bool
    let staticPose: Bool

    @State private var lift: CGFloat = 0
    @State private var squash: CGFloat = 1
    @State private var displayedColor: Color = Theme.notePending
    @State private var flagVisible = false

    var body: some View {
        NoteShape()
            .fill(displayedColor)
            .overlay {
                NoteFlagShape()
                    .fill(displayedColor)
                    .opacity(flagVisible ? 1 : 0)
            }
            .frame(width: 18, height: 34)
            .scaleEffect(x: 1, y: squash, anchor: .bottom)
            .transformEffect(CGAffineTransform(translationX: 0, y: lift))
            .onAppear { apply(phase, from: nil, animated: false) }
            .onChange(of: phase) { old, new in apply(new, from: old, animated: true) }
            .onChange(of: isFinale) { _, new in
                if new { jump() }
            }
    }

    /// 颜色与符尾过渡：落地变色 0.15s；整轮重置（composed→pending）0.3s
    private func apply(_ new: NotePhase, from old: NotePhase?, animated: Bool) {
        let color: Color = switch new {
        case .pending: Theme.notePending
        case .jumping: Theme.primary
        case .composed: Theme.textPrimary
        }
        let fade = (old == .composed && new == .pending) ? StaffMotion.resetFade : StaffMotion.landColorFade
        withAnimation(animated ? .easeInOut(duration: fade) : nil) {
            displayedColor = color
        }
        withAnimation(animated ? .easeOut(duration: StaffMotion.flagFade) : nil) {
            flagVisible = new == .jumping
        }
        if new == .jumping {
            if staticPose {
                // 静态姿势：定格在跳跃顶点（对齐设计稿快照）
                lift = -StaffMotion.jumpAmplitude
            } else if animated {
                jump()
            }
        }
    }

    /// 跳跃：上升 0.22s → 弹簧落地 → 触谱挤压回弹；Reduce Motion 只保留颜色高亮
    private func jump() {
        guard !reduceMotion, !staticPose else { return }
        withAnimation(.easeOut(duration: StaffMotion.riseDuration)) {
            lift = -StaffMotion.jumpAmplitude
        }
        withAnimation(StaffMotion.landSpring.delay(StaffMotion.riseDuration)) {
            lift = 0
        }
        let landAt = StaffMotion.riseDuration + StaffMotion.landSettle
        withAnimation(.easeIn(duration: 0.06).delay(landAt)) {
            squash = StaffMotion.squashScale
        }
        withAnimation(StaffMotion.squashSpring.delay(landAt + 0.06)) {
            squash = 1
        }
    }
}

// MARK: - 预览

#Preview("谱写循环 · 固定拍") {
    VStack(spacing: 16) {
        ForEach(0..<StaffMotion.beatsPerCycle, id: \.self) { beat in
            ComposingStaffView(phase: .composing, fixedBeat: beat)
        }
        ComposingStaffView(phase: .finale, fixedBeat: 0)
    }
    .padding()
    .background(Theme.background)
}

#Preview("谱写循环 · 夜谱") {
    ComposingStaffView(phase: .composing, fixedBeat: 2)
        .padding()
        .background(Theme.background)
        .environment(\.colorScheme, .dark)
}
