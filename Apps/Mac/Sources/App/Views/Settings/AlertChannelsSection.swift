import SwiftUI
import Domain

struct AlertChannelsSection: View {
    @ObservedObject var model: AppModel
    var embedded: Bool = false

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                SettingsChrome.card(title: "报警通道") { content }
            }
        }
        .onAppear {
            Task { await model.refreshNotificationStatus() }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { model.settings.alertChannels.macNotificationEnabled },
                set: { model.setMacNotificationEnabled($0) }
            )) {
                SettingsChrome.labelStack(
                    AlertChannel.macNotification.titleCN,
                    AlertChannel.macNotification.subtitleCN
                )
            }
            .toggleStyle(.switch)

            Toggle(isOn: Binding(
                get: { model.settings.alertChannels.outboundEmailEnabled },
                set: { model.setOutboundEmailAlertEnabled($0) }
            )) {
                SettingsChrome.labelStack(
                    AlertChannel.outboundEmail.titleCN,
                    AlertChannel.outboundEmail.subtitleCN
                )
            }
            .toggleStyle(.switch)

            Text(model.notificationStatusCaption)
                .font(.system(size: 11))
                .foregroundStyle(
                    model.notificationStatusCaption == "通知已开启" ? SBTheme.ok : SBTheme.warn
                )

            HStack {
                Button("测试 Mac 通知") { model.sendTestMacNotification() }
                    .buttonStyle(SBButtonStyle(kind: .normal))
                Button("测试报警邮件") { model.sendTestEmail() }
                    .buttonStyle(SBButtonStyle(kind: .normal))
            }

            Text("偏低 / 危急 / 耗尽，或平台报警邮件关键词时触发。")
                .font(.system(size: 10))
                .foregroundStyle(SBTheme.muted)
        }
    }
}
