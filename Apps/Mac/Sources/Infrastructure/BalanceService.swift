import Foundation
import Domain

/// 编排：API / 手录查余额 + Mac 通知 + 邮件报警。
public actor BalanceService {
    private let secrets: LocalSecretStore
    private let smtp: SMTPClient
    private let notifications: MacNotificationService

    /// 单账号查询上限，超时返回失败卡，避免整页卡在「查询中」。
    private let perAccountTimeout: Duration = .seconds(15)
    /// 邮件发送上限；超时只记失败，不挡余额展示。
    private let smtpTimeout: Duration = .seconds(10)
    private let fetchLimiter = RefreshConcurrencyLimiter()

    public init(
        secrets: LocalSecretStore = .shared,
        smtp: SMTPClient = SMTPClient(),
        notifications: MacNotificationService = .shared
    ) {
        self.secrets = secrets
        self.smtp = smtp
        self.notifications = notifications
    }

    public func refreshAll(settings: AppSettings) async -> (snapshots: [BalanceSnapshot], alerts: [AlertEvent], settings: AppSettings) {
        var updated = settings
        let accounts = settings.enabledAccounts

        // 1) 并行查余额（互不阻塞）；先出结果再报警
        var snapsById: [UUID: BalanceSnapshot] = [:]
        await withTaskGroup(of: (UUID, BalanceSnapshot).self) { group in
            for account in accounts {
                group.addTask {
                    await self.fetchLimiter.withPermit {
                        let snap = await self.refreshAPIWithTimeout(account: account, settings: settings)
                        return (account.id, snap)
                    }
                }
            }
            for await (id, snap) in group {
                snapsById[id] = snap
            }
        }

        let snapshots = accounts.compactMap { snapsById[$0.id] }

        // 2) 报警（Mac 通知快；SMTP 有超时，挂住也不影响卡片）
        var alerts: [AlertEvent] = []
        for snap in snapshots {
            if let event = await dispatchAlerts(
                snapshot: snap,
                key: "api-\(snap.accountId.uuidString)",
                settings: &updated
            ) {
                alerts.append(event)
            }
        }

        return (snapshots, alerts, updated)
    }

    private func refreshAPIWithTimeout(account: BalanceAccount, settings: AppSettings) async -> BalanceSnapshot {
        do {
            return try await withTimeout(perAccountTimeout) {
                await self.refreshAPI(account: account, settings: settings)
            }
        } catch {
            return BalanceSnapshot(
                accountId: account.id,
                providerKind: account.kind,
                displayName: account.title,
                source: .api,
                status: .error,
                detail: "",
                errorMessage: "查询超时（\(Int(perAccountTimeout.components.seconds))s）"
            )
        }
    }

    public func refreshAPI(account: BalanceAccount, settings: AppSettings) async -> BalanceSnapshot {
        if !account.kind.isRecognized {
            return BalanceSnapshot(
                accountId: account.id,
                providerKind: account.kind,
                displayName: account.title,
                source: .api,
                unit: account.resolvedManualUnit,
                status: .setup,
                detail: "未识别的渠道，已跳过查询",
                errorMessage: "unrecognized provider"
            )
        }
        if account.kind.isManualEntry {
            return await fetchViaProvider(
                account: account,
                settings: settings,
                credentials: ProviderCredentials(apiKey: "", baseURL: account.baseURL, userId: account.userId)
            )
        }

        let secret = secrets.get(account: account.secretRef) ?? ""
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

        let apiBase = account.kind.resolveAPIBaseURL(accountBase: account.baseURL)
        return await fetchViaProvider(
            account: account,
            settings: settings,
            credentials: ProviderCredentials(apiKey: secret, baseURL: apiBase, userId: account.userId)
        )
    }

    private func fetchViaProvider(
        account: BalanceAccount,
        settings: AppSettings,
        credentials: ProviderCredentials
    ) async -> BalanceSnapshot {
        let provider = ProviderRegistry.provider(for: account.kind)
        do {
            var snap = try await provider.fetchBalance(account: account, credentials: credentials)
            snap.source = .api
            // 稳定列表身份
            snap.id = account.id
            let ch = settings.alertChannels
            // 账号级阈值只覆盖 warning；mid/critical 不得被 clamp 抬到大于 warning
            let warningAmt = account.alertThreshold ?? ch.warningAmount
            let midAmt = min(ch.midAmount, warningAmt)
            let critAmt = min(ch.criticalAmount, midAmt)
            let warnPct = account.alertPercentThreshold ?? ch.warningPercent
            let midPct = min(ch.midPercent, warnPct)
            let critPct = min(ch.criticalPercent, midPct)
            snap.status = BalanceSnapshot.resolveStatus(
                amount: snap.amount,
                remainingPercent: snap.remainingPercent,
                warningAmount: warningAmt,
                midAmount: midAmt,
                criticalAmount: critAmt,
                warningPercent: warnPct,
                midPercent: midPct,
                criticalPercent: critPct
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

    public func sendTestEmail(settings: EmailAlertSettings) async throws {
        let password = secrets.get(account: settings.passwordRef) ?? ""
        try await withTimeout(smtpTimeout) {
            try await self.smtp.sendTest(settings: settings, password: password)
        }
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
        if !force {
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
            let password = secrets.get(account: settings.email.passwordRef) ?? ""
            let emailSettings = settings.email
            let mailSubject = title
            let mailBody = message
            do {
                try await withTimeout(smtpTimeout) {
                    try await self.smtp.send(
                        settings: emailSettings,
                        password: password,
                        subject: mailSubject,
                        body: mailBody
                    )
                }
                emailed = true
            } catch {
                emailError = error.localizedDescription
                AppLog.error("SMTP alert failed: \(error.localizedDescription)")
            }
        }

        // 通知已出即可进冷却；邮件失败不反复刷（除非连通知都没有）
        if AlertCooldownPolicy.shouldEnterCooldown(notified: notified, emailed: emailed)
            || (notified && emailError != nil) {
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
        case .warning, .caution, .critical, .depleted: true
        default: false
        }
    }

    // MARK: - Timeout helper

    private func withTimeout<T: Sendable>(
        _ duration: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: duration)
                throw TimeoutError(seconds: duration.components.seconds)
            }
            guard let first = try await group.next() else {
                throw TimeoutError(seconds: duration.components.seconds)
            }
            group.cancelAll()
            return first
        }
    }
}

private struct TimeoutError: Error, LocalizedError {
    let seconds: Int64
    var errorDescription: String? { "操作超时（\(seconds)s）" }
}
