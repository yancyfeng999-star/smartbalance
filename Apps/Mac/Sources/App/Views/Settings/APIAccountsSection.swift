import SwiftUI
import AppKit
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
    @State private var draftUserId = ""
    @State private var draftAccessKey = ""
    @State private var draftSecret = ""
    @State private var draftManualAmount = ""
    @State private var editAccountId: UUID?
    @State private var editField = ""
    @State private var editUserId = ""
    @State private var editAccessKey = ""

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
            Text("点平台卡片展开，添加密钥或手录金额")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(ProviderKind.allCases) { kind in
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
            title: kind.displayName,
            subtitle: platformSubtitle(kind: kind, accounts: accounts),
            badge: accounts.isEmpty ? nil : "\(accounts.count)",
            badgeColor: accounts.contains(where: { missingCredential($0) }) ? SBTheme.warn : SBTheme.ok,
            isExpanded: expanded
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if accounts.isEmpty {
                    Text(kind.isManualEntry ? "尚未添加 · 展开下方表单手录余额" : "尚未添加 · 粘贴密钥后保存")
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
                    withAnimation(AppMotion.expand) {
                        if editAccountId == acc.id {
                            editAccountId = nil
                            editField = ""
                            editUserId = ""
                        } else {
                            editAccountId = acc.id
                            editUserId = acc.userId ?? ""
                            if acc.kind.isManualEntry, let a = acc.manualAmount {
                                editField = String(format: "%g", a)
                            } else {
                                editField = ""
                            }
                        }
                    }
                } label: {
                    Image(systemName: acc.kind.isManualEntry ? "pencil.circle.fill" : "key.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SBTheme.accent)
                }
                .buttonStyle(.plain)
                .help(acc.kind.isManualEntry ? "录入余额" : "更新密钥")

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
                    Button("保存金额") {
                        model.updateManualAmount(id: acc.id, amountText: editField)
                        editAccountId = nil
                        editField = ""
                    }
                    .buttonStyle(SBButtonStyle(kind: .accent))
                    .disabled(editField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("打开后台") {
                        if let url = acc.baseURL.flatMap(URL.init(string:)) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SBTheme.accent)
                    Button("收起") {
                        editAccountId = nil
                        editField = ""
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
                    Button("保存 AK/SK") {
                        let ak = editAccessKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        let sk = editField.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !ak.isEmpty, !sk.isEmpty else {
                            model.banner = "请同时填写 Access Key ID 与 Secret Access Key"
                            return
                        }
                        model.updateAccountSecret(
                            id: acc.id,
                            secret: VolcengineSigner.packCredentials(accessKeyId: ak, secretAccessKey: sk)
                        )
                        editAccountId = nil
                        editField = ""
                        editAccessKey = ""
                    }
                    .buttonStyle(SBButtonStyle(kind: .accent))
                    .disabled(
                        editAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || editField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    Button("收起") {
                        editAccountId = nil
                        editField = ""
                        editAccessKey = ""
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
                Text("粘贴密钥（可只改用户 ID 时留空）")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                SecureField(acc.kind.credentialHintCN, text: $editField)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 10) {
                    Button("保存") {
                        let hasUID = !editUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        let hasSecret = !editField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        if acc.kind.needsUserId, hasUID {
                            model.updateAccountUserId(id: acc.id, userId: editUserId)
                        }
                        if hasSecret {
                            model.updateAccountSecret(id: acc.id, secret: editField)
                        }
                        if !hasUID && !hasSecret {
                            // 需要 userId 且当前账号没有 → 必须填
                            if acc.kind.needsUserId, (acc.userId ?? "").isEmpty {
                                model.banner = "请填写用户 ID"
                                return
                            }
                        }
                        editAccountId = nil
                        editField = ""
                        editUserId = ""
                    }
                    .buttonStyle(SBButtonStyle(kind: .accent))
                    .disabled(
                        editField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && editUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    Button("收起") {
                        editAccountId = nil
                        editField = ""
                        editUserId = ""
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
            Text(kind.isManualEntry ? "添加手录账号" : "添加密钥")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SBTheme.text)

            TextField("显示名称（可选）", text: $draftName)
                .textFieldStyle(.roundedBorder)

            if kind.needsBaseURL {
                TextField("Base URL，如 https://api.example.com", text: $draftBaseURL)
                    .textFieldStyle(.roundedBorder)
            }
            if kind.needsUserId {
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
            } else {
                SecureField(kind.credentialHintCN, text: $draftSecret)
                    .textFieldStyle(.roundedBorder)
            }

            Button(kind.isManualEntry ? "添加手录账号" : "保存密钥") {
                submitAdd(kind: kind)
            }
            .buttonStyle(SBButtonStyle(kind: .accent))
            .disabled(addDisabled(kind))
        }
    }

    private func addDisabled(_ kind: ProviderKind) -> Bool {
        if kind.isManualEntry {
            return kind.needsBaseURL && draftBaseURL.isEmpty
        }
        if kind.needsAccessKeyPair {
            return draftAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || draftSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return draftSecret.isEmpty
            || (kind.needsBaseURL && draftBaseURL.isEmpty)
            || (kind.needsUserId && draftUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func submitAdd(kind: ProviderKind) {
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
        model.addAccount(
            kind: kind,
            displayName: draftName,
            baseURL: kind.needsBaseURL ? draftBaseURL : kind.defaultBaseURL,
            userId: kind.needsUserId ? draftUserId : nil,
            secret: secret,
            manualAmount: kind.isManualEntry ? amount : nil
        )
        resetDraft(for: kind)
    }

    private func resetDraft(for kind: ProviderKind) {
        draftName = ""
        draftBaseURL = kind.defaultBaseURL ?? ""
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
        }
    }

    private static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()
}
