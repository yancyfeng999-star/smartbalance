import SwiftUI

struct SMTPSection: View {
    @ObservedObject var model: AppModel
    var embedded: Bool = false

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
        Group {
            if embedded {
                content
            } else {
                SettingsChrome.card(title: "邮件报警 SMTP") { content }
            }
        }
        .onAppear(perform: loadFields)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("推荐 465 + TLS。失败会提示在首页且不进冷却。")
                .font(.system(size: 11))
                .foregroundStyle(SBTheme.muted)

            HStack(spacing: 8) {
                Text("快捷")
                    .font(.system(size: 10))
                    .foregroundStyle(SBTheme.muted)
                smtpPresetButton("QQ", host: "smtp.qq.com")
                smtpPresetButton("163", host: "smtp.163.com")
                smtpPresetButton("Gmail", host: "smtp.gmail.com")
            }

            TextField("SMTP 主机", text: $smtpHost)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("端口", text: $smtpPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Toggle("TLS", isOn: $useTLS)
                    .toggleStyle(.switch)
            }
            if smtpPort.trimmingCharacters(in: .whitespaces) == "587" {
                Text("请改用 465 + TLS（暂不支持 587 STARTTLS）。")
                    .font(.system(size: 11))
                    .foregroundStyle(SBTheme.warn)
            }
            TextField("用户名", text: $smtpUser)
                .textFieldStyle(.roundedBorder)
            if let mask = model.maskedSMTPPassword(), smtpPass.isEmpty {
                HStack {
                    Text("已保存密码")
                        .font(.system(size: 11))
                        .foregroundStyle(SBTheme.muted)
                    Text(mask)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(SBTheme.text)
                    Spacer()
                    Text("留空则不改")
                        .font(.system(size: 10))
                        .foregroundStyle(SBTheme.muted)
                }
            }
            SecureField(model.hasSMTPPassword() ? "新密码（可选）" : "密码 / 授权码", text: $smtpPass)
                .textFieldStyle(.roundedBorder)
            TextField("发件人", text: $mailFromAddr)
                .textFieldStyle(.roundedBorder)
            TextField("收件人（逗号分隔）", text: $mailTo)
                .textFieldStyle(.roundedBorder)
            HStack {
                SettingsChrome.labeledField("金额阈值", text: $amountTh)
                SettingsChrome.labeledField("百分比", text: $percentTh)
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
