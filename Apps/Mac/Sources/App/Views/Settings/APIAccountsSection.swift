import SwiftUI
import Domain

struct APIAccountsSection: View {
    @ObservedObject var model: AppModel
    /// 嵌在折叠卡内时不再套外层 card
    var embedded: Bool = false

    @State private var newKind: ProviderKind = .viraltok
    @State private var newName = ""
    @State private var newBaseURL = ""
    @State private var newSecret = ""

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                SettingsChrome.card(title: "API 账号") { content }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.settings.accounts.isEmpty {
                Text("暂无 · 选平台粘贴 Key 即可")
                    .font(.system(size: 12))
                    .foregroundStyle(SBTheme.muted)
            } else {
                ForEach(model.settings.accounts) { acc in
                    accountRow(acc)
                    if acc.id != model.settings.accounts.last?.id {
                        Divider().overlay(SBTheme.stroke)
                    }
                }
            }

            Divider().overlay(SBTheme.stroke)

            Text("添加账号")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SBTheme.muted)

            Picker("平台", selection: $newKind) {
                ForEach(ProviderKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            TextField("显示名称（可选）", text: $newName)
                .textFieldStyle(.roundedBorder)

            if newKind.needsBaseURL {
                TextField("Base URL，如 https://api.example.com", text: $newBaseURL)
                    .textFieldStyle(.roundedBorder)
            }

            SecureField(newKind.credentialHintCN, text: $newSecret)
                .textFieldStyle(.roundedBorder)

            Button("添加") {
                model.addAccount(
                    kind: newKind,
                    displayName: newName,
                    baseURL: newKind.needsBaseURL ? newBaseURL : newKind.defaultBaseURL,
                    secret: newSecret
                )
                newName = ""; newBaseURL = ""; newSecret = ""
            }
            .buttonStyle(SBButtonStyle(kind: .accent))
            .disabled(newSecret.isEmpty || (newKind.needsBaseURL && newBaseURL.isEmpty))
        }
    }

    private func accountRow(_ acc: BalanceAccount) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(acc.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SBTheme.text)
                Text(acc.kind.displayName + (model.hasSecret(for: acc) ? " · 已配置密钥" : " · 缺密钥"))
                    .font(.system(size: 10))
                    .foregroundStyle(SBTheme.muted)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { acc.enabled },
                set: { model.toggleAccount(acc.id, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            Button(role: .destructive) {
                model.removeAccount(acc.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(SBTheme.danger)
            }
            .buttonStyle(.plain)
        }
    }
}
