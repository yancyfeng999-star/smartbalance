import SwiftUI

struct SMTPSection: View {
    @ObservedObject var model: AppModel

    @State private var smtpHost = ""
    @State private var smtpPort = "465"
    @State private var useTLS = true
    @State private var smtpUser = ""
    @State private var smtpPass = ""
    @State private var mailFromAddr = ""
    @State private var mailTo = ""
    @State private var amountTh = "10"
    @State private var percentTh = "20"
    @State private var cooldown = "3600"

    var body: some View {
        SettingsChrome.card(title: "邮件报警 SMTP（发出）") {
            Text("推荐 465 + TLS（隐式 TLS）。发送失败会显示在首页且不进入冷却，便于重试。")
                .font(.system(size: 11))
                .foregroundStyle(SBTheme.muted)

            HStack(spacing: 8) {
                Text("快捷填入")
                    .font(.system(size: 10))
                    .foregroundStyle(SBTheme.muted)
                smtpPresetButton("QQ", host: "smtp.qq.com")
                smtpPresetButton("163", host: "smtp.163.com")
                smtpPresetButton("Gmail", host: "smtp.gmail.com")
            }

            TextField("SMTP 主机，如 smtp.qq.com", text: $smtpHost)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("端口", text: $smtpPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Toggle("TLS（推荐 465）", isOn: $useTLS)
                    .toggleStyle(.switch)
            }
            if smtpPort.trimmingCharacters(in: .whitespaces) == "587" {
                Text("当前版本请改用 465 + TLS。587 STARTTLS 暂不支持。")
                    .font(.system(size: 11))
                    .foregroundStyle(SBTheme.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField("用户名", text: $smtpUser)
                .textFieldStyle(.roundedBorder)
            SecureField("密码 / 授权码（留空不改）", text: $smtpPass)
                .textFieldStyle(.roundedBorder)
            TextField("发件人", text: $mailFromAddr)
                .textFieldStyle(.roundedBorder)
            TextField("收件人（逗号分隔）", text: $mailTo)
                .textFieldStyle(.roundedBorder)
            HStack {
                SettingsChrome.labeledField("金额阈值", text: $amountTh)
                SettingsChrome.labeledField("百分比阈值", text: $percentTh)
                SettingsChrome.labeledField("冷却秒", text: $cooldown)
            }
            Button("保存 SMTP 与阈值") {
                model.saveOutboundEmail(
                    host: smtpHost,
                    port: Int(smtpPort) ?? 465,
                    useTLS: useTLS,
                    username: smtpUser,
                    password: smtpPass,
                    from: mailFromAddr,
                    to: mailTo,
                    amountThreshold: Double(amountTh) ?? 10,
                    percentThreshold: Double(percentTh) ?? 20,
                    cooldownSeconds: Int(cooldown) ?? 3600
                )
                smtpPass = ""
            }
            .buttonStyle(SBButtonStyle(kind: .accent))
        }
        .onAppear(perform: loadFields)
    }

    private func smtpPresetButton(_ title: String, host: String) -> some View {
        Button(title) {
            smtpHost = host
            smtpPort = "465"
            useTLS = true
        }
        .buttonStyle(SBButtonStyle(kind: .normal))
    }

    private func loadFields() {
        let e = model.settings.email
        smtpHost = e.smtpHost
        smtpPort = String(e.smtpPort)
        useTLS = e.useTLS
        smtpUser = e.username
        mailFromAddr = e.fromAddress
        mailTo = e.toAddresses.joined(separator: ", ")
        let ch = model.settings.alertChannels
        amountTh = String(format: "%.0f", ch.defaultAmountThreshold)
        percentTh = String(format: "%.0f", ch.defaultPercentThreshold)
        cooldown = String(ch.cooldownSeconds)
    }
}
