import SwiftUI
import Domain

/// 设置页：折叠卡片。
///
/// 智余本职 = 查各平台 API / Token 余额并报警，**不需要**「开数据源」总开关。
/// 1. API 账号 — 添加 Key / 手录
/// 2. 报警通知 — Mac 通知 + SMTP 出站
/// 3. 后台同步 / 阈值 / 登录启动 / 日志 / 更新 + 底部一句话关于
struct SettingsRootView: View {
    @ObservedObject var model: AppModel

    @State private var expandAPI = false
    @State private var expandAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            apiCard
            alertCard
            BackgroundSystemSection(model: model)
        }
    }

    // MARK: 1 · API 账号

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
        if n == 0 { return "先在这里添加 DeepSeek / Kimi / 手录…" }
        return "已添加 \(n) 个 · 主页会显示余额卡"
    }

    // MARK: 2 · 报警

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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SBTheme.muted)
    }
}
