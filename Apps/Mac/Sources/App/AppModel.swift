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
    private let secrets = LocalSecretStore.shared
    private let service = BalanceService()
    private var refreshTask: Task<Void, Never>?

    @Published var launchAtLoginEnabled: Bool = LaunchAtLogin.isEnabled
    @Published var updateChecking = false
    @Published var updateMessage: String?
    @Published var updateOpenURL: URL?
    @Published var updateDownloadURL: URL?
    @Published var updateAvailable = false
    /// 0…1 下载进度；nil 表示未在下载
    @Published var updateDownloadProgress: Double?

    private let updateChecker = UpdateChecker()

    /// 置顶窗是否打开（驱动图钉高亮；与磁盘标志解耦）
    @Published var pinWindowOpen = false

    init() {
        var loaded = SettingsStore.shared.load()
        // 旧版曾有「数据源」总开关；关掉会让软件空转。启动时强制开启。
        if !loaded.apiQueryEnabled {
            loaded.apiQueryEnabled = true
            try? SettingsStore.shared.save(loaded)
        }
        // 启动时置顶窗未打开，图钉应灭；清掉上次会话残留标志
        if loaded.windowPinned {
            loaded.windowPinned = false
            try? SettingsStore.shared.save(loaded)
        }
        self.settings = loaded
        self.pinWindowOpen = false
        self.launchAtLoginEnabled = LaunchAtLogin.isEnabled
        AppLog.info("App launch · accounts=\(settings.accounts.count) interval=\(settings.refreshIntervalSecs)s")
        Task { @MainActor in
            MacNotificationService.shared.installDelegateIfNeeded()
            _ = await MacNotificationService.shared.requestAuthorizationIfNeeded()
            await refreshNotificationStatus()
            rescheduleManualReminders()
        }
        startAutoRefreshIfNeeded()
    }

    func refreshNotificationStatus() async {
        let status = await MacNotificationService.shared.authorizationStatus()
        notificationStatusCaption = MacNotificationService.statusCaption(for: status)
    }

    /// 顶栏刷新按钮左侧：仅时间（如「刷新 15:21」）。
    var refreshTimeText: String {
        if let lastRefreshAt {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return "刷新 \(f.string(from: lastRefreshAt))"
        }
        return "—"
    }

    /// 打开当前首个已启用账号对应控制台；无账号时提示。
    func openDashboard() {
        guard let account = settings.enabledAccounts.first else {
            banner = "请先添加 API 账号"
            selectedTab = .settings
            return
        }
        let urlString: String? = {
            switch account.kind {
            case .deepseek:
                return "https://platform.deepseek.com"
            case .openrouter:
                return "https://openrouter.ai/activity"
            case .viraltok:
                return "https://www.viraltok.ai"
            case .laozhang:
                return "https://api2.laozhang.ai"
            case .dmxapi:
                return "https://www.dmxapi.cn"
            case .kimi:
                return "https://platform.kimi.com/console/api-keys"
            case .volcengine:
                return "https://console.volcengine.com/finance/account-overview/"
            case .mimo:
                return "https://platform.xiaomimimo.com/console/balance"
            case .minimax:
                return "https://platform.minimaxi.com/user-center/payment/balance"
            case .newapi:
                let base = (account.baseURL ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return base.isEmpty ? nil : base
            }
        }()
        guard let urlString, let url = URL(string: urlString) else {
            banner = "无法打开 \(account.kind.displayName) 后台地址"
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Refresh

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        banner = nil
        // 兼容旧设置：若用户曾关掉「数据源」总开关，强制恢复（产品本职就是查余额）
        if !settings.apiQueryEnabled {
            settings.apiQueryEnabled = true
            try? store.save(settings)
        }
        AppLog.info("Refresh start · accounts=\(settings.enabledAccounts.count)")
        Task {
            // 仅当有「需要密钥的 API 账号」或 SMTP 报警密码时才解锁密钥库。
            let hasKeyAccounts = settings.enabledAccounts.contains { !$0.kind.isManualEntry }
            let needsSecrets = hasKeyAccounts || settings.alertChannels.outboundEmailEnabled
            if needsSecrets {
                do {
                    try await secrets.unlockSessionIfNeeded(
                        reason: "智余需要验证身份以读取 API 密钥与报警邮箱密码"
                    )
                } catch {
                    self.banner = "未通过验证：\(error.localizedDescription)（可用指纹或本机密码）"
                    self.isRefreshing = false
                    AppLog.error("Secret unlock failed: \(error.localizedDescription)")
                    return
                }
            }

            let result = await service.refreshAll(settings: settings)
            self.snapshots = result.snapshots.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            if !result.alerts.isEmpty {
                self.recentAlerts = Array((result.alerts + self.recentAlerts).prefix(20))
                if let fail = result.alerts.first(where: {
                    !$0.emailed && $0.message.hasPrefix("邮件发送失败")
                }) {
                    let firstLine = fail.message.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? fail.message
                    self.banner = firstLine
                    AppLog.error(firstLine)
                }
                for a in result.alerts {
                    AppLog.info("Alert: \(a.title) notified=\(a.notified) emailed=\(a.emailed)")
                }
            }
            self.settings = result.settings
            self.lastRefreshAt = Date()
            self.isRefreshing = false
            try? store.save(self.settings)
            AppLog.info("Refresh done · cards=\(self.snapshots.count)")
        }
    }

    func startAutoRefreshIfNeeded() {
        refreshTask?.cancel()
        guard settings.refreshIntervalSecs > 0 else { return }
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

    func addAccount(
        kind: ProviderKind,
        displayName: String,
        baseURL: String?,
        userId: String? = nil,
        secret: String,
        manualAmount: Double? = nil
    ) {
        let account = BalanceAccount(
            kind: kind,
            displayName: displayName,
            baseURL: baseURL,
            userId: userId,
            manualAmount: kind.isManualEntry ? manualAmount : nil,
            manualUnit: kind.isManualEntry ? kind.defaultManualUnit : nil,
            manualUpdatedAt: (kind.isManualEntry && manualAmount != nil) ? Date() : nil,
            dailyReminderEnabled: kind.isManualEntry ? true : nil
        )
        if kind.needsSecret, !secret.isEmpty {
            do {
                try secrets.set(secret, account: account.secretRef)
            } catch {
                banner = "密钥保存失败：\(error.localizedDescription)"
                return
            }
        }
        settings.accounts.append(account)
        persist()
        rescheduleManualReminders()
        banner = kind.isManualEntry ? "已添加手录账号 · 每天 10:00 提醒核对" : "账号已保存"
        refresh()
    }

    func removeAccount(_ id: UUID) {
        if let acc = settings.accounts.first(where: { $0.id == id }) {
            secrets.delete(account: acc.secretRef)
        }
        settings.accounts.removeAll { $0.id == id }
        snapshots.removeAll { $0.accountId == id }
        persist()
        rescheduleManualReminders()
    }

    /// 给已有账号补填/更新密钥（不必删号重加）。
    func updateAccountSecret(id: UUID, secret: String) {
        guard let acc = settings.accounts.first(where: { $0.id == id }) else { return }
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            banner = "密钥不能为空"
            return
        }
        do {
            try secrets.set(trimmed, account: acc.secretRef)
            banner = "已更新 \(acc.title) 的密钥"
            objectWillChange.send()
            refresh()
        } catch {
            banner = "密钥保存失败：\(error.localizedDescription)"
        }
    }

    /// 补填 / 修改用户 ID（New-API、DMXAPI 等需要）。
    func updateAccountUserId(id: UUID, userId: String) {
        guard let idx = settings.accounts.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            banner = "用户 ID 不能为空"
            return
        }
        settings.accounts[idx].userId = trimmed
        persist()
        banner = "已更新 \(settings.accounts[idx].title) 的用户 ID"
        refresh()
    }

    /// 手录余额（MiMo / MiniMax）。
    func updateManualAmount(id: UUID, amountText: String, unit: String? = nil) {
        guard let idx = settings.accounts.firstIndex(where: { $0.id == id }) else { return }
        let cleaned = amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: "$", with: "")
        guard let value = Double(cleaned) else {
            banner = "请输入有效数字金额"
            return
        }
        settings.accounts[idx].manualAmount = value
        if let unit, !unit.isEmpty {
            settings.accounts[idx].manualUnit = unit
        } else if settings.accounts[idx].manualUnit == nil {
            settings.accounts[idx].manualUnit = settings.accounts[idx].kind.defaultManualUnit
        }
        settings.accounts[idx].manualUpdatedAt = Date()
        persist()
        banner = "已更新 \(settings.accounts[idx].title)：\(settings.accounts[idx].resolvedManualUnit)\(String(format: "%.2f", value))"
        refresh()
    }

    func setDailyReminder(id: UUID, enabled: Bool) {
        guard let idx = settings.accounts.firstIndex(where: { $0.id == id }) else { return }
        settings.accounts[idx].dailyReminderEnabled = enabled
        persist()
        rescheduleManualReminders()
    }

    func toggleAccount(_ id: UUID, enabled: Bool) {
        guard let idx = settings.accounts.firstIndex(where: { $0.id == id }) else { return }
        settings.accounts[idx].enabled = enabled
        persist()
        rescheduleManualReminders()
    }

    /// 每天 10:00 提醒手录账号打开网页核对并更新金额。
    func rescheduleManualReminders() {
        let names = settings.accounts
            .filter { $0.enabled && $0.kind.isManualEntry && $0.wantsDailyReminder }
            .map(\.title)
        Task {
            _ = await MacNotificationService.shared.requestAuthorizationIfNeeded()
            await MacNotificationService.shared.scheduleDailyManualBalanceReminder(
                hour: 10,
                minute: 0,
                names: names
            )
        }
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
        AppLog.info("Background sync interval → \(secs)s")
        startAutoRefreshIfNeeded()
    }

    func setRefreshInterval(_ interval: RefreshInterval) {
        setRefreshInterval(interval.seconds ?? 0)
    }

    func setQuotaThresholdAlertsEnabled(_ on: Bool) {
        settings.alertChannels.quotaThresholdAlertsEnabled = on
        persist()
    }

    func setAmountThreshold(_ value: Double) {
        setWarningAmount(value)
    }

    func setPercentThreshold(_ value: Double) {
        setWarningPercent(value)
    }

    func setWarningAmount(_ value: Double) {
        let v = max(1, value)
        settings.alertChannels.warningAmount = v
        if settings.alertChannels.criticalAmount > v {
            settings.alertChannels.criticalAmount = max(1, v * 0.25)
        }
        settings.email.defaultAmountThreshold = v
        persist()
        refresh()
    }

    func setCriticalAmount(_ value: Double) {
        let w = settings.alertChannels.warningAmount
        settings.alertChannels.criticalAmount = min(max(1, value), w)
        persist()
        refresh()
    }

    func setWarningPercent(_ value: Double) {
        let v = max(1, min(99, value))
        settings.alertChannels.warningPercent = v
        if settings.alertChannels.criticalPercent > v {
            settings.alertChannels.criticalPercent = max(1, v * 0.5)
        }
        settings.email.defaultPercentThreshold = v
        persist()
        refresh()
    }

    func setCriticalPercent(_ value: Double) {
        let w = settings.alertChannels.warningPercent
        settings.alertChannels.criticalPercent = min(max(1, value), w)
        persist()
        refresh()
    }

    func setLaunchAtLogin(_ on: Bool) {
        if LaunchAtLogin.setEnabled(on) {
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
        } else {
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
            banner = "无法修改「登录时启动」，请在 系统设置 → 通用 → 登录项 中检查"
        }
    }

    func openLogs() {
        AppLog.info("User opened logs folder")
        AppLog.revealInFinder()
    }

    func checkForUpdates() {
        guard !updateChecking else { return }
        updateChecking = true
        updateMessage = nil
        updateOpenURL = nil
        updateDownloadURL = nil
        updateAvailable = false
        updateDownloadProgress = nil
        Task {
            let result = await updateChecker.check()
            await MainActor.run {
                self.updateMessage = result.message
                self.updateOpenURL = result.openURL
                self.updateDownloadURL = result.downloadURL
                self.updateAvailable = result.status == .available
                AppLog.info("Update check: \(result.message)")
            }
            // 对齐智额：发现新版本 → 自动下载 → 打开 → 退出
            if result.status == .available {
                await downloadAndOpenUpdate(result: result)
            } else {
                await MainActor.run { self.updateChecking = false }
            }
        }
    }

    @MainActor
    private func downloadAndOpenUpdate(result: UpdateCheckResult) async {
        guard let remote = result.downloadURL else {
            updateChecking = false
            updateMessage = (result.message) + "（无 zip，打开发布页）"
            if let page = result.openURL {
                NSWorkspace.shared.open(page)
            }
            return
        }
        updateMessage = "正在下载 \(result.latestVersion ?? "")…"
        updateDownloadProgress = 0
        do {
            let file = try await ReleaseDownloader().download(from: remote) { [weak self] fraction in
                Task { @MainActor in
                    self?.updateDownloadProgress = fraction
                    self?.updateMessage = "下载中 \(Int((fraction * 100).rounded()))%"
                }
            }
            updateDownloadProgress = 1
            updateMessage = "已下载，正在打开…"
            updateChecking = false
            NSWorkspace.shared.open(file)
            try? await Task.sleep(nanoseconds: 800_000_000)
            NSApp.terminate(nil)
        } catch {
            updateChecking = false
            updateDownloadProgress = nil
            updateMessage = "下载失败：\(error.localizedDescription)"
            if let page = result.openURL {
                NSWorkspace.shared.open(page)
            }
        }
    }

    func openUpdateURL() {
        if let url = updateDownloadURL ?? updateOpenURL {
            NSWorkspace.shared.open(url)
        }
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0"
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
            do {
                try secrets.set(password, account: settings.email.passwordRef)
            } catch {
                banner = "SMTP 密码保存失败：\(error.localizedDescription)"
                return
            }
        }
        persist()
        banner = "邮件报警设置已保存"
    }

    /// 测试按钮：始终请求权限并投递；结果弹窗 + 首页 banner，避免「没反应」。
    func sendTestMacNotification() {
        Task {
            let granted = await MacNotificationService.shared.requestAuthorizationIfNeeded()
            await refreshNotificationStatus()
            if granted {
                let ok = await MacNotificationService.shared.post(
                    title: "【\(Brand.nameCN)】测试通知",
                    body: "Mac 通知通道正常。余额异常时会在此提醒。",
                    id: "test-mac"
                )
                let msg = ok ? "已发送测试 Mac 通知，请看右上角横幅" : "调度失败，请查看日志"
                banner = msg
                presentAlert(title: "Mac 通知", message: msg)
                AppLog.info("Test Mac notification ok=\(ok)")
            } else {
                let msg = notificationStatusCaption
                banner = msg
                presentAlert(title: "Mac 通知未授权", message: msg + "\n\n可在「系统设置 → 通知 → 智余」中打开。")
            }
        }
    }

    func sendTestEmail() {
        Task {
            do {
                try await service.sendTestEmail(settings: settings.email)
                let msg = "测试邮件已发送，请查收件箱"
                banner = msg
                presentAlert(title: "报警邮件", message: msg)
                AppLog.info("Test email sent")
            } catch {
                let msg = "测试邮件失败：\(error.localizedDescription)"
                banner = msg
                presentAlert(title: "报警邮件失败", message: msg + "\n\n请确认 SMTP 主机/端口/授权码/发件收件人已保存。")
                AppLog.error(msg)
            }
        }
    }

    /// 已存密钥的掩码展示（两端可见）。未解锁会话时只提示「已保存」。
    func maskedSecret(for account: BalanceAccount) -> String? {
        if let s = secrets.get(account: account.secretRef), !s.isEmpty {
            // 火山 AK/SK 两行：只遮罩展示 AK
            if account.kind.needsAccessKeyPair,
               let pair = VolcengineSigner.unpackCredentials(s) {
                return "AK " + SecretMask.display(pair.accessKeyId)
            }
            return SecretMask.display(s)
        }
        if secrets.contains(account: account.secretRef) {
            return secrets.isSessionUnlocked ? nil : "已保存 · 点刷新用指纹解锁"
        }
        return nil
    }

    func maskedSMTPPassword() -> String? {
        if let s = secrets.get(account: settings.email.passwordRef), !s.isEmpty {
            return SecretMask.display(s)
        }
        if secrets.contains(account: settings.email.passwordRef) {
            return secrets.isSessionUnlocked ? nil : "已保存 · 点刷新用指纹解锁"
        }
        return nil
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        // 菜单栏 App：异步弹，避免卡死
        DispatchQueue.main.async {
            alert.runModal()
        }
    }

    func hasSecret(for account: BalanceAccount) -> Bool {
        secrets.contains(account: account.secretRef)
    }

    func hasSMTPPassword() -> Bool {
        secrets.contains(account: settings.email.passwordRef)
    }

    var secretsSessionUnlocked: Bool { secrets.isSessionUnlocked }

    /// 主动用指纹解锁（设置页点一下即可，不必等刷新）。
    func unlockSecrets() {
        Task {
            do {
                try await secrets.unlockSessionIfNeeded(
                    reason: "智余需要验证身份以显示已保存的密钥"
                )
                // 触发界面刷新掩码
                objectWillChange.send()
                banner = "已通过指纹/密码验证"
            } catch {
                banner = "验证失败：\(error.localizedDescription)"
            }
        }
    }

    func persist() {
        try? store.save(settings)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
