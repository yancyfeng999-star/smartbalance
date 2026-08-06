import SwiftUI
import Domain

struct SettingsView: View {
    @ObservedObject var model: AppModel

    // API 账号
    @State private var newKind: ProviderKind = .deepseek
    @State private var newName = ""
    @State private var newBaseURL = ""
    @State private var newSecret = ""

    // 平台邮件源
    @State private var mailName = ""
    @State private var mailFrom = ""
    @State private var mailSubject = ""
    @State private var mailUnit = "¥"
    @State private var mailRegex = ""

    // IMAP
    @State private var imapEnabled = false
    @State private var imapHost = ""
    @State private var imapPort = "993"
    @State private var imapTLS = true
    @State private var imapUser = ""
    @State private var imapPass = ""
    @State private var imapFolder = "INBOX"

    // 出站 SMTP
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

    /// 试解析 sheet 目标源
    @State private var parseTarget: PlatformMailSource?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            dataSourceBlock
            apiAccountsBlock
            addAPIBlock
            mailSourcesBlock
            addMailSourceBlock
            imapBlock
            alertChannelsBlock
            outboundEmailBlock
            refreshBlock
            aboutBlock
        }
        .onAppear(perform: loadFields)
        .sheet(item: $parseTarget) { src in
            PasteMailParseSheet(source: src, model: model)
        }
    }

    // MARK: - Data sources

    private var dataSourceBlock: some View {
        settingsCard(title: "数据源（怎么知道余额）") {
            Toggle(isOn: Binding(
                get: { model.settings.apiQueryEnabled },
                set: { model.apiQueryOn = $0 }
            )) {
                labelStack(DataSourceKind.api.titleCN, DataSourceKind.api.subtitleCN)
            }
            .toggleStyle(.switch)

            Toggle(isOn: Binding(
                get: { model.settings.platformMailEnabled },
                set: { model.platformMailOn = $0 }
            )) {
                labelStack(DataSourceKind.platformEmail.titleCN, DataSourceKind.platformEmail.subtitleCN)
            }
            .toggleStyle(.switch)
        }
    }

    // MARK: - API

    private var apiAccountsBlock: some View {
        settingsCard(title: "API 账号") {
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

    private var addAPIBlock: some View {
        settingsCard(title: "添加 API 账号") {
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

    // MARK: - Platform mail

    private var mailSourcesBlock: some View {
        settingsCard(title: "平台邮件源（无实时 API）") {
            Text("匹配平台「固定发件邮箱」发来的余额/报警信，解析金额后展示。")
                .font(.system(size: 11))
                .foregroundStyle(SBTheme.muted)
            if model.settings.mailSources.isEmpty {
                Text("暂无")
                    .font(.system(size: 12))
                    .foregroundStyle(SBTheme.muted)
            } else {
                ForEach(model.settings.mailSources) { src in
                    mailSourceRow(src)
                    if src.id != model.settings.mailSources.last?.id {
                        Divider().overlay(SBTheme.stroke)
                    }
                }
            }
        }
    }

    private func mailSourceRow(_ src: PlatformMailSource) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(src.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SBTheme.text)
                Text("发件人含 \(src.fromContains)")
                    .font(.system(size: 10))
                    .foregroundStyle(SBTheme.muted)
            }
            Spacer(minLength: 4)
            Button("试解析") {
                parseTarget = src
            }
            .buttonStyle(SBButtonStyle(kind: .normal))
            Toggle("", isOn: Binding(
                get: { src.enabled },
                set: { model.toggleMailSource(src.id, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            Button(role: .destructive) {
                model.removeMailSource(src.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(SBTheme.danger)
            }
            .buttonStyle(.plain)
        }
    }

    private var addMailSourceBlock: some View {
        settingsCard(title: "添加平台邮件源") {
            TextField("显示名称", text: $mailName)
                .textFieldStyle(.roundedBorder)
            TextField("发件人包含（必填）如 noreply@xxx.com", text: $mailFrom)
                .textFieldStyle(.roundedBorder)
            TextField("主题包含（可选）", text: $mailSubject)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("单位 ¥/$", text: $mailUnit)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                TextField("金额正则（可选，含一个捕获组）", text: $mailRegex)
                    .textFieldStyle(.roundedBorder)
            }
            Button("添加邮件源") {
                model.addMailSource(
                    displayName: mailName,
                    fromContains: mailFrom,
                    subjectContains: mailSubject,
                    unit: mailUnit,
                    regex: mailRegex
                )
                mailName = ""; mailFrom = ""; mailSubject = ""; mailRegex = ""
            }
            .buttonStyle(SBButtonStyle(kind: .accent))
            .disabled(mailFrom.isEmpty)
        }
    }

    private var imapBlock: some View {
        settingsCard(title: "IMAP 收件箱（读平台邮件）") {
            Toggle("启用 IMAP", isOn: $imapEnabled)
                .toggleStyle(.switch)
            TextField("IMAP 主机，如 imap.qq.com", text: $imapHost)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("端口", text: $imapPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Toggle("TLS（推荐 993）", isOn: $imapTLS)
                    .toggleStyle(.switch)
            }
            TextField("用户名 / 邮箱", text: $imapUser)
                .textFieldStyle(.roundedBorder)
            SecureField(model.hasIMAPPassword() ? "密码（留空不改）" : "密码 / 授权码", text: $imapPass)
                .textFieldStyle(.roundedBorder)
            TextField("文件夹", text: $imapFolder)
                .textFieldStyle(.roundedBorder)
            Button("保存 IMAP") {
                model.saveInboundMailbox(
                    enabled: imapEnabled,
                    host: imapHost,
                    port: Int(imapPort) ?? 993,
                    useTLS: imapTLS,
                    username: imapUser,
                    password: imapPass,
                    folder: imapFolder
                )
                imapPass = ""
            }
            .buttonStyle(SBButtonStyle(kind: .accent))
            Text("用于拉取平台发来的余额邮件。与下方「邮件报警」SMTP 可同一邮箱，也可分开。")
                .font(.system(size: 10))
                .foregroundStyle(SBTheme.muted)
        }
    }

    // MARK: - Alerts

    private var alertChannelsBlock: some View {
        settingsCard(title: "报警通道（智余如何通知你）") {
            Toggle(isOn: Binding(
                get: { model.settings.alertChannels.macNotificationEnabled },
                set: { model.setMacNotificationEnabled($0) }
            )) {
                labelStack(AlertChannel.macNotification.titleCN, AlertChannel.macNotification.subtitleCN)
            }
            .toggleStyle(.switch)

            Toggle(isOn: Binding(
                get: { model.settings.alertChannels.outboundEmailEnabled },
                set: { model.setOutboundEmailAlertEnabled($0) }
            )) {
                labelStack(AlertChannel.outboundEmail.titleCN, AlertChannel.outboundEmail.subtitleCN)
            }
            .toggleStyle(.switch)

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
    }

    private var outboundEmailBlock: some View {
        settingsCard(title: "邮件报警 SMTP（发出）") {
            TextField("SMTP 主机，如 smtp.qq.com", text: $smtpHost)
                .textFieldStyle(.roundedBorder)
            HStack {
                TextField("端口", text: $smtpPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Toggle("TLS（推荐 465）", isOn: $useTLS)
                    .toggleStyle(.switch)
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
                labeledField("金额阈值", text: $amountTh)
                labeledField("百分比阈值", text: $percentTh)
                labeledField("冷却秒", text: $cooldown)
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

    private var refreshBlock: some View {
        settingsCard(title: "刷新间隔") {
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
        settingsCard(title: "关于") {
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

    // MARK: - Helpers

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

    private func labelStack(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).foregroundStyle(SBTheme.text)
            Text(sub)
                .font(.system(size: 11))
                .foregroundStyle(SBTheme.muted)
        }
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(SBTheme.muted)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SBTheme.muted)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SBTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SBTheme.stroke, lineWidth: 1)
                )
        )
    }

    private func loadFields() {
        let box = model.settings.inboundMailbox
        imapEnabled = box.enabled
        imapHost = box.imapHost
        imapPort = String(box.imapPort)
        imapTLS = box.useTLS
        imapUser = box.username
        imapFolder = box.folder

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
