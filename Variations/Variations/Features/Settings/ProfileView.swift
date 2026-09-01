//
//  ProfileView.swift
//  Variations
//
//  「我的」页（设计稿 5.8）：身份票券卡（SIWA 双态 + 权益行三态）→ 设置分组下沉 → 版本页脚。
//  全页唯一朱色行动：「购买次数」。
//

import SwiftUI
import AuthenticationServices
import Nuke

struct ProfileView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.colorScheme) private var colorScheme

    /// 非 nil 时（iPhone compact）底部显示胶囊 TabBar
    var tabSelection: Binding<AppTab>? = nil

    @State private var showServer = false
    @State private var serverDraft = ""
    @State private var serverInvalid = false
    @State private var cacheBytes: Int64 = 0
    @State private var session: AccountSession?
    @State private var confirmDelete = false
    @State private var accountBusy = false
    @State private var accountNotice: String?
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("我的")
                    .font(Theme.Fonts.pageTitle)
                    .foregroundStyle(Theme.textPrimary)

                group {
                    if let session {
                        accountLoggedIn(session)
                    } else {
                        accountGuest
                    }
                }

                group {
                    if services.config.isDev {
                        row("服务器地址", value: services.settings.serverURLString.isEmpty ? "内置默认" : services.settings.serverURLString) {
                            serverDraft = services.settings.serverURLString
                            showServer = true
                        }
                        divider
                    }
                    row("外观", value: services.settings.appearance.rawValue) {
                        cycleAppearance()
                    }
                    divider
                    HStack {
                        Text("清除缓存").foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(Self.bytesLabel(cacheBytes))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                    .onTapGesture { clearCache() }
                }

                HStack {
                    Text("版本").foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("变奏 \(Self.version)")
                        .foregroundStyle(Theme.textSecondary)
                }
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.card))
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
        .task {
            cacheBytes = Self.totalCacheBytes()
            session = await services.accountAuth.currentSession()
            await services.quotaStore.refresh(api: services.api)
            #if DEBUG
            // 营销截图：直接拉起收银台（IAP 审核信息截屏用）
            if MarketingSeed.args.contains("-marketingPaywall") { showPaywall = true }
            #endif
        }
        .sheet(isPresented: $showServer) { serverSheet }
        .sheet(isPresented: $showPaywall) { PaywallSheet() }
        .alert("服务器地址需为 https，或本机 localhost/局域网调试地址", isPresented: $serverInvalid) {}
        .alert(accountNotice ?? "", isPresented: .constant(accountNotice != nil)) {
            Button("好") { accountNotice = nil }
        }
        .confirmationDialog(
            "注销账号？将删除账号、登录状态与云端用量记录；本机已保存的变奏图不受影响。此操作不可恢复。",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("注销账号", role: .destructive) { deleteAccount() }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 身份票券卡（设计稿 5.8）

    /// 未登录态：SIWA 按钮 + 权益叙事紧贴（转化路径最短）
    private var accountGuest: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("账号")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("登录享 7 日每日 10 次特权")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let data = credential.identityToken,
                          let identityToken = String(data: data, encoding: .utf8) else { return }
                    var fullName = ""
                    if let n = credential.fullName {
                        fullName = [n.givenName, n.familyName].compactMap { $0 }.joined(separator: " ")
                    }
                    exchangeLogin(identityToken: identityToken, fullName: fullName)
                case .failure:
                    break // 用户取消或系统失败：静默
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Text("游客 1 次体验 · 不登录也可使用")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
    }

    /// 已登录态：56pt 徽记 + 权益行三态 + 退出/注销
    private func accountLoggedIn(_ session: AccountSession) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                identityBadge(for: session)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name.isEmpty ? "变奏用户" : session.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(session.isPrivateEmail ? "已隐藏邮箱地址" : session.email)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("已登录，\(session.name.isEmpty ? "变奏用户" : session.name)")

            Divider()

            quotaLine

            Divider()

            Button { logout() } label: {
                Text("退出登录")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
            }
            .buttonStyle(.plain)

            Divider()

            Button { confirmDelete = true } label: {
                Text("注销账号")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
            }
            .buttonStyle(.plain)
        }
    }

    /// 身份徽记：56pt 圆 markSurface 底 + 朱色衬线首字符（设计稿 5.8）
    private func identityBadge(for session: AccountSession) -> some View {
        let initial = session.name.isEmpty
            ? "𝄞"
            : String(session.name.prefix(1))
        return Text(initial)
            .font(Font.system(size: 22, weight: .semibold, design: .serif))
            .foregroundStyle(Theme.primary)
            .frame(width: 56, height: 56)
            .background(Circle().fill(Theme.markSurface))
            .accessibilityHidden(true)
    }

    /// 权益行三态（设计稿 5.9）：游客体验 / 特权谱线 / 已购数字；右端「购买次数」唯一朱色行动（创作者模式隐藏）
    private var quotaLine: some View {
        let store = services.quotaStore
        return VStack(spacing: 8) {
            HStack {
                Text(store.quotaLabel)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(store.quotaValueText)
                    .font(.system(size: 12))
                    .foregroundStyle(store.exhausted ? Theme.primary : Theme.textSecondary)
                if store.showsPurchaseEntry {
                    Button { showPaywall = true } label: {
                        Text("购买次数")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            if store.showsTrack {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.staffLine).frame(height: 2)
                        Capsule().fill(Theme.primary)
                            .frame(width: proxy.size.width * store.trackFraction, height: 2)
                    }
                }
                .frame(height: 2)
                .accessibilityHidden(true)
            }
            if store.quota?.tier == "user" {
                // 已购总额常驻展示（永久余额），与每日特权额度并列
                HStack {
                    Text("已购次数")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(store.quota?.paid?.remaining ?? 0) 次 · 永久有效")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // contain：额度文案整体朗读，同时保留「购买次数」按钮的独立可操作性（ignore 会使其对 VoiceOver/UI 测试不可见）
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(store.quotaLabel)，\(store.quotaValueText)")
    }

    // MARK: - 组/行

    private func group(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.card))
    }

    private var divider: some View {
        Divider().padding(.horizontal, 14)
    }

    private func row(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(value)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary.opacity(0.6))
            }
            .font(.system(size: 15))
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sheets

    private var serverSheet: some View {
        VStack(spacing: 16) {
            Text("服务器地址（开发环境覆盖）")
                .font(.system(size: 16, weight: .semibold))
            TextField(AppConfiguration.devBaseURLString, text: $serverDraft)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            HStack {
                Button("取消") { showServer = false }
                Spacer()
                Button("保存") {
                    let trimmed = serverDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.isEmpty || ServerURLValidator.isValid(trimmed) else {
                        serverInvalid = true
                        return
                    }
                    services.settings.serverURLString = trimmed
                    showServer = false
                }
            }
            Text("留空使用内置默认 \(AppConfiguration.devBaseURLString)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(20)
        .presentationDetents([.height(260)])
        .presentationBackground(Theme.surface)
    }

    // MARK: - 动作

    /// 系统 SIWA 面板凭据 → POST /api/auth/apple 换发会话令牌
    private func exchangeLogin(identityToken: String, fullName: String) {
        guard !accountBusy else { return }
        accountBusy = true
        Task {
            defer { accountBusy = false }
            do {
                let reply = try await services.api.loginWithApple(identityToken: identityToken, fullName: fullName)
                session = reply.user
                services.quotaStore.apply(reply.quota)
            } catch let error as AppError {
                accountNotice = error.errorDescription
            } catch {
                accountNotice = error.localizedDescription
            }
        }
    }

    private func logout() {
        Task {
            do {
                try await services.api.logout()
            } catch {
                // 服务端不可达也本地清会话（降级游客）
                await services.accountAuth.clearSession()
            }
            session = nil
            await services.quotaStore.refresh(api: services.api)
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await services.api.deleteAccount()
                session = nil
                await services.quotaStore.refresh(api: services.api)
            } catch let error as AppError {
                accountNotice = error.errorDescription
            } catch {
                accountNotice = error.localizedDescription
            }
        }
    }

    private func cycleAppearance() {
        let all = Appearance.allCases
        let index = all.firstIndex(of: services.settings.appearance) ?? 0
        services.settings.appearance = all[(index + 1) % all.count]
    }

    /// 仅清 Nuke 图片缓存；ArtifactsStore 是用户产物（变奏集图片），不是缓存，绝不在此删除
    private func clearCache() {
        ImagePipelineBootstrap.clearDiskCache()
        cacheBytes = Self.totalCacheBytes()
    }

    // MARK: - 工具

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// 缓存占用（仅 Nuke 图片磁盘缓存，与 clearCache 的清除范围一致）
    static func totalCacheBytes() -> Int64 {
        var total: Int64 = 0
        let nukeDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(ImagePipelineBootstrap.dataCacheName, isDirectory: true)
        if let enumerator = FileManager.default.enumerator(at: nukeDir, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) {
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                total += Int64(values?.totalFileAllocatedSize ?? 0)
            }
        }
        return total
    }

    static func bytesLabel(_ bytes: Int64) -> String {
        bytes < 1024 * 1024 ? "\(bytes / 1024) KB" : String(format: "%.0f MB", Double(bytes) / 1024 / 1024)
    }
}
