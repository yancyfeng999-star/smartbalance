import Foundation
import SwiftUI
import AppKit
import Domain
import Infrastructure

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var snapshots: [BalanceSnapshot] = []
    @Published var recentAlerts: [AlertEvent] = []
    @Published var isRefreshing = false
    @Published var lastRefreshAt: Date?
    @Published var banner: String?
    @Published var selectedTab: Tab = .home
    /// Mac 通知授权状态文案（设置页展示）。
    @Published var notificationStatusCaption: String = "系统未授权通知 · 点测试可再次请求"

    enum Tab: String {
        case home
        case settings
    }

    private let store = SettingsStore.shared
    private let keychain = KeychainStore.shared
    private let service = BalanceService()
    private var refreshTask: Task<Void, Never>?

    init() {
        self.settings = SettingsStore.shared.load()
        Task {
            _ = await MacNotificationService.shared.requestAuthorizationIfNeeded()
            await refreshNotificationStatus()
        }
        startAutoRefreshIfNeeded()
    }

    func refreshNotificationStatus() async {
        let status = await MacNotificationService.shared.authorizationStatus()
        notificationStatusCaption = MacNotificationService.statusCaption(for: status)
    }

    var statusLine: String {
        if isRefreshing { return "刷新中…" }
        if let lastRefreshAt {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            return "更新于 \(f.string(from: lastRefreshAt))"
        }
        return Brand.taglineCN
    }

    // MARK: - Data sources

    var apiQueryOn: Bool {
        get { settings.apiQueryEnabled }
        set {
            settings.apiQueryEnabled = newValue
            persist()
            startAutoRefreshIfNeeded()
        }
    }

    var platformMailOn: Bool {
        get { settings.platformMailEnabled }
        set {
            settings.platformMailEnabled = newValue
            persist()
            startAutoRefreshIfNeeded()
        }
    }

    // MARK: - Refresh

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        banner = nil
        Task {
            let result = await service.refreshAll(settings: settings)
            self.snapshots = result.snapshots.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            if !result.alerts.isEmpty {
                self.recentAlerts = Array((result.alerts + self.recentAlerts).prefix(20))
            }
            self.settings = result.settings
            self.lastRefreshAt = Date()
            self.isRefreshing = false
            try? store.save(self.settings)
        }
    }

    func startAutoRefreshIfNeeded() {
        refreshTask?.cancel()
        let anySource = settings.apiQueryEnabled || settings.platformMailEnabled
        guard anySource, settings.refreshIntervalSecs > 0 else { return }
        let interval = settings.refreshIntervalSecs
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            await self?.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    // MARK: - API accounts

    func addAccount(kind: ProviderKind, displayName: String, baseURL: String?, secret: String) {
        let account = BalanceAccount(kind: kind, displayName: displayName, baseURL: baseURL)
        if !secret.isEmpty {
            try? keychain.set(secret, account: account.secretRef)
        }
        settings.accounts.append(account)
        persist()
        refresh()
    }

    func removeAccount(_ id: UUID) {
        if let acc = settings.accounts.first(where: { $0.id == id }) {
            keychain.delete(account: acc.secretRef)
        }
        settings.accounts.removeAll { $0.id == id }
        snapshots.removeAll { $0.accountId == id }
        persist()
    }

    func toggleAccount(_ id: UUID, enabled: Bool) {
        guard let idx = settings.accounts.firstIndex(where: { $0.id == id }) else { return }
        settings.accounts[idx].enabled = enabled
        persist()
    }

    // MARK: - Platform mail sources

    func addMailSource(displayName: String, fromContains: String, subjectContains: String, unit: String, regex: String) {
        let src = PlatformMailSource(
            displayName: displayName.isEmpty ? fromContains : displayName,
            fromContains: fromContains,
            subjectContains: subjectContains,
            amountRegex: regex,
            unit: unit.isEmpty ? "¥" : unit
        )
        settings.mailSources.append(src)
        persist()
        refresh()
    }

    func removeMailSource(_ id: UUID) {
        settings.mailSources.removeAll { $0.id == id }
        snapshots.removeAll { $0.accountId == id }
        persist()
    }

    func toggleMailSource(_ id: UUID, enabled: Bool) {
        guard let idx = settings.mailSources.firstIndex(where: { $0.id == id }) else { return }
        settings.mailSources[idx].enabled = enabled
        persist()
    }

    /// 粘贴邮件试解析（不访问 IMAP）。
    func parsePastedMail(source: PlatformMailSource, subject: String, body: String) async -> BalanceSnapshot {
        await service.parsePastedMail(
            source: source,
            subject: subject,
            body: body,
            settings: settings
        )
    }

    /// 将试解析金额写入该平台源缓存，并更新首页卡片。
    func writeLastParsedAmount(sourceId: UUID, amount: Double) {
        guard let idx = settings.mailSources.firstIndex(where: { $0.id == sourceId }) else { return }
        settings.mailSources[idx].lastParsedAmount = amount
        settings.mailSources[idx].lastParsedAt = Date()
        let src = settings.mailSources[idx]
        persist()

        let th = src.alertThreshold ?? settings.alertChannels.defaultAmountThreshold
        let status = BalanceSnapshot.resolveStatus(
            amount: amount,
            remainingPercent: nil,
            amountThreshold: th,
            percentThreshold: settings.alertChannels.defaultPercentThreshold
        )
        let snap = BalanceSnapshot(
            accountId: sourceId,
            displayName: src.displayName,
            source: .platformEmail,
            amount: amount,
            unit: src.unit,
            status: status,
            detail: "试解析写入",
            mailSubject: nil
        )
        if let sIdx = snapshots.firstIndex(where: { $0.accountId == sourceId }) {
            snapshots[sIdx] = snap
        } else {
            snapshots.append(snap)
            snapshots.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }
        banner = "已写入 \(src.displayName) 上次金额 \(snap.primaryText)"
    }

    func saveInboundMailbox(
        enabled: Bool,
        host: String,
        port: Int,
        useTLS: Bool,
        username: String,
        password: String,
        folder: String
    ) {
        settings.inboundMailbox.enabled = enabled
        settings.inboundMailbox.imapHost = host
        settings.inboundMailbox.imapPort = port
        settings.inboundMailbox.useTLS = useTLS
        settings.inboundMailbox.username = username
        settings.inboundMailbox.folder = folder.isEmpty ? "INBOX" : folder
        if !password.isEmpty {
            try? keychain.set(password, account: settings.inboundMailbox.passwordRef)
        }
        persist()
        banner = "IMAP 收件箱已保存"
    }

    // MARK: - Alert channels

    func setMacNotificationEnabled(_ on: Bool) {
        settings.alertChannels.macNotificationEnabled = on
        persist()
        if on {
            Task {
                _ = await MacNotificationService.shared.requestAuthorizationIfNeeded()
                await refreshNotificationStatus()
            }
        }
    }

    func setOutboundEmailAlertEnabled(_ on: Bool) {
        settings.alertChannels.outboundEmailEnabled = on
        settings.email.enabled = on
        persist()
    }

    func setRefreshInterval(_ secs: Int) {
        settings.refreshIntervalSecs = secs
        persist()
        startAutoRefreshIfNeeded()
    }

    func saveOutboundEmail(
        host: String,
        port: Int,
        useTLS: Bool,
        username: String,
        password: String,
        from: String,
        to: String,
        amountThreshold: Double,
        percentThreshold: Double,
        cooldownSeconds: Int
    ) {
        settings.email.smtpHost = host
        settings.email.smtpPort = port
        settings.email.useTLS = useTLS
        settings.email.username = username
        settings.email.fromAddress = from
        settings.email.toAddresses = to
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        settings.email.defaultAmountThreshold = amountThreshold
        settings.email.defaultPercentThreshold = percentThreshold
        settings.email.cooldownSeconds = cooldownSeconds
        settings.alertChannels.defaultAmountThreshold = amountThreshold
        settings.alertChannels.defaultPercentThreshold = percentThreshold
        settings.alertChannels.cooldownSeconds = cooldownSeconds
        settings.email.enabled = settings.alertChannels.outboundEmailEnabled
        if !password.isEmpty {
            try? keychain.set(password, account: settings.email.passwordRef)
        }
        persist()
        banner = "邮件报警设置已保存"
    }

    func sendTestEmail() {
        Task {
            do {
                try await service.sendTestEmail(settings: settings.email)
                banner = "测试邮件已发送"
            } catch {
                banner = "测试邮件失败：\(error.localizedDescription)"
            }
        }
    }

    /// 测试按钮必达：不依赖余额状态，始终请求权限并投递测试通知。
    func sendTestMacNotification() {
        Task {
            let granted = await MacNotificationService.shared.requestAuthorizationIfNeeded()
            await refreshNotificationStatus()
            if granted {
                await service.sendTestMacNotification()
                banner = "已发送测试 Mac 通知"
            } else {
                banner = notificationStatusCaption
            }
        }
    }

    func hasSecret(for account: BalanceAccount) -> Bool {
        !(keychain.get(account: account.secretRef) ?? "").isEmpty
    }

    func hasIMAPPassword() -> Bool {
        !(keychain.get(account: settings.inboundMailbox.passwordRef) ?? "").isEmpty
    }

    func persist() {
        try? store.save(settings)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
