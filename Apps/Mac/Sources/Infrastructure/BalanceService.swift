import Foundation
import Domain

/// 编排：API 查余额 + 平台邮件解析 + Mac 通知 + 邮件报警。
public actor BalanceService {
    private let keychain: KeychainStore
    private let smtp: SMTPClient
    private let imap: IMAPClient
    private let notifications: MacNotificationService

    public init(
        keychain: KeychainStore = .shared,
        smtp: SMTPClient = SMTPClient(),
        imap: IMAPClient = IMAPClient(),
        notifications: MacNotificationService = .shared
    ) {
        self.keychain = keychain
        self.smtp = smtp
        self.imap = imap
        self.notifications = notifications
    }

    public func refreshAll(settings: AppSettings) async -> (snapshots: [BalanceSnapshot], alerts: [AlertEvent], settings: AppSettings) {
        var snapshots: [BalanceSnapshot] = []
        var alerts: [AlertEvent] = []
        var updated = settings

        // ① API 直查
        if settings.apiQueryEnabled {
            for account in settings.enabledAccounts {
                let snap = await refreshAPI(account: account, settings: settings)
                snapshots.append(snap)
                if let event = await dispatchAlerts(snapshot: snap, key: account.id.uuidString, settings: &updated) {
                    alerts.append(event)
                }
            }
        }

        // ② 平台固定邮件
        if settings.platformMailEnabled {
            let mailResult = await refreshPlatformMail(settings: &updated)
            snapshots.append(contentsOf: mailResult.snapshots)
            alerts.append(contentsOf: mailResult.alerts)
        }

        return (snapshots, alerts, updated)
    }

    public func refreshAPI(account: BalanceAccount, settings: AppSettings) async -> BalanceSnapshot {
        let secret = keychain.get(account: account.secretRef) ?? ""
        if secret.isEmpty {
            return BalanceSnapshot(
                accountId: account.id,
                providerKind: account.kind,
                displayName: account.title,
                source: .api,
                status: .setup,
                detail: account.kind.credentialHintCN,
                errorMessage: "未配置密钥"
            )
        }

        let creds = ProviderCredentials(apiKey: secret, baseURL: account.baseURL)
        let provider = ProviderRegistry.provider(for: account.kind)
        do {
            var snap = try await provider.fetchBalance(account: account, credentials: creds)
            snap.source = .api
            let amountTh = account.alertThreshold ?? settings.alertChannels.defaultAmountThreshold
            let percentTh = account.alertPercentThreshold ?? settings.alertChannels.defaultPercentThreshold
            snap.status = BalanceSnapshot.resolveStatus(
                amount: snap.amount,
                remainingPercent: snap.remainingPercent,
                amountThreshold: amountTh,
                percentThreshold: percentTh
            )
            return snap
        } catch {
            return BalanceSnapshot(
                accountId: account.id,
                providerKind: account.kind,
                displayName: account.title,
                source: .api,
                status: .error,
                detail: "",
                errorMessage: error.localizedDescription
            )
        }
    }

    public func refreshPlatformMail(settings: inout AppSettings) async -> (snapshots: [BalanceSnapshot], alerts: [AlertEvent]) {
        var snapshots: [BalanceSnapshot] = []
        var alerts: [AlertEvent] = []

        let sources = settings.enabledMailSources
        guard !sources.isEmpty else { return ([], []) }

        guard settings.inboundMailbox.isConfigured else {
            for src in sources {
                snapshots.append(BalanceSnapshot(
                    accountId: src.id,
                    displayName: src.displayName,
                    source: .platformEmail,
                    amount: src.lastParsedAmount,
                    unit: src.unit,
                    status: .setup,
                    detail: "请先配置 IMAP 收件箱",
                    errorMessage: "IMAP 未配置",
                    mailSubject: nil
                ))
            }
            return (snapshots, [])
        }

        let password = keychain.get(account: settings.inboundMailbox.passwordRef) ?? ""
        guard !password.isEmpty else {
            for src in sources {
                snapshots.append(BalanceSnapshot(
                    accountId: src.id,
                    displayName: src.displayName,
                    source: .platformEmail,
                    status: .setup,
                    detail: "请填写 IMAP 密码/授权码",
                    errorMessage: "缺少 IMAP 密码"
                ))
            }
            return (snapshots, [])
        }

        let box = settings.inboundMailbox
        let messages: [FetchedMailMessage]
        do {
            messages = try await imap.fetchRecent(
                host: box.imapHost,
                port: box.imapPort,
                useTLS: box.useTLS,
                username: box.username,
                password: password,
                folder: box.folder,
                maxMessages: box.maxMessages
            )
        } catch {
            for src in sources {
                snapshots.append(BalanceSnapshot(
                    accountId: src.id,
                    displayName: src.displayName,
                    source: .platformEmail,
                    amount: src.lastParsedAmount,
                    unit: src.unit,
                    status: .error,
                    detail: src.lastParsedAmount != nil ? "沿用上次解析结果" : "",
                    errorMessage: error.localizedDescription
                ))
            }
            return (snapshots, [])
        }

        for src in sources {
            guard let idx = settings.mailSources.firstIndex(where: { $0.id == src.id }) else { continue }
            let matched = messages
                .filter { BalanceMailParser.matches(message: $0, source: src) }
                .reversed() // 最新优先（fetch 通常升序）

            guard let best = matched.first else {
                // 无新匹配：展示缓存
                if let amount = settings.mailSources[idx].lastParsedAmount {
                    let th = src.alertThreshold ?? settings.alertChannels.defaultAmountThreshold
                    let status = BalanceSnapshot.resolveStatus(
                        amount: amount,
                        remainingPercent: nil,
                        amountThreshold: th,
                        percentThreshold: settings.alertChannels.defaultPercentThreshold
                    )
                    snapshots.append(BalanceSnapshot(
                        accountId: src.id,
                        displayName: src.displayName,
                        source: .platformEmail,
                        amount: amount,
                        unit: src.unit,
                        status: status,
                        detail: "暂无新匹配邮件 · 显示上次结果",
                        fetchedAt: settings.mailSources[idx].lastParsedAt ?? Date()
                    ))
                } else {
                    snapshots.append(BalanceSnapshot(
                        accountId: src.id,
                        displayName: src.displayName,
                        source: .platformEmail,
                        status: .unknown,
                        detail: "收件箱中未匹配到：发件人含「\(src.fromContains)」"
                    ))
                }
                continue
            }

            let text = best.subject + "\n" + best.body
            let amount = BalanceMailParser.extractAmount(from: text, customRegex: src.amountRegex)
            let platformAlert = BalanceMailParser.looksLikeAlert(subject: best.subject, body: best.body)
            let th = src.alertThreshold ?? settings.alertChannels.defaultAmountThreshold
            let status: BalanceStatus = {
                if let amount {
                    return BalanceSnapshot.resolveStatus(
                        amount: amount,
                        remainingPercent: nil,
                        amountThreshold: th,
                        percentThreshold: settings.alertChannels.defaultPercentThreshold
                    )
                }
                return platformAlert ? .warning : .unknown
            }()

            let isNewMail = settings.mailSources[idx].lastMessageId != best.id
            if let amount {
                settings.mailSources[idx].lastParsedAmount = amount
                settings.mailSources[idx].lastParsedAt = Date()
            }
            settings.mailSources[idx].lastMessageId = best.id

            let snap = BalanceSnapshot(
                accountId: src.id,
                displayName: src.displayName,
                source: .platformEmail,
                amount: amount ?? settings.mailSources[idx].lastParsedAmount,
                unit: src.unit,
                status: status,
                detail: "来自 \(best.from)",
                mailSubject: best.subject
            )
            snapshots.append(snap)

            // 新邮件 +（余额偏低或平台报警信）→ 报警
            let should = isNewMail && (shouldAlert(status: status) || platformAlert)
            if should {
                if let event = await dispatchAlerts(
                    snapshot: snap,
                    key: "mail-\(src.id.uuidString)",
                    settings: &settings,
                    force: true,
                    extraNote: platformAlert ? "平台邮件含报警关键词" : nil
                ) {
                    alerts.append(event)
                }
            }
        }

        return (snapshots, alerts)
    }

    /// 粘贴邮件正文试解析（不写 IMAP）。
    public func parsePastedMail(
        source: PlatformMailSource,
        subject: String,
        body: String,
        settings: AppSettings
    ) -> BalanceSnapshot {
        let text = subject + "\n" + body
        let amount = BalanceMailParser.extractAmount(from: text, customRegex: source.amountRegex)
        let th = source.alertThreshold ?? settings.alertChannels.defaultAmountThreshold
        let status = BalanceSnapshot.resolveStatus(
            amount: amount,
            remainingPercent: nil,
            amountThreshold: th,
            percentThreshold: settings.alertChannels.defaultPercentThreshold
        )
        return BalanceSnapshot(
            accountId: source.id,
            displayName: source.displayName,
            source: .platformEmail,
            amount: amount,
            unit: source.unit,
            status: amount == nil ? .unknown : status,
            detail: amount == nil ? "未能从正文提取金额，可调整正则" : "试解析成功",
            errorMessage: amount == nil ? "解析失败" : nil,
            mailSubject: subject
        )
    }

    public func sendTestEmail(settings: EmailAlertSettings) async throws {
        let password = keychain.get(account: settings.passwordRef) ?? ""
        try await smtp.sendTest(settings: settings, password: password)
    }

    public func sendTestMacNotification() async {
        await notifications.post(
            title: "【\(Brand.nameCN)】测试通知",
            body: "Mac 通知通道正常。余额异常时会在此提醒。",
            id: "test-\(UUID().uuidString)"
        )
    }

    // MARK: - Alerts

    private func dispatchAlerts(
        snapshot: BalanceSnapshot,
        key: String,
        settings: inout AppSettings,
        force: Bool = false,
        extraNote: String? = nil
    ) async -> AlertEvent? {
        guard force || shouldAlert(status: snapshot.status) else { return nil }

        let channels = settings.alertChannels
        guard channels.macNotificationEnabled || (channels.outboundEmailEnabled && settings.email.enabled) else {
            return nil
        }

        let cooldown = TimeInterval(channels.cooldownSeconds)
        if !force, let last = settings.lastAlertAtByAccount[key], Date().timeIntervalSince(last) < cooldown {
            return nil
        }

        let title = "【\(Brand.nameCN)】\(snapshot.displayName) 余额关注"
        var message = """
        名称：\(snapshot.displayName)
        来源：\(snapshot.source.titleCN)
        余额：\(snapshot.primaryText)
        状态：\(snapshot.status.titleCN)
        详情：\(snapshot.detail)
        """
        if let sub = snapshot.mailSubject { message += "\n邮件主题：\(sub)" }
        if let note = extraNote { message += "\n说明：\(note)" }
        if let err = snapshot.errorMessage { message += "\n错误：\(err)" }
        message += "\n时间：\(ISO8601DateFormatter().string(from: snapshot.fetchedAt))\n\n— \(Brand.nameCN)"

        var emailed = false
        var notified = false

        if channels.macNotificationEnabled {
            await notifications.post(title: title, body: "\(snapshot.primaryText) · \(snapshot.status.titleCN)", id: key)
            notified = true
        }

        if channels.outboundEmailEnabled && settings.email.enabled && settings.email.isConfigured {
            let password = keychain.get(account: settings.email.passwordRef) ?? ""
            do {
                try await smtp.send(
                    settings: settings.email,
                    password: password,
                    subject: title,
                    body: message
                )
                emailed = true
            } catch {
                return AlertEvent(
                    accountId: snapshot.accountId,
                    title: title,
                    message: "邮件发送失败：\(error.localizedDescription)\n\n\(message)",
                    emailed: false,
                    notified: notified,
                    source: snapshot.source
                )
            }
        }

        settings.lastAlertAtByAccount[key] = Date()
        return AlertEvent(
            accountId: snapshot.accountId,
            title: title,
            message: message,
            emailed: emailed,
            notified: notified,
            source: snapshot.source
        )
    }

    private func shouldAlert(status: BalanceStatus) -> Bool {
        switch status {
        case .warning, .critical, .depleted: true
        default: false
        }
    }
}
