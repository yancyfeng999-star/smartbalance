import SwiftUI
import Domain

struct APIAccountsSection: View {
    @ObservedObject var model: AppModel

    @State private var newKind: ProviderKind = .deepseek
    @State private var newName = ""
    @State private var newBaseURL = ""
    @State private var newSecret = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            accountsCard
            addCard
        }
    }

    private var accountsCard: some View {
        SettingsChrome.card(title: "API 账号") {
            if model.settings.accounts.isEmpty {
                Text("暂无 · 多数平台走这里")
                    .font(.system(size: 12))
                    .foregroundStyle(SBTheme.muted)
            } else {
                ForEach(model.settings.accounts) { acc in
                    accountRow(
                        title: acc.title,
                        subtitle: acc.kind.displayName + (model.hasSecret(for: acc) ? " · 已配置密钥" : " · 缺密钥"),
                        enabled: acc.enabled,
                        onToggle: { model.toggleAccount(acc.id, enabled: $0) },
                        onDelete: { model.removeAccount(acc.id) }
                    )
                    if acc.id != model.settings.accounts.last?.id {
                        Divider().overlay(SBTheme.stroke)
                    }
                }
            }
        }
    }

    private var addCard: some View {
        SettingsChrome.card(title: "添加 API 账号") {
            Picker("平台", selection: $newKind) {
                ForEach(ProviderKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .labelsHidden()
            // 3+ providers: menu is clearer than a cramped segmented control.
            .pickerStyle(.menu)

            TextField("显示名称（可选）", text: $newName)
                .textFieldStyle(.roundedBorder)

            if newKind.needsBaseURL {
                TextField("Base URL，如 https://api.example.com", text: $newBaseURL)
                    .textFieldStyle(.roundedBorder)
            }

            SecureField(newKind.credentialHintCN, text: $newSecret)
                .textFieldStyle(.roundedBorder)

            Button("添加 API 账号") {
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

    private func accountRow(
        title: String,
        subtitle: String,
        enabled: Bool,
        onToggle: @escaping (Bool) -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SBTheme.text)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(SBTheme.muted)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { enabled }, set: onToggle))
                .labelsHidden()
                .toggleStyle(.switch)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(SBTheme.danger)
            }
            .buttonStyle(.plain)
        }
    }
}
