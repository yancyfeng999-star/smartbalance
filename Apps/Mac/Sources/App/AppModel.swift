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
    /// 首页当前选中的账号（高亮 +「打开后台」目标）；点卡片切换。
    @Published var selectedAccountId: UUID?
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
    /// 首页长按卡片进入排序模式（对齐智额 ↑↓）
    @Published var isReorderMode = false

    /// 外观 → SwiftUI preferredColorScheme
    var preferredColorScheme: ColorScheme? {
        switch settings.resolvedThemeMode {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }

    func setThemeMode(_ mode: ThemeMode) {
        settings.themeMode = mode.rawValue
        persist()
        objectWillChange.send()
    }

    func setLanguage(_ lang: AppLanguage) {
        settings.appLanguage = lang.rawValue
        L10n.shared.setLanguage(lang)
        persist()
        objectWillChange.send()
    }

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
        L10n.shared.setLanguage(loaded.resolvedLanguage)
        // 启动立刻显示账号卡片（查询中），避免空态引导页一直占着
        self.snapshots = Self.placeholderSnapshots(from: loaded)
        self.selectedAccountId = loaded.enabledAccounts.first?.id
        AppLog.info("App launch · accounts=\(settings.accounts.count) interval=\(settings.refreshIntervalSecs)s")
        Task { @MainActor in
            MacNotificationService.shared.installDelegateIfNeeded()
            _ = await MacNotificationService.shared.requestAuthorizationIfNeeded()
            await refreshNotificationStatus()
            rescheduleManualReminders()
        }
        startAutoRefreshIfNeeded()
    }

    /// 有账号时的占位卡（加载中 / 待解锁），保证首页直接进卡片而不是「去添加账号」。
    /// 顺序与 `settings.accounts`（用户排序）一致。
    private static func placeholderSnapshots(from settings: AppSettings) -> [BalanceSnapshot] {
        settings.enabledAccounts.map { account in
            BalanceSnapshot(
                accountId: account.id,
                providerKind: account.kind,
                displayName: account.title,
                source: .api,
                status: .unknown,
                detail: "查询中…",
                errorMessage: nil
            )
        }
    }

    /// 按账号列表顺序排列快照（不按名称字母序）。
    func orderedSnapshots(_ snaps: [BalanceSnapshot]) -> [BalanceSnapshot] {
        let order = settings.enabledAccounts.map(\.id)
        return snaps.sorted { a, b in
            let ia = order.firstIndex(of: a.accountId) ?? Int.max
            let ib = order.firstIndex(of: b.accountId) ?? Int.max
            if ia != ib { return ia < ib }
            return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
        }
    }

    func enterReorderMode() {
        guard snapshots.count >= 2 else {
            banner = "至少两个账号才能排序"
            return
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        AppMotion.withSelection {
            isReorderMode = true
        }
    }

    func exitReorderMode() {
        AppMotion.withSelection {
            isReorderMode = false
        }
    }

    /// 在已启用账号中上移 / 下移，并写回 `settings.accounts` 顺序。
    func moveAccount(id: UUID, up: Bool) {
        let enabledIds = settings.enabledAccounts.map(\.id)
        guard let ei = enabledIds.firstIndex(of: id) else { return }
        let ej = up ? ei - 1 : ei + 1
        guard enabledIds.indices.contains(ej) else { return }
        let otherId = enabledIds[ej]
        guard let from = settings.accounts.firstIndex(where: { $0.id == id }),
              let to = settings.accounts.firstIndex(where: { $0.id == otherId }) else { return }
        AppMotion.withSelection {
            settings.accounts.swapAt(from, to)
            snapshots = orderedSnapshots(snapshots)
        }
        persist()
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

    /// 选中首页账号（高亮 +「打开后台」目标）。
    func selectAccount(id: UUID) {
        guard settings.enabledAccounts.contains(where: { $0.id == id }) else { return }
        guard selectedAccountId != id else { return }
        AppMotion.withSelection {
            selectedAccountId = id
        }
    }

    /// 若当前选中已失效，回落到第一个已启用账号。
    func ensureValidSelectedAccount() {
        let enabled = settings.enabledAccounts
        if let id = selectedAccountId, enabled.contains(where: { $0.id == id }) {
            return
        }
        selectedAccountId = enabled.first?.id
    }

    /// 打开当前选中账号的官网/后台；无选中时用首个已启用账号。
    func openDashboard() {
        ensureValidSelectedAccount()
        let account: BalanceAccount?
        if let id = selectedAccountId {
            account = settings.enabledAccounts.first(where: { $0.id == id })
                ?? settings.accounts.first(where: { $0.id == id })
        } else {
            account = nil
        }
        guard let account = account ?? settings.enabledAccounts.first else {
            banner = "请先添加 API 账号"
            selectedTab = .settings
            return
        }
        openDashboard(for: account)
    }

    /// 打开指定账号的官网/后台。
    func openDashboard(for account: BalanceAccount) {
        guard let urlString = account.resolvedConsoleURL, let url = URL(string: urlString) else {
            banner = "请先在该账号填写官网/后台链接"
            selectedTab = .settings
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
        // 刷新过程中始终保留卡片骨架，绝不闪回「去添加账号」
        if snapshots.isEmpty, !settings.enabledAccounts.isEmpty {
            snapshots = Self.placeholderSnapshots(from: settings)
        } else if !settings.enabledAccounts.isEmpty {
            // 已有结果的卡保持金额；仅无结果的显示查询中
            snapshots = orderedSnapshots(
                settings.enabledAccounts.map { account in
                    if let existing = snapshots.first(where: { $0.accountId == account.id }),
                       existing.amount != nil || existing.errorMessage != nil {
                        return existing
                    }
                    return BalanceSnapshot(
                        accountId: account.id,
                        providerKind: account.kind,
                        displayName: account.title,
                        source: .api,
                        status: .unknown,
                        detail: "查询中…"
                    )
                }
            )
        }
        AppLog.info("Refresh start · accounts=\(settings.enabledAccounts.count)")
        Task { @MainActor in
            defer {
                // 无论成功/失败/取消，都解除刷新锁，避免永远「查询中」
                self.isRefreshing = false
            }
            do {
                // 密钥直接从本机 vault 读，无指纹门禁
                let result = await service.refreshAll(settings: settings)
                self.snapshots = orderedSnapshots(result.snapshots)
                if self.snapshots.isEmpty, !self.settings.enabledAccounts.isEmpty {
                    self.snapshots = Self.placeholderSnapshots(from: self.settings)
                }
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
                try? store.save(self.settings)
                AppLog.info("Refresh done · cards=\(self.snapshots.count)")
            } catch {
                self.banner = "刷新失败：\(error.localizedDescription)"
                AppLog.error("Refresh crashed: \(error.localizedDescription)")
            }
        }
    }

    func startAutoRefreshIfNeeded() {
        refreshTask?.cancel()
        guard settings.refreshIntervalSecs > 0 else {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 400_000_000)
                self?.refresh()
            }
            return
        }
        let interval = settings.refreshIntervalSecs
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
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
        consoleURL: String? = nil,
        userId: String? = nil,
        secret: String,
        manualAmount: Double? = nil
    ) {
        let account = BalanceAccount(
            kind: kind,
            displayName: displayName,
            baseURL: baseURL,
            consoleURL: consoleURL,
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
        if selectedAccountId == nil {
            selectedAccountId = account.id
        }
        persist()
        // 立刻出现在首页
        if !snapshots.contains(where: { $0.accountId == account.id }) {
            snapshots.append(
                BalanceSnapshot(
                    accountId: account.id,
                    providerKind: account.kind,
                    displayName: account.title,
                    source: .api,
                    status: .unknown,
                    detail: "查询中…"
                )
            )
            snapshots = orderedSnapshots(snapshots)
        }
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
        if selectedAccountId == id {
            selectedAccountId = settings.enabledAccounts.first?.id
        }
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

    /// 修改官网 / 后台链接（「打开后台」跳转用）。
    func updateAccountConsoleURL(id: UUID, consoleURL: String) {
        guard let idx = settings.accounts.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = consoleURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            settings.accounts[idx].consoleURL = settings.accounts[idx].kind.defaultConsoleURL
        } else {
            settings.accounts[idx].consoleURL = BalanceAccount.normalizedURLString(trimmed) ?? trimmed
        }
        persist()
        banner = "已更新 \(settings.accounts[idx].title) 的官网链接"
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
        if !enabled, selectedAccountId == id {
            selectedAccountId = settings.enabledAccounts.first?.id
        } else if enabled, selectedAccountId == nil {
            selectedAccountId = id
        }
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
        let t = AlertChannelSettings.clampAmountTiers(
            warning: value,
            mid: settings.alertChannels.midAmount,
            critical: settings.alertChannels.criticalAmount
        )
        settings.alertChannels.warningAmount = t.w
        settings.alertChannels.midAmount = t.m
        settings.alertChannels.criticalAmount = t.c
        settings.email.defaultAmountThreshold = t.w
        persist()
        refresh()
    }

    func setMidAmount(_ value: Double) {
        let t = AlertChannelSettings.clampAmountTiers(
            warning: settings.alertChannels.warningAmount,
            mid: value,
            critical: settings.alertChannels.criticalAmount
        )
        settings.alertChannels.warningAmount = t.w
        settings.alertChannels.midAmount = t.m
        settings.alertChannels.criticalAmount = t.c
        persist()
        refresh()
    }

    func setCriticalAmount(_ value: Double) {
        let t = AlertChannelSettings.clampAmountTiers(
            warning: settings.alertChannels.warningAmount,
            mid: settings.alertChannels.midAmount,
            critical: value
        )
        settings.alertChannels.warningAmount = t.w
        settings.alertChannels.midAmount = t.m
        settings.alertChannels.criticalAmount = t.c
        persist()
        refresh()
    }

    func setWarningPercent(_ value: Double) {
        let t = AlertChannelSettings.clampPercentTiers(
            warning: value,
            mid: settings.alertChannels.midPercent,
            critical: settings.alertChannels.criticalPercent
        )
        settings.alertChannels.warningPercent = t.w
        settings.alertChannels.midPercent = t.m
        settings.alertChannels.criticalPercent = t.c
        settings.email.defaultPercentThreshold = t.w
        persist()
        refresh()
    }

    func setMidPercent(_ value: Double) {
        let t = AlertChannelSettings.clampPercentTiers(
            warning: settings.alertChannels.warningPercent,
            mid: value,
            critical: settings.alertChannels.criticalPercent
        )
        settings.alertChannels.warningPercent = t.w
        settings.alertChannels.midPercent = t.m
        settings.alertChannels.criticalPercent = t.c
        persist()
        refresh()
    }

    func setCriticalPercent(_ value: Double) {
        let t = AlertChannelSettings.clampPercentTiers(
            warning: settings.alertChannels.warningPercent,
            mid: settings.alertChannels.midPercent,
            critical: value
        )
        settings.alertChannels.warningPercent = t.w
        settings.alertChannels.midPercent = t.m
        settings.alertChannels.criticalPercent = t.c
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

    /// 已存密钥的掩码展示（两端可见）。
    func maskedSecret(for account: BalanceAccount) -> String? {
        guard let s = secrets.get(account: account.secretRef), !s.isEmpty else { return nil }
        if account.kind.needsAccessKeyPair,
           let pair = VolcengineSigner.unpackCredentials(s) {
            return "AK " + SecretMask.display(pair.accessKeyId)
        }
        return SecretMask.display(s)
    }

    func maskedSMTPPassword() -> String? {
        guard let s = secrets.get(account: settings.email.passwordRef), !s.isEmpty else { return nil }
        return SecretMask.display(s)
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

    func persist() {
        try? store.save(settings)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
