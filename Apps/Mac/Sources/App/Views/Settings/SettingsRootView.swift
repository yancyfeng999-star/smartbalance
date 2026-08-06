import SwiftUI
import Domain

/// 设置页：智额式折叠卡片，相近能力归纳合并。
///
/// 卡片结构：
/// 1. 数据源 — API / 平台邮件开关
/// 2. API 账号 — 列表 + 添加
/// 3. 平台邮件 — 邮件源 + IMAP（入站）
/// 4. 报警通知 — Mac 通知 + SMTP（出站）
/// 5. 通用 — 刷新间隔 + 关于
struct SettingsRootView: View {
    @ObservedObject var model: AppModel

    @State private var expandDataSource = true
    @State private var expandAPI = true
    @State private var expandMail = false
    @State private var expandAlert = false
    @State private var expandGeneral = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            dataSourceCard
            apiCard
            platformMailCard
            alertCard
            generalCard
        }
        .onAppear {
            // 无账号时默认展开 API；有平台邮件源时展开邮件卡
            if model.settings.accounts.isEmpty {
                expandAPI = true
            }
            if !model.settings.mailSources.isEmpty || model.settings.inboundMailbox.enabled {
                expandMail = true
            }
        }
    }

    // MARK: 1 · 数据源

    private var dataSourceCard: some View {
        SettingsExpandableCard(
            icon: "antenna.radiowaves.left.and.right",
            iconColors: [Color(red: 0.3, green: 0.55, blue: 0.98), Color(red: 0.45, green: 0.35, blue: 0.95)],
            title: "数据源",
            subtitle: dataSourceSubtitle,
            isExpanded: $expandDataSource
        ) {
            Toggle(isOn: Binding(
                get: { model.settings.apiQueryEnabled },
                set: { model.apiQueryOn = $0 }
            )) {
                SettingsChrome.labelStack(DataSourceKind.api.titleCN, DataSourceKind.api.subtitleCN)
            }
            .toggleStyle(.switch)

            Toggle(isOn: Binding(
                get: { model.settings.platformMailEnabled },
                set: { model.platformMailOn = $0 }
            )) {
                SettingsChrome.labelStack(
                    DataSourceKind.platformEmail.titleCN,
                    DataSourceKind.platformEmail.subtitleCN
                )
            }
            .toggleStyle(.switch)
        }
    }

    private var dataSourceSubtitle: String {
        var parts: [String] = []
        if model.settings.apiQueryEnabled { parts.append("API") }
        if model.settings.platformMailEnabled { parts.append("邮件") }
        return parts.isEmpty ? "均已关闭" : parts.joined(separator: " · ") + " 已开"
    }

    // MARK: 2 · API 账号

    private var apiCard: some View {
        SettingsExpandableCard(
            icon: "key.fill",
            iconColors: [Color(red: 0.2, green: 0.7, blue: 0.55), Color(red: 0.15, green: 0.55, blue: 0.75)],
            title: "API 账号",
            subtitle: apiSubtitle,
            isExpanded: $expandAPI
        ) {
            APIAccountsSection(model: model, embedded: true)
        }
    }

    private var apiSubtitle: String {
        let n = model.settings.accounts.count
        if n == 0 { return "DeepSeek / New-API / OpenRouter / 吉米" }
        return "已添加 \(n) 个"
    }

    // MARK: 3 · 平台邮件（源 + IMAP）

    private var platformMailCard: some View {
        SettingsExpandableCard(
            icon: "envelope.fill",
            iconColors: [Color(red: 0.95, green: 0.55, blue: 0.25), Color(red: 0.9, green: 0.35, blue: 0.4)],
            title: "平台邮件",
            subtitle: mailSubtitle,
            isExpanded: $expandMail
        ) {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("邮件源规则")
                PlatformMailSection(model: model, embedded: true)

                Divider().overlay(SBTheme.stroke)

                sectionLabel("IMAP 收件箱（读信）")
                IMAPSection(model: model, embedded: true)
            }
        }
    }

    private var mailSubtitle: String {
        let n = model.settings.mailSources.count
        let imap = model.settings.inboundMailbox.enabled ? "IMAP 已开" : "IMAP 未开"
        if n == 0 { return imap }
        return "\(n) 个源 · \(imap)"
    }

    // MARK: 4 · 报警（Mac + SMTP）

    private var alertCard: some View {
        SettingsExpandableCard(
            icon: "bell.badge.fill",
            iconColors: [Color(red: 0.95, green: 0.35, blue: 0.4), Color(red: 0.85, green: 0.25, blue: 0.55)],
            title: "报警通知",
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

    // MARK: 5 · 通用

    private var generalCard: some View {
        SettingsExpandableCard(
            icon: "slider.horizontal.3",
            iconColors: [Color(red: 0.45, green: 0.48, blue: 0.55), Color(red: 0.3, green: 0.32, blue: 0.4)],
            title: "通用",
            subtitle: refreshSubtitle,
            isExpanded: $expandGeneral
        ) {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("刷新间隔")
                Picker("间隔", selection: Binding(
                    get: { model.settings.refreshIntervalSecs },
                    set: { model.setRefreshInterval($0) }
                )) {
                    Text("仅手动").tag(0)
                    Text("5 分钟").tag(300)
                    Text("10 分钟").tag(600)
                    Text("15 分钟").tag(900)
                    Text("30 分钟").tag(1800)
                }
                .labelsHidden()
                .pickerStyle(.menu)

                Divider().overlay(SBTheme.stroke)

                sectionLabel("关于")
                Text("\(Brand.nameCN) · \(Brand.nameEN)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SBTheme.text)
                Text("API 直查 · 平台邮件 · Mac 通知 · 邮件报警")
                    .font(.system(size: 11))
                    .foregroundStyle(SBTheme.muted)
                Text("v0.1.0 · 仅 Mac · 密钥本机 Keychain")
                    .font(.system(size: 10))
                    .foregroundStyle(SBTheme.muted)
            }
        }
    }

    private var refreshSubtitle: String {
        let s = model.settings.refreshIntervalSecs
        if s <= 0 { return "仅手动刷新" }
        if s < 60 { return "\(s) 秒" }
        return "每 \(s / 60) 分钟"
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SBTheme.muted)
    }
}
