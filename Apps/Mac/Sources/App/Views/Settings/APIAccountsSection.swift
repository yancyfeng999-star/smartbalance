import SwiftUI
import Domain
import Infrastructure

/// 两层嵌套：外层「API 账号」→ 内层按平台折叠卡 → 点开添加/编辑密钥。
struct APIAccountsSection: View {
    @ObservedObject var model: AppModel
    var embedded: Bool = false

    /// 当前展开的内层卡：平台 kind 或 "add"
    @State private var expandedKey: String? = nil
    @State private var draftName = ""
    @State private var draftBaseURL = ""
    @State private var draftConsoleURL = ""
    @State private var draftUserId = ""
    @State private var draftAccessKey = ""
    @State private var draftSecret = ""
    @State private var draftManualAmount = ""
    @State private var editAccountId: UUID?
    @State private var editField = ""
    @State private var editUserId = ""
    @State private var editAccessKey = ""
    @State private var editConsoleURL = ""

    var body: some View {
        Group {
            if embedded {
                nestedList
            } else {
                SettingsChrome.card(title: "API 账号") { nestedList }
            }
        }
    }

    private var nestedList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("点平台卡片展开；浏览器渠道登录后点击连接，无需复制 Cookie")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(ProviderKind.selectableCases) { kind in
                platformCard(kind)
            }
        }
    }

    // MARK: - Level-2 platform card

    private func platformCard(_ kind: ProviderKind) -> some View {
        let accounts = model.settings.accounts.filter { $0.kind == kind }
        let key = kind.rawValue
        let expanded = Binding(
            get: { expandedKey == key },
            set: { on in
                withAnimation(AppMotion.expand) {
                    expandedKey = on ? key : (expandedKey == key ? nil : expandedKey)
                    if on {
                        resetDraft(for: kind)
                        editAccountId = nil
                        editField = ""
                    }
                }
            }
        )

        return NestedSettingsCard(
            icon: iconName(for: kind),
            iconColors: iconColors(for: kind),
            providerKind: kind,
            title: kind.displayName,
            subtitle: platformSubtitle(kind: kind, accounts: accounts),
            badge: accounts.isEmpty ? nil : "\(accounts.count)",
            badgeColor: accounts.contains(where: { missingCredential($0) }) ? SBTheme.warn : SBTheme.ok,
            isExpanded: expanded
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if accounts.isEmpty {
                    Text(kind.isManualEntry ? "尚未添加 · 展开下方表单手录余额" : (kind.supportsBrowserSessionImport ? "尚未添加 · 从浏览器导入或手动保存" : "尚未添加 · 粘贴密钥后保存"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SBTheme.muted)
                } else {
                    ForEach(accounts) { acc in
                        existingAccountBlock(acc)
                    }
                }

                Divider().overlay(SBTheme.stroke)

                addForm(for: kind)
            }
        }
    }

    private func platformSubtitle(kind: ProviderKind, accounts: [BalanceAccount]) -> String {
        if accounts.isEmpty {
            return kind.isManualEntry ? "手录 · 每日提醒" : kind.credentialHintCN
        }
        let missing = accounts.filter { missingCredential($0) }.count
        if missing > 0 {
            return "已添加 \(accounts.count) · \(missing) 个待补"
        }
        return "已添加 \(accounts.count) 个"
    }

    private func missingCredential(_ acc: BalanceAccount) -> Bool {
        if acc.kind.isManualEntry {
            return acc.manualAmount == nil
        }
        return model.maskedSecret(for: acc) == nil && !model.hasSecret(for: acc)
    }

    // MARK: - Existing account row (edit key)

    private func existingAccountBlock(_ acc: BalanceAccount) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(acc.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SBTheme.text)
                    Text(accountStatusLine(acc))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(missingCredential(acc) ? SBTheme.warn : SBTheme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Toggle("", isOn: Binding(
                    get: { acc.enabled },
                    set: { model.toggleAccount(acc.id, enabled: $0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.85)

                Button {
                    model.openDashboard(for: acc)
                } label: {
                    Image(systemName: "safari")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SBTheme.accent)
                }
                .buttonStyle(.plain)
                .help("打开官网/后台")
                .disabled(acc.resolvedConsoleURL == nil)

                Button {
                    withAnimation(AppMotion.expand) {
                        if editAccountId == acc.id {
                            editAccountId = nil
                            editField = ""
                            editUserId = ""
                            editAccessKey = ""
                            editConsoleURL = ""
                        } else {
                            editAccountId = acc.id
                            editUserId = acc.userId ?? ""
                            editConsoleURL = acc.consoleURL ?? acc.kind.defaultConsoleURL ?? ""
                            if acc.kind.isManualEntry, let a = acc.manualAmount {
                                editField = String(format: "%g", a)
                            } else {
                                editField = ""
                            }
                            editAccessKey = ""
                        }
                    }
                } label: {
                    Image(systemName: acc.kind.isManualEntry ? "pencil.circle.fill" : "key.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SBTheme.accent)
                }
                .buttonStyle(.plain)
                .help(acc.kind.isManualEntry ? "录入余额" : "更新密钥 / 官网")

                Button(role: .destructive) {
                    model.removeAccount(acc.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SBTheme.danger)
                }
                .buttonStyle(.plain)
            }

            if editAccountId == acc.id {
                editEditor(for: acc)
                    .transition(AppMotion.expandContent)
            }
            if acc.kind.supportsBrowserSessionImport {
                HStack(spacing: 10) {
                    Button("打开官网登录") { model.openBrowserLogin(for: acc.kind) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SBTheme.accent)
                        .accessibilityIdentifier("browser.login.\(acc.id.uuidString)")
                        .disabled(model.browserImporting)
                    Button(browserImportButtonTitle(for: acc.kind, existing: true)) {
                        Task {
                            await model.importBrowserSession(intoAccountId: acc.id)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SBTheme.accent)
                    .accessibilityIdentifier("browser.reimport.\(acc.id.uuidString)")
                    .disabled(model.browserImporting)
                    .padding(.top, 2)
                }
                browserImportFeedback(for: acc.kind)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SBTheme.panel.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(SBTheme.stroke, lineWidth: 1)
                )
        )
    }

    private func accountStatusLine(_ acc: BalanceAccount) -> String {
        if model.snapshots.contains(where: { $0.accountId == acc.id && $0.connectionIssue == .loginRequired }) {
            return "登录已失效 · 重新连接后恢复刷新"
        }
        if acc.kind.supportsBrowserSessionImport, missingCredential(acc) {
            return "尚未连接 · 点击重新连接自动获取登录态"
        }
        if acc.kind.isManualEntry {
            if let amt = acc.manualAmount {
                let when = acc.manualUpdatedAt.map { Self.shortDate.string(from: $0) } ?? "—"
                return "手录 \(acc.resolvedManualUnit)\(String(format: "%.2f", amt)) · \(when)"
            }
            return "尚未录入金额"
        }
        if let mask = model.maskedSecret(for: acc) {
            if acc.kind.needsUserId {
                if let uid = acc.userId, !uid.isEmpty {
                    return mask + " · UID \(uid)"
                }
                return mask + " · 缺用户 ID"
            }
            return mask
        }
        if acc.kind.needsUserId, (acc.userId ?? "").isEmpty {
            return "缺密钥 / 用户 ID · 点钥匙补全"
        }
        return "缺密钥 · 点钥匙添加"
    }

    private func editEditor(for acc: BalanceAccount) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("官网 / 后台链接（打开后台时跳转）")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SBTheme.muted)
            TextField("https://…", text: $editConsoleURL)
                .textFieldStyle(.roundedBorder)

            if acc.kind.isManualEntry {
                Text("对照网页录入余额")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                TextField("金额，如 128.50", text: $editField)
                    .textFieldStyle(.roundedBorder)
                Toggle("每天 10:00 提醒核对", isOn: Binding(
                    get: { acc.wantsDailyReminder },
                    set: { model.setDailyReminder(id: acc.id, enabled: $0) }
                ))
                .font(.system(size: 11, weight: .medium))
                HStack(spacing: 10) {
                    Button("保存") {
                        model.updateAccountConsoleURL(id: acc.id, consoleURL: editConsoleURL)
                        if !editField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            model.updateManualAmount(id: acc.id, amountText: editField)
                        }
                        editAccountId = nil
                        editField = ""
                        editConsoleURL = ""
                    }
                    .buttonStyle(SBButtonStyle(kind: .accent))
                    Button("打开后台") {
                        model.updateAccountConsoleURL(id: acc.id, consoleURL: editConsoleURL)
                        if let refreshed = model.settings.accounts.first(where: { $0.id == acc.id }) {
                            model.openDashboard(for: refreshed)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SBTheme.accent)
                    Button("收起") {
                        editAccountId = nil
                        editField = ""
                        editConsoleURL = ""
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                }
            } else if acc.kind.needsAccessKeyPair {
                Text(acc.kind.accessKeyIdHintCN)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                TextField(acc.kind.accessKeyIdHintCN, text: $editAccessKey)
                    .textFieldStyle(.roundedBorder)
                Text(acc.kind.credentialHintCN)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                SecureField(acc.kind.credentialHintCN, text: $editField)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 10) {
                    Button("保存") {
                        model.updateAccountConsoleURL(id: acc.id, consoleURL: editConsoleURL)
                        let ak = editAccessKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        let sk = editField.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !ak.isEmpty, !sk.isEmpty {
                            Task {
                                await model.updateAccountSecret(
                                    id: acc.id,
                                    secret: VolcengineSigner.packCredentials(accessKeyId: ak, secretAccessKey: sk)
                                )
                            }
                        }
                        editAccountId = nil
                        editField = ""
                        editAccessKey = ""
                        editConsoleURL = ""
                    }
                    .buttonStyle(SBButtonStyle(kind: .accent))
                    Button("打开后台") {
                        model.updateAccountConsoleURL(id: acc.id, consoleURL: editConsoleURL)
                        if let refreshed = model.settings.accounts.first(where: { $0.id == acc.id }) {
                            model.openDashboard(for: refreshed)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SBTheme.accent)
                    Button("收起") {
                        editAccountId = nil
                        editField = ""
                        editAccessKey = ""
                        editConsoleURL = ""
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                }
            } else {
                if acc.kind.needsUserId {
                    Text(acc.kind.userIdHintCN)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SBTheme.muted)
                    TextField(acc.kind.userIdHintCN, text: $editUserId)
                        .textFieldStyle(.roundedBorder)
                }
                Text("粘贴密钥（可只改官网 / 用户 ID 时留空）")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                SecureField(acc.kind.credentialHintCN, text: $editField)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 10) {
                    Button("保存") {
                        model.updateAccountConsoleURL(id: acc.id, consoleURL: editConsoleURL)
                        let hasUID = !editUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        let hasSecret = !editField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        if acc.kind.needsUserId, hasUID {
                            model.updateAccountUserId(id: acc.id, userId: editUserId)
                        }
                        if hasSecret {
                            Task {
                                await model.updateAccountSecret(id: acc.id, secret: editField)
                            }
                        }
                        if !hasUID && !hasSecret {
                            if acc.kind.needsUserId, (acc.userId ?? "").isEmpty {
                                model.banner = "请填写用户 ID"
                                return
                            }
                        }
                        editAccountId = nil
                        editField = ""
                        editUserId = ""
                        editConsoleURL = ""
                    }
                    .buttonStyle(SBButtonStyle(kind: .accent))
                    Button("打开后台") {
                        model.updateAccountConsoleURL(id: acc.id, consoleURL: editConsoleURL)
                        if let refreshed = model.settings.accounts.first(where: { $0.id == acc.id }) {
                            model.openDashboard(for: refreshed)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SBTheme.accent)
                    Button("收起") {
                        editAccountId = nil
                        editField = ""
                        editUserId = ""
                        editConsoleURL = ""
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                }
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Add form inside platform card

    private func addForm(for kind: ProviderKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kind.isManualEntry ? "添加手录账号" : (kind.supportsBrowserSessionImport ? "连接浏览器账号" : "添加密钥"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SBTheme.text)

            TextField("显示名称（可选）", text: $draftName)
                .textFieldStyle(.roundedBorder)

            if kind.needsBaseURL {
                TextField("API Base URL，如 https://api.example.com", text: $draftBaseURL)
                    .textFieldStyle(.roundedBorder)
            }

            Text("官网 / 后台链接（打开后台时跳转，可改）")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SBTheme.muted)
            TextField(
                kind.defaultConsoleURL ?? "https://… 平台控制台",
                text: $draftConsoleURL
            )
            .textFieldStyle(.roundedBorder)

            if kind.needsUserId, !kind.supportsBrowserSessionImport {
                TextField(kind.userIdHintCN, text: $draftUserId)
                    .textFieldStyle(.roundedBorder)
            }

            if kind.isManualEntry {
                TextField("当前余额（可选）", text: $draftManualAmount)
                    .textFieldStyle(.roundedBorder)
                Text("每天 10:00 提醒打开后台核对")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
            } else if kind.needsAccessKeyPair {
                TextField(kind.accessKeyIdHintCN, text: $draftAccessKey)
                    .textFieldStyle(.roundedBorder)
                SecureField(kind.credentialHintCN, text: $draftSecret)
                    .textFieldStyle(.roundedBorder)
                Text("在「访问控制 → 密钥管理」创建 AK/SK，需开通账单查询权限")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else if kind.supportsBrowserSessionImport {
                cookieProviderSetup(kind: kind)
            } else {
                SecureField(kind.credentialHintCN, text: $draftSecret)
                    .textFieldStyle(.roundedBorder)
            }

            if kind.supportsBrowserSessionImport {
                Button("打开官网登录") { model.openBrowserLogin(for: kind) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SBTheme.accent)
                    .accessibilityIdentifier("browser.login.\(kind.rawValue)")
                    .disabled(model.browserImporting)
                Button(browserImportButtonTitle(for: kind)) {
                    let name = draftName
                    let consoleURL = draftConsoleURL
                    Task {
                        let saved = await model.importBrowserSessionAndAdd(kind: kind, displayName: name, consoleURL: consoleURL)
                        if saved, expandedKey == kind.rawValue {
                            resetDraft(for: kind)
                        }
                    }
                }
                .buttonStyle(SBButtonStyle(kind: .accent))
                .accessibilityIdentifier("browser.add.\(kind.rawValue)")
                .disabled(model.browserImporting)
                browserImportFeedback(for: kind)
            } else {
                Button(kind.isManualEntry ? "添加手录账号" : "保存密钥") {
                    Task {
                        await submitAdd(kind: kind)
                    }
                }
                .buttonStyle(SBButtonStyle(kind: .accent))
                .disabled(addDisabled(kind))
            }
        }
    }

    private func browserImportButtonTitle(for kind: ProviderKind, existing: Bool = false) -> String {
        if model.browserImporting { return "正在自动连接…" }
        if model.browserImportDirectoryRequired.contains(kind) {
            return "授权目录并重新连接"
        }
        if model.browserLoginRequiredKinds.contains(kind) { return "登录完成，重新连接" }
        return existing ? "重新连接" : "自动连接并添加"
    }

    @ViewBuilder
    private func browserImportFeedback(for kind: ProviderKind) -> some View {
        if let message = model.browserImportMessages[kind] {
            HStack(alignment: .top, spacing: 6) {
                if model.browserImporting {
                    ProgressView().controlSize(.mini)
                }
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(model.browserImportDirectoryRequired.contains(kind) ? SBTheme.warn : SBTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// MiMo / MiniMax / apinebula：一键导入优先，手贴备选。
    @ViewBuilder
    private func cookieProviderSetup(kind: ProviderKind) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("浏览器连接")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SBTheme.text)
            Text(cookieSetupGuide(kind))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup("高级：手动填写 Cookie") {
                SecureField("Cookie 或会话值", text: $draftSecret)
                    .textFieldStyle(.roundedBorder)
                if kind.needsUserId {
                    TextField(kind.userIdHintCN, text: $draftUserId)
                        .textFieldStyle(.roundedBorder)
                }
                Text("仅作为备选；自动连接会从浏览器读取会话并识别 UID")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("手动填写后保存") { Task { await submitAdd(kind: kind) } }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SBTheme.accent)
                    .disabled(addDisabled(kind) || model.browserImporting)
            }
            .font(.system(size: 11, weight: .medium))
        }
    }

    private func cookieSetupGuide(_ kind: ProviderKind) -> String {
        "1. 已登录？直接点「自动连接并添加」\n2. 需要登录时，点「打开官网登录」并完成登录\n3. 回到智余点「登录完成，重新连接」，自动获取余额\n首次权限不足时，请在系统窗口确认浏览器目录。无需手抄 Cookie / UID"
    }

    private func addDisabled(_ kind: ProviderKind) -> Bool {
        if kind.isManualEntry {
            // 手录至少要有官网（默认会预填；New-API 式无默认时需填）
            let consoleEmpty = draftConsoleURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (kind.defaultConsoleURL ?? "").isEmpty
            return consoleEmpty
        }
        if kind.needsAccessKeyPair {
            return draftAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || draftSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        // Cookie 平台：密钥非空即可（userId 可从 Cookie / session 自动拆）
        if kind.supportsBrowserSessionImport {
            // apinebula 主路径是 Chrome 导入，手动保存时才校验密钥框
            return draftSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return draftSecret.isEmpty
            || (kind.needsBaseURL && draftBaseURL.isEmpty)
            || (kind.needsUserId && draftUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func submitAdd(kind: ProviderKind) async {
        let amount = Double(
            draftManualAmount
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: "")
        )
        let secret: String
        if kind.needsAccessKeyPair {
            secret = VolcengineSigner.packCredentials(
                accessKeyId: draftAccessKey,
                secretAccessKey: draftSecret
            )
        } else {
            secret = draftSecret
        }
        let console = draftConsoleURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = await model.addAccount(
            kind: kind,
            displayName: draftName,
            baseURL: kind.needsBaseURL ? draftBaseURL : kind.defaultBaseURL,
            consoleURL: console.isEmpty ? kind.defaultConsoleURL : console,
            userId: kind.needsUserId ? draftUserId : nil,
            secret: secret,
            manualAmount: kind.isManualEntry ? amount : nil
        )
        if saved, expandedKey == kind.rawValue {
            resetDraft(for: kind)
        } else if !saved, kind.supportsBrowserSessionImport {
            model.browserImportMessages[kind] = "密钥保存失败，填写内容已保留。请重试"
        }
    }

    private func resetDraft(for kind: ProviderKind) {
        draftName = ""
        draftBaseURL = kind.defaultBaseURL ?? ""
        draftConsoleURL = kind.defaultConsoleURL ?? ""
        draftUserId = ""
        draftAccessKey = ""
        draftSecret = ""
        draftManualAmount = ""
    }

    // MARK: - Visual identity

    private func iconName(for kind: ProviderKind) -> String {
        switch kind {
        case .deepseek: "sparkles"
        case .newapi: "server.rack"
        case .openrouter: "network"
        case .viraltok: "film"
        case .laozhang: "person.crop.circle"
        case .dmxapi: "shippingbox"
        case .kimi: "moon.stars"
        case .volcengine: "flame.fill"
        case .mimo: "iphone"
        case .minimax: "waveform"
        case .apinebula: "cloud.fill"
        case .bytebroad: "b.circle.fill"
        case .unsupported: "questionmark.circle"
        }
    }

    private func iconColors(for kind: ProviderKind) -> [Color] {
        switch kind {
        case .deepseek: [Color(red: 0.25, green: 0.55, blue: 0.95), Color(red: 0.2, green: 0.4, blue: 0.9)]
        case .newapi: [Color(red: 0.45, green: 0.35, blue: 0.95), Color(red: 0.35, green: 0.25, blue: 0.85)]
        case .openrouter: [Color(red: 0.55, green: 0.25, blue: 0.75), Color(red: 0.45, green: 0.2, blue: 0.65)]
        case .viraltok: [Color(red: 0.15, green: 0.65, blue: 0.45), Color(red: 0.1, green: 0.5, blue: 0.35)]
        case .laozhang: [Color(red: 0.95, green: 0.55, blue: 0.20), Color(red: 0.9, green: 0.4, blue: 0.15)]
        case .dmxapi: [Color(red: 0.09, green: 0.64, blue: 0.72), Color(red: 0.05, green: 0.5, blue: 0.6)]
        case .kimi: [Color(red: 0.25, green: 0.25, blue: 0.28), Color(red: 0.15, green: 0.15, blue: 0.18)]
        case .volcengine: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.1, green: 0.3, blue: 0.85)]
        case .mimo: [Color(red: 0.95, green: 0.30, blue: 0.25), Color(red: 0.85, green: 0.2, blue: 0.2)]
        case .minimax: [Color(red: 0.55, green: 0.25, blue: 0.95), Color(red: 0.4, green: 0.15, blue: 0.85)]
        case .apinebula: [Color(red: 0.20, green: 0.55, blue: 0.90), Color(red: 0.12, green: 0.35, blue: 0.75)]
        case .bytebroad: [Color(red: 0.10, green: 0.48, blue: 0.83), Color(red: 0.08, green: 0.30, blue: 0.61)]
        case .unsupported: [Color(red: 0.45, green: 0.45, blue: 0.48), Color(red: 0.32, green: 0.32, blue: 0.35)]
        }
    }

    private static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()
}
