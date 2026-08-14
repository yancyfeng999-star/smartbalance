import SwiftUI
import Domain

/// 设置页：折叠卡片。
///
/// 1. 外观 · 2. 语言（对齐智额）
/// 3. API 账号 · 4. 报警 · 5. 后台同步 / 关于
struct SettingsRootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared

    @State private var expandAPI = false
    @State private var expandAlert = false
    @State private var expandCompat = false

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 10) {
            AppearanceSettingsCard(model: model)
            LanguageSettingsCard(model: model)
            apiCard
            alertCard
            compatibilityCard
            BackgroundSystemSection(model: model)
        }
        .onAppear {
            if model.preferExpandAPIAccounts {
                expandAPI = true
                model.preferExpandAPIAccounts = false
            }
        }
    }

    // MARK: API 账号

    private var apiCard: some View {
        SettingsExpandableCard(
            icon: "key.fill",
            iconColors: [Color(red: 0.2, green: 0.7, blue: 0.55), Color(red: 0.15, green: 0.55, blue: 0.75)],
            title: l10n.t("settings.api"),
            subtitle: apiSubtitle,
            isExpanded: $expandAPI
        ) {
            APIAccountsSection(model: model, embedded: true)
        }
    }

    private var apiSubtitle: String {
        let n = model.settings.accounts.count
        if n == 0 { return "先在这里添加 DeepSeek / Kimi / 手录…" }
        return "已添加 \(n) 个 · 主页会显示余额卡"
    }

    // MARK: 2 · 报警

    private var alertCard: some View {
        SettingsExpandableCard(
            icon: "bell.badge.fill",
            iconColors: [Color(red: 0.95, green: 0.35, blue: 0.4), Color(red: 0.85, green: 0.25, blue: 0.55)],
            title: l10n.t("settings.alerts"),
            subtitle: alertSubtitle,
            isExpanded: $expandAlert
        ) {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("通知通道")
                AlertChannelsSection(model: model, embedded: true)

                Divider().overlay(SBTheme.stroke)

                sectionLabel("邮件报警 SMTP（发出）")
                SMTPSection(model: model, embedded: true)
            }
        }
    }

    private var alertSubtitle: String {
        var parts: [String] = []
        if model.settings.alertChannels.macNotificationEnabled { parts.append("Mac") }
        if model.settings.alertChannels.outboundEmailEnabled { parts.append("邮件") }
        return parts.isEmpty ? "均已关闭" : parts.joined(separator: " · ") + " 已开"
    }

    private var compatibilityCard: some View {
        SettingsExpandableCard(
            icon: "checkmark.shield.fill",
            iconColors: [Color(red: 0.25, green: 0.62, blue: 0.78), Color(red: 0.18, green: 0.42, blue: 0.82)],
            title: l10n.t("settings.compatibility"),
            subtitle: compatibilitySubtitle,
            isExpanded: $expandCompat
        ) {
            CompatibilityView(model: model, presentation: .settings)
        }
        .onChange(of: expandCompat) { _, open in
            if open {
                model.openCompatibilityFromSettings()
            }
        }
    }

    private var compatibilitySubtitle: String {
        guard let report = model.compatibilityReport else {
            return l10n.t("settings.compatibility_sub")
        }
        return report.hasBlockingIssue
            ? l10n.t("settings.compatibility_sub.blocked")
            : l10n.t("settings.compatibility_sub.ok")
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SBTheme.muted)
    }
}
