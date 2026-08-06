import SwiftUI
import Domain

/// Settings tab root. Section order is product-fixed:
/// 1 data source · 2 API · 3 platform mail · 4 IMAP · 5 alerts · 6 SMTP · 7 refresh · 8 about
struct SettingsRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DataSourceSettingsSection(model: model)
            APIAccountsSection(model: model)
            PlatformMailSection(model: model)
            IMAPSection(model: model)
            AlertChannelsSection(model: model)
            SMTPSection(model: model)
            refreshBlock
            aboutBlock
        }
    }

    private var refreshBlock: some View {
        SettingsChrome.card(title: "刷新间隔") {
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
        }
    }

    private var aboutBlock: some View {
        SettingsChrome.card(title: "关于") {
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
