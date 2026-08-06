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
                if let event = await dispatchAlerts(
                    snapshot: snap,
                    key: "api-\(account.id.uuidString)",
                    settings: &updated
                ) {
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
                snapshots.append(PlatformMailIngest.snapshotOnIMAPFailure(
                    source: src,
                    errorMessage: error.localizedDescription
                ))
            }
            return (snapshots, [])
        }

        for src in sources {
            guard let idx = settings.mailSources.firstIndex(where: { $0.id == src.id }) else { continue }
            let amountTh = src.alertThreshold ?? settings.alertChannels.defaultAmountThreshold
            let percentTh = settings.alertChannels.defaultPercentThreshold
            let result = PlatformMailIngest.ingest(
                source: settings.mailSources[idx],
                messages: messages,
                thresholds: (amount: amountTh, percent: percentTh)
            )
            // 写入金额缓存等；lastMessageId 在无需报警时已由 ingest 提交
            settings.mailSources[idx] = result.updatedSource
            snapshots.append(result.snapshot)

            // 新 Message-ID +（偏低/危急/耗尽 或 平台报警信）→ 双通道报警（去重由 ingest 判定）
            // lastMessageId 仅在至少一条通道成功后再提交，双失败则保留旧 ID 以便下次重试
            if result.shouldAlert {
                if let event = await dispatchAlerts(
                    snapshot: result.snapshot,
                    key: "mail-\(src.id.uuidString)",
                    settings: &settings,
                    force: true,
                    extraNote: result.alertNote
                ) {
                    alerts.append(event)
                    if MailIngestResult.shouldCommitLastMessageId(
                        shouldAlert: true,
                        notified: event.notified,
                        emailed: event.emailed
                    ), let mid = result.pendingMessageId {
                        settings.mailSources[idx].lastMessageId = mid
                    }
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
        // force：平台报警邮件；否则需开启「额度阈值报警」且状态偏低/危急/耗尽
        if force {
            // always continue
        } else {
            guard settings.alertChannels.quotaThresholdAlertsEnabled else { return nil }
            guard shouldAlert(status: snapshot.status) else { return nil }
        }

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
        var emailError: String?

        if channels.macNotificationEnabled {
            notified = await notifications.post(
                title: title,
                body: "\(snapshot.primaryText) · \(snapshot.status.titleCN)",
                id: key
            )
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
                emailError = error.localizedDescription
            }
        }

        // 仅通知成功或邮件成功之一才写冷却；两者都失败 → 可立即重试
        if AlertCooldownPolicy.shouldEnterCooldown(notified: notified, emailed: emailed) {
            settings.lastAlertAtByAccount[key] = Date()
        }

        var finalMessage = message
        if let emailError {
            finalMessage = "邮件发送失败：\(emailError)\n\n\(message)"
        }

        return AlertEvent(
            accountId: snapshot.accountId,
            title: title,
            message: finalMessage,
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
