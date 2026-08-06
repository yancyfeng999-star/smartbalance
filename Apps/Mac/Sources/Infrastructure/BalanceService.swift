import Foundation
import Domain

/// 编排：API / 手录查余额 + Mac 通知 + 邮件报警。
public actor BalanceService {
    private let secrets: LocalSecretStore
    private let smtp: SMTPClient
    private let notifications: MacNotificationService

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
        var snapshots: [BalanceSnapshot] = []
        var alerts: [AlertEvent] = []
        var updated = settings

        // 智余本职就是查余额：始终刷新已启用账号（不再依赖「数据源」总开关）
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

        return (snapshots, alerts, updated)
    }

    public func refreshAPI(account: BalanceAccount, settings: AppSettings) async -> BalanceSnapshot {
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

        return await fetchViaProvider(
            account: account,
            settings: settings,
            credentials: ProviderCredentials(apiKey: secret, baseURL: account.baseURL, userId: account.userId)
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

    public func sendTestEmail(settings: EmailAlertSettings) async throws {
        let password = secrets.get(account: settings.passwordRef) ?? ""
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
