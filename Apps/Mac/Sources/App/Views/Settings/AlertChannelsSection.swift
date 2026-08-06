import SwiftUI
import Domain

struct AlertChannelsSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsChrome.card(title: "报警通道（智余如何通知你）") {
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
                    model.notificationStatusCaption == "通知已开启"
                        ? SBTheme.ok
                        : SBTheme.warn
                )

            HStack {
                Button("测试 Mac 通知") { model.sendTestMacNotification() }
                    .buttonStyle(SBButtonStyle(kind: .normal))
                Button("测试报警邮件") { model.sendTestEmail() }
                    .buttonStyle(SBButtonStyle(kind: .normal))
            }

            Text("触发：API/邮件解析后状态为偏低·危急·耗尽；或平台新邮件含报警关键词。")
                .font(.system(size: 10))
                .foregroundStyle(SBTheme.muted)
        }
        .onAppear {
            Task { await model.refreshNotificationStatus() }
        }
    }
}
