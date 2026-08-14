import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Domain
import Infrastructure

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var snapshots: [BalanceSnapshot] = []
    @Published var recentAlerts: [AlertEvent] = []
    @Published private(set) var usageHistory = UsageHistoryDocument()
    @Published private(set) var usageDataError: String?
    @Published private(set) var usageRecoveryNotice = false
    @Published private(set) var refreshNoticeKey: String?
    @Published var isRefreshing = false
    @Published var lastRefreshAt: Date?
    @Published var banner: String? {
        didSet { scheduleBannerAutoDismiss() }
    }
    /// 黄条提示自动消失任务（成功/失败提示约 3.5s；「正在…」不自动关）
    private var bannerDismissTask: Task<Void, Never>?
    @Published var selectedTab: Tab = .home
    /// 首页当前选中的账号（高亮 +「打开后台」目标）；点卡片切换。
    @Published var selectedAccountId: UUID?
    /// Mac 通知授权状态文案（设置页展示）。
    @Published var notificationStatusCaption: String = "系统未授权通知 · 点测试可再次请求"
    @Published private(set) var sessionRoute: SessionRoute = .home
    @Published var onboardingStep: OnboardingStep = .privacy
    @Published private(set) var compatibilityReport: CompatibilityReport?
    @Published private(set) var diagnosticReport: DiagnosticReport?
    @Published private(set) var isCollectingDiagnostics = false
    @Published var preferExpandAPIAccounts = false
    @Published var settingsSupportPage: SettingsSupportPage?
    @Published var restorePreview: TransferPreview?
    @Published var restoreOutcome: RestoreOutcome?
    @Published var restoreIncludeUsage = true
    @Published var restoreLegacyAcknowledged = false
    @Published var restoreBusy = false
    private var diagnosticsReturnTab: Tab = .home
    private var pendingRestoreData: Data?
    private var pendingRestoreMode: SettingsSupportPage = .transfer
    private var restoreSession = RestoreSession()
    private var restoreTask: Task<Void, Never>?

    enum Tab: String {
        case home
        case usage
        case settings
        case diagnostics
    }

    enum SettingsSupportPage: String {
        case transfer
        case backup
    }

    private let store = SettingsStore.shared
    private let secrets = LocalSecretStore.shared
    private let service = BalanceService()
    private let usageStore = UsageHistoryStore.shared
    private let firstLaunchStore = FirstLaunchStore.shared
    private let compatibilityChecker = CompatibilityChecker()
    private let restoreCoordinator: RestoreCoordinator
    private var pendingOpenSettingsAfterOnboarding = false
    private var refreshTask: Task<Void, Never>?
    private let refreshCoordinator: RefreshCoordinator
    private var usageBaselineResetTask: Task<Void, Never>?
    private var pendingUsageBaselineResetIDs: Set<UUID> = []
    private var refreshLoadingOwner: RefreshLoadingOwner = .none

    @Published var launchAtLoginEnabled: Bool = LaunchAtLogin.isEnabled
    @Published var updateChecking = false
    @Published var updateMessage: String?
    @Published var updateOpenURL: URL?
    @Published var updateDownloadURL: URL?
    @Published var updateAvailable = false
    /// 0…1 下载进度；nil 表示未在下载
    @Published var updateDownloadProgress: Double?
    /// 从浏览器导入 Cookie 进行中（防重复点、防主线程卡死）
    @Published var browserImporting = false
    private let updateChecker = UpdateChecker()

    /// 非进度类 banner 数秒后自动清除。
    private func scheduleBannerAutoDismiss() {
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
        guard let text = banner, !text.isEmpty else { return }
        // 进行中的提示由后续成功/失败覆盖，不自动关
        if text.contains("正在") || text.contains("请稍候") || text.contains("查询中") {
            return
        }
        let snapshot = text
        bannerDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled, let self else { return }
            if self.banner == snapshot {
                self.banner = nil
            }
        }
    }

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
        var next = settings
        next.themeMode = mode.rawValue
        settings = next
        persist()
        applyAppearancePreference()
        objectWillChange.send()
    }

    /// 把浅色 / 深色落到 AppKit。
    /// MenuBarExtra 仅靠 `preferredColorScheme` 改不了 `SBTheme` 的 `NSColor` 动态色，
    /// 必须同时设 `NSApp.appearance` + 各 `window.appearance`。
    func applyAppearancePreference() {
        let appearance: NSAppearance?
        switch settings.resolvedThemeMode {
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        case .system:
            appearance = nil
        }
        // 应用级：动态 Color / 控件都会跟 effectiveAppearance 走
        NSApp.appearance = appearance
        for window in NSApp.windows where !MenuBarStatusItemDriver.isStatusBarHostWindow(window) {
            window.appearance = appearance
            window.backgroundColor = SBTheme.windowNSBackground
            window.contentView?.layer?.backgroundColor = SBTheme.windowNSBackground.cgColor
            window.contentView?.needsDisplay = true
            window.contentView?.subviews.forEach { $0.needsDisplay = true }
        }
        PinnedBalanceWindowController.shared.refreshAppearance()
    }

    func setLanguage(_ lang: AppLanguage) {
        settings.appLanguage = lang.rawValue
        L10n.shared.setLanguage(lang)
        persist()
        objectWillChange.send()
    }

    init() {
        let supportDirectory = SettingsStore.shared.fileURL.deletingLastPathComponent()
        self.restoreCoordinator = RestoreCoordinator(
            directory: supportDirectory,
            settingsStore: SettingsStore.shared,
            usageStore: UsageHistoryStore.shared
        )
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
        let coordinator = RefreshCoordinator(
            fetcher: BalanceServiceRefreshFetcher(service: service),
            usageRecorder: UsageHistoryRefreshRecorder(store: usageStore)
        )
        self.refreshCoordinator = coordinator
        L10n.shared.setLanguage(loaded.resolvedLanguage)
        // 启动立刻显示账号卡片（查询中），避免空态引导页一直占着
        self.snapshots = Self.placeholderSnapshots(from: loaded)
        self.selectedAccountId = loaded.enabledAccounts.first?.id
        coordinator.seedAcceptedSnapshots(self.snapshots)
        coordinator.onSnapshotsAccepted = { [weak self] outcome in
            self?.applyAcceptedRefreshSnapshots(outcome)
        }
        coordinator.onTerminal = { [weak self] outcome in
            self?.applyRefreshTerminal(outcome)
        }
        AppLog.info("App launch · accounts=\(settings.accounts.count) interval=\(settings.refreshIntervalSecs)s")
        prepareLaunchSession()
        registerRefreshLifecycleObservers()
        // 对齐智额：通知图标只跟包内白底 AppIcon 走；不 setIcon（会写自定义 Icon 锁死旧图）
        Task { @MainActor in
            MacNotificationService.shared.installDelegateIfNeeded()
            await refreshNotificationStatus()
            await refreshCompatibilityReport()
            rescheduleManualReminders()
            applyAppearancePreference()
            try? await Task.sleep(nanoseconds: 300_000_000)
            applyAppearancePreference()
            // 普通 Keychain 不需要启动解锁。通知授权改到明确用户动作。
            if self.sessionRoute == .home {
                self.startAutoRefreshIfNeeded()
            }
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await self.usageStore.load()
                self.usageHistory = result.document
                self.usageRecoveryNotice = result.recovery == .corruptFileBackedUp
            } catch {
                self.usageDataError = "load"
                AppLog.error("Usage history load failed", category: .usage, event: "usage_load_failed")
            }
        }
    }
    
    /// 有账号时的占位卡（加载中），保证首页直接进卡片而不是「去添加账号」。
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

    func usageSummary(
        period: UsagePeriod,
        anchor: Date,
        calendar: Calendar = .current
    ) -> UsageDashboardSummary {
        UsageSummaryBuilder.build(
            document: usageHistory,
            period: period,
            anchor: anchor,
            calendar: calendar
        )
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
            return "\(L10n.shared.t(RefreshPresentation.lastRefreshPrefixKey)) \(f.string(from: lastRefreshAt))"
        }
        return "—"
    }

    var refreshButtonHelpKey: String {
        RefreshPresentation.refreshButtonHelpKey(refreshCoordinator.state)
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

    /// 打开指定账号的官网/后台（优先 Google Chrome）。
    func openDashboard(for account: BalanceAccount) {
        guard let urlString = account.resolvedConsoleURL, let url = URL(string: urlString) else {
            banner = "请先在该账号填写官网/后台链接"
            selectedTab = .settings
            return
        }
        BrowserLauncher.open(url)
    }

    // MARK: - Refresh

    func refresh() {
        refresh(trigger: .manual)
    }

    func refresh(trigger: RefreshTrigger) {
        guard pendingUsageBaselineResetIDs.isEmpty else {
            resetPendingUsageBaselinesAndRefresh()
            return
        }
        if !settings.apiQueryEnabled {
            settings.apiQueryEnabled = true
            try? store.save(settings)
        }
        prepareSnapshotsForRefresh()
        let admission = refreshCoordinator.request(
            RefreshRequest(scope: .all, trigger: trigger),
            settings: settings,
            currentSnapshots: snapshots
        )
        switch admission {
        case .ignoredSameScope:
            AppLog.info("Refresh coalesced · trigger=\(trigger.rawValue)")
        case .skippedNoAccounts:
            if refreshLoadingOwner == .refresh {
                isRefreshing = false
                refreshLoadingOwner = .none
            }
            AppLog.info("Refresh skipped · no accounts")
        case .started:
            refreshLoadingOwner = .refresh
            isRefreshing = true
            if trigger == .manual {
                banner = nil
                refreshNoticeKey = nil
            }
            AppLog.info(
                "Refresh start · accounts=\(settings.enabledAccounts.count) trigger=\(trigger.rawValue) gen=\(refreshCoordinator.generation)"
            )
        }
    }

    func handleRefreshButton() {
        if RefreshPresentation.refreshButtonCancels(refreshCoordinator.state) {
            cancelRefresh(reason: .user)
        } else {
            refresh(trigger: .manual)
        }
    }

    func cancelRefresh(reason: RefreshCancelReason = .user) {
        refreshCoordinator.cancel(reason: reason)
        if RefreshLoadingPolicy.shouldApplyRefreshTerminalToLoading(owner: refreshLoadingOwner) {
            isRefreshing = RefreshPresentation.isBusy(refreshCoordinator.state)
        }
    }

    func dismissRefreshNotice() {
        refreshNoticeKey = nil
        banner = nil
    }

    private func prepareSnapshotsForRefresh() {
        if snapshots.isEmpty, !settings.enabledAccounts.isEmpty {
            snapshots = Self.placeholderSnapshots(from: settings)
        } else if !settings.enabledAccounts.isEmpty {
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
    }

    private func applyAcceptedRefreshSnapshots(_ outcome: RefreshOutcome) {
        snapshots = orderedSnapshots(outcome.snapshots)
        if snapshots.isEmpty, !settings.enabledAccounts.isEmpty {
            snapshots = Self.placeholderSnapshots(from: settings)
        }
        if !outcome.alerts.isEmpty {
            recentAlerts = Array((outcome.alerts + recentAlerts).prefix(20))
            if let fail = outcome.alerts.first(where: {
                !$0.emailed && $0.message.hasPrefix("邮件发送失败")
            }) {
                let firstLine = fail.message.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? fail.message
                banner = firstLine
                AppLog.error(firstLine)
            }
            for alert in outcome.alerts {
                AppLog.info("Alert: \(alert.title) notified=\(alert.notified) emailed=\(alert.emailed)")
            }
        }
        settings.lastAlertAtByAccount = outcome.lastAlertAtByAccount
        lastRefreshAt = Date()
        try? store.save(settings)
        AppLog.info("Refresh snapshots accepted · cards=\(snapshots.count) gen=\(outcome.generation)")
    }

    private func applyRefreshTerminal(_ outcome: RefreshOutcome?) {
        if case .running = refreshCoordinator.state { return }
        let applyLoading = RefreshLoadingPolicy.shouldApplyRefreshTerminalToLoading(
            owner: refreshLoadingOwner
        )
        if applyLoading {
            isRefreshing = RefreshPresentation.isBusy(refreshCoordinator.state)
            if !isRefreshing {
                refreshLoadingOwner = .none
            }
        } else {
            return
        }

        if let warning = outcome?.usageWarning {
            usageDataError = warning == .loadFailed ? "load" : "save"
            refreshNoticeKey = warning.messageKey
            banner = L10n.shared.t(warning.messageKey)
            AppLog.error("Usage history persist failed", category: .usage, event: "usage_persist_failed")
        } else if let document = outcome?.usageDocument {
            usageHistory = document
            usageDataError = nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let loadResult = try? await self.usageStore.load() {
                    self.usageRecoveryNotice = self.usageRecoveryNotice
                        || loadResult.recovery == .corruptFileBackedUp
                }
            }
        }

        if outcome?.usageWarning == nil,
           let key = RefreshPresentation.statusMessageKey(refreshCoordinator.state) {
            refreshNoticeKey = key
            banner = L10n.shared.t(key)
        } else if outcome?.usageWarning == nil, outcome != nil {
            refreshNoticeKey = nil
        }
    }

    private func registerRefreshLifecycleObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let reason = RefreshLifecyclePolicy.cancelReason(for: .willSleep) else { return }
                self?.cancelRefresh(reason: reason)
            }
        }
    }

    private func invalidateActiveRefresh() {
        refreshCoordinator.cancel(reason: .superseded)
    }

    private func requestUsageBaselineResetAndRefresh(for accountIDs: Set<UUID>) {
        guard !accountIDs.isEmpty else {
            refresh()
            return
        }
        pendingUsageBaselineResetIDs.formUnion(accountIDs)
        resetPendingUsageBaselinesAndRefresh()
    }

    private func resetPendingUsageBaselinesAndRefresh() {
        guard !pendingUsageBaselineResetIDs.isEmpty else {
            refresh()
            return
        }
        refreshLoadingOwner = .usageBaselineReset
        invalidateActiveRefresh()
        usageBaselineResetTask?.cancel()
        isRefreshing = true
        let accountIDs = pendingUsageBaselineResetIDs
        let generation = refreshCoordinator.generation
        usageBaselineResetTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let history = try await self.usageStore.resetBaselines(for: accountIDs)
                guard !Task.isCancelled, generation == self.refreshCoordinator.generation else { return }
                let loadResult = try await self.usageStore.load()
                guard !Task.isCancelled, generation == self.refreshCoordinator.generation else { return }
                self.usageHistory = history
                self.usageRecoveryNotice = self.usageRecoveryNotice
                    || loadResult.recovery == .corruptFileBackedUp
                self.usageDataError = nil
                self.pendingUsageBaselineResetIDs.subtract(accountIDs)
                self.usageBaselineResetTask = nil
                self.refreshLoadingOwner = .none
                self.isRefreshing = false
                self.refresh()
            } catch is CancellationError {
                return
            } catch {
                guard generation == self.refreshCoordinator.generation else { return }
                self.usageDataError = error is UsageHistoryStoreError ? "load" : "save"
                self.usageBaselineResetTask = nil
                self.refreshLoadingOwner = .none
                self.isRefreshing = false
                AppLog.error("Usage baseline reset failed: \(error.localizedDescription)")
            }
        }
    }

    /// 按当前阈值本地重算卡片状态（不打 API）。
    func recomputeSnapshotStatusesFromThresholds() {
        let ch = settings.alertChannels
        snapshots = snapshots.map { snap in
            var s = snap
            if s.errorMessage != nil || s.status == .setup || s.status == .error {
                return s
            }
            guard s.amount != nil || s.remainingPercent != nil else { return s }
            let account = settings.accounts.first(where: { $0.id == s.accountId })
            let warningAmt = account?.alertThreshold ?? ch.warningAmount
            let midAmt = min(ch.midAmount, warningAmt)
            let critAmt = min(ch.criticalAmount, midAmt)
            let warnPct = account?.alertPercentThreshold ?? ch.warningPercent
            let midPct = min(ch.midPercent, warnPct)
            let critPct = min(ch.criticalPercent, midPct)
            s.status = BalanceSnapshot.resolveStatus(
                amount: s.amount,
                remainingPercent: s.remainingPercent,
                warningAmount: warningAmt,
                midAmount: midAmt,
                criticalAmount: critAmt,
                warningPercent: warnPct,
                midPercent: midPct,
                criticalPercent: critPct
            )
            return s
        }
    }

    func startAutoRefreshIfNeeded() {
        refreshTask?.cancel()
        guard settings.refreshIntervalSecs > 0 else {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 400_000_000)
                self?.refresh(trigger: .interval)
            }
            return
        }
        let interval = settings.refreshIntervalSecs
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            self?.refresh(trigger: .interval)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                guard !Task.isCancelled else { break }
                self?.refresh(trigger: .interval)
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
    ) async {
        let normalized = normalizeSessionCredential(kind: kind, secret: secret, userId: userId)
        let account = BalanceAccount(
            kind: kind,
            displayName: displayName,
            baseURL: baseURL,
            consoleURL: consoleURL,
            userId: normalized.userId,
            manualAmount: kind.isManualEntry ? manualAmount : nil,
            manualUnit: kind.isManualEntry ? kind.defaultManualUnit : nil,
            manualUpdatedAt: (kind.isManualEntry && manualAmount != nil) ? Date() : nil,
            dailyReminderEnabled: kind.isManualEntry ? true : nil
        )
        if kind.needsSecret, !normalized.secret.isEmpty {
            do {
                try secrets.set(normalized.secret, account: account.secretRef)
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
        invalidateActiveRefresh()
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
        let knownAccountIDs = Set(settings.accounts.map(\.id))
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let history = try await self.usageStore.record(
                    snapshots: [],
                    knownAccountIDs: knownAccountIDs,
                    now: Date(),
                    calendar: .current
                )
                self.usageHistory = history
                let loadResult = try await self.usageStore.load()
                self.usageRecoveryNotice = self.usageRecoveryNotice
                    || loadResult.recovery == .corruptFileBackedUp
                self.usageDataError = nil
            } catch {
                self.usageDataError = error is UsageHistoryStoreError ? "load" : "save"
                AppLog.error("Usage baseline cleanup failed: \(error.localizedDescription)")
            }
        }
    }

    /// 给已有账号补填/更新密钥（不必删号重加）。
    func updateAccountSecret(id: UUID, secret: String) async {
        guard let idx = settings.accounts.firstIndex(where: { $0.id == id }) else { return }
        let acc = settings.accounts[idx]
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            banner = "密钥不能为空"
            return
        }
        let normalized = normalizeSessionCredential(kind: acc.kind, secret: trimmed, userId: acc.userId)
        do {
            try secrets.set(normalized.secret, account: acc.secretRef)
            if let uid = normalized.userId, !uid.isEmpty {
                settings.accounts[idx].userId = uid
                persist()
            }
            banner = "已更新 \(acc.title) 的密钥"
            objectWillChange.send()
            requestUsageBaselineResetAndRefresh(for: [id])
        } catch {
            banner = "密钥保存失败：\(error.localizedDescription)"
        }
    }

    /// MiMo / MiniMax / apinebula：把整段 Cookie 拆成 token + userId 再入库。
    private func normalizeSessionCredential(
        kind: ProviderKind,
        secret: String,
        userId: String?
    ) -> (secret: String, userId: String?) {
        switch kind {
        case .mimo:
            let r = SessionCookieParser.resolveMiMo(secret: secret, userId: userId)
            return (r.token, r.userId)
        case .minimax:
            let token = SessionCookieParser.resolveMiniMaxToken(secret: secret)
            let groupId = SessionCookieParser.value(named: "minimax_group_id_v2", in: secret)
                ?? userId?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (token, (groupId?.isEmpty == false) ? groupId : nil)
        case .apinebula:
            let r = SessionCookieParser.resolveApinebula(secret: secret, userId: userId)
            return (r.session, r.userId)
        default:
            return (secret.trimmingCharacters(in: .whitespacesAndNewlines), userId)
        }
    }

    /// 新用户：从本机 Chrome/Edge 导入控制台登录态并添加账号（纯后台，绝不堵 UI）。
    func importBrowserSessionAndAdd(kind: ProviderKind, displayName: String = "") async {
        guard kind.supportsBrowserSessionImport else {
            banner = "该平台不支持浏览器导入"
            return
        }
        guard !browserImporting else { return }
        browserImporting = true
        banner = "正在从 Chrome 读取登录态（请稍候，勿重复点击）…"
        let name = displayName
        do {
            let cred = try await BrowserSessionImporter.importSessionAsync(for: kind)
            await addAccount(
                kind: kind,
                displayName: name,
                baseURL: kind.defaultBaseURL,
                consoleURL: kind.defaultConsoleURL,
                userId: cred.userId,
                secret: cred.secret
            )
            browserImporting = false
            banner = "已从 \(cred.source) 导入 \(kind.displayName) 登录态"
        } catch {
            let msg = error.localizedDescription
            browserImporting = false
            banner = msg
            AppLog.error("Browser import failed: \(msg)")
        }
    }

    /// 已有账号：从浏览器刷新会话 Cookie（纯后台）。
    func importBrowserSession(intoAccountId id: UUID) async {
        guard let acc = settings.accounts.first(where: { $0.id == id }) else { return }
        guard acc.kind.supportsBrowserSessionImport else {
            banner = "该平台不支持浏览器导入"
            return
        }
        guard !browserImporting else { return }
        browserImporting = true
        banner = "正在从 Chrome 更新登录态（请稍候）…"
        let kind = acc.kind
        let title = acc.title
        do {
            let cred = try await BrowserSessionImporter.importSessionAsync(for: kind)
            await updateAccountSecret(id: id, secret: cred.secret)
            if let uid = cred.userId, !uid.isEmpty {
                updateAccountUserId(id: id, userId: uid)
            }
            browserImporting = false
            banner = "已从 \(cred.source) 更新 \(title) 登录态"
        } catch {
            let msg = error.localizedDescription
            browserImporting = false
            banner = msg
            AppLog.error("Browser re-import failed: \(msg)")
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
        requestUsageBaselineResetAndRefresh(for: [id])
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
        // 立刻同步首页卡片，不必等下一次 refresh
        if !enabled {
            snapshots.removeAll { $0.accountId == id }
        } else if !snapshots.contains(where: { $0.accountId == id }) {
            let acc = settings.accounts[idx]
            snapshots.append(
                BalanceSnapshot(
                    accountId: acc.id,
                    providerKind: acc.kind,
                    displayName: acc.title,
                    source: .api,
                    status: .unknown,
                    detail: "查询中…"
                )
            )
            snapshots = orderedSnapshots(snapshots)
        }
        persist()
        rescheduleManualReminders()
        refresh()
    }

    /// 每天 10:00 提醒手录账号打开网页核对并更新金额。
    func rescheduleManualReminders() {
        let names = settings.accounts
            .filter { $0.enabled && $0.kind.isManualEntry && $0.wantsDailyReminder }
            .map(\.title)
        Task {
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
                rescheduleManualReminders()
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
        recomputeSnapshotStatusesFromThresholds()
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
        recomputeSnapshotStatusesFromThresholds()
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
        recomputeSnapshotStatusesFromThresholds()
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
        recomputeSnapshotStatusesFromThresholds()
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
        recomputeSnapshotStatusesFromThresholds()
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
        recomputeSnapshotStatusesFromThresholds()
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

    func openDiagnosticsCenter() {
        if selectedTab != .diagnostics {
            diagnosticsReturnTab = selectedTab
        }
        selectedTab = .diagnostics
        Task { await refreshDiagnostics() }
    }

    func closeDiagnosticsCenter() {
        selectedTab = diagnosticsReturnTab == .diagnostics ? .home : diagnosticsReturnTab
    }

    func openSettingsFromDiagnostics() {
        selectedTab = .settings
    }

    func refreshDiagnostics() async {
        guard !isCollectingDiagnostics else { return }
        isCollectingDiagnostics = true
        defer { isCollectingDiagnostics = false }
        let notification = await MacNotificationService.shared.authorizationState()
        let refreshSummary = DiagnosticRefreshSummary(
            refreshState: refreshCoordinator.state,
            lastRefreshAt: lastRefreshAt,
            succeededCount: refreshCoordinator.lastAcceptedOutcome?.succeededCount ?? 0,
            failedCount: refreshCoordinator.lastAcceptedOutcome?.failedCount ?? 0
        )
        let snapshotSettings = settings
        let snapshotUsage = usageHistory
        let usageError = usageDataError
        let version = appVersion
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let settingsURL = store.fileURL
        let usageURL = usageStore.fileURL
        let report = await Task.detached(priority: .userInitiated) {
            let keychain = LocalSecretStore.shared.availabilityStatus()
            let context = DiagnosticsService.makeLiveContext(
                settings: snapshotSettings,
                usage: snapshotUsage,
                usageSaveError: usageError,
                refresh: refreshSummary,
                keychainStatus: keychain,
                notificationAuthorization: notification,
                appVersion: version,
                build: build,
                settingsFileURL: settingsURL,
                usageHistoryFileURL: usageURL
            )
            return DiagnosticsService().collect(context)
        }.value
        diagnosticReport = report
    }

    func copyDiagnosticsSummary() {
        guard let report = diagnosticReport else { return }
        let text = PrivacyRedactor.redact(DiagnosticArchiveWriter.textSummary(report))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        banner = L10n.shared.t("diagnostics.copied")
    }

    func exportDiagnostics() {
        guard let report = diagnosticReport else { return }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = L10n.shared.t("diagnostics.export.title")
        panel.nameFieldStringValue = "smartbalance-diagnostics.zip"
        panel.allowedContentTypes = [.zip]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try DiagnosticArchiveWriter().writeZip(report, to: url)
            banner = L10n.shared.t("diagnostics.export.success")
            AppLog.info("Diagnostic archive exported")
        } catch {
            banner = L10n.shared.t("diagnostics.export.failed")
            AppLog.error("Diagnostic export failed", category: .filesystem, event: "diagnostics_export_failed")
        }
    }

    func openDiagnosticsHelp() {
        if let url = URL(string: "https://github.com/yancyfeng999-star/smartbalance/blob/main/docs/USER_GUIDE.md") {
            BrowserLauncher.open(url)
        }
    }

    // MARK: - Settings transfer / local restore

    func openSettingsTransfer() {
        settingsSupportPage = .transfer
        clearRestorePreview(resetPage: false)
    }

    func openBackupRestore() {
        settingsSupportPage = .backup
        clearRestorePreview(resetPage: false)
    }

    func closeSettingsSupport() {
        abortInFlightRestore()
        if restorePreview != nil || restoreOutcome != nil {
            clearRestorePreview(resetPage: false)
            return
        }
        settingsSupportPage = nil
    }

    func exportSettingsTransfer() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = L10n.shared.t("settings.transfer.export_title")
        panel.message = L10n.shared.t("settings.transfer.export_message")
        panel.nameFieldStringValue = SettingsTransferService.datedFileName(
            prefix: L10n.shared.t("settings.transfer.file_prefix")
        )
        panel.allowedContentTypes = [.json]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try SettingsTransferService.writeExport(
                settings: settings,
                appVersion: appVersion,
                to: url
            )
            banner = L10n.shared.t("settings.transfer.export_ok")
            AppLog.info("Settings transfer exported")
        } catch {
            banner = L10n.shared.t("settings.transfer.export_failed")
            AppLog.error("Settings transfer export failed", category: .backup, event: "settings_export_failed")
        }
    }

    func exportLocalBackup() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = L10n.shared.t("settings.backup.export_title")
        panel.message = L10n.shared.t("settings.backup.export_message")
        panel.nameFieldStringValue = SettingsTransferService.datedFileName(
            prefix: L10n.shared.t("settings.backup.file_prefix")
        )
        panel.allowedContentTypes = [.json]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try SettingsTransferService.writeLocalRestore(
                settings: settings,
                usage: restoreIncludeUsage ? usageHistory : nil,
                appVersion: appVersion,
                to: url
            )
            banner = L10n.shared.t("settings.backup.export_ok")
            AppLog.info("Local restore package exported")
        } catch {
            banner = L10n.shared.t("settings.backup.export_failed")
            AppLog.error("Local restore export failed", category: .backup, event: "restore_export_failed")
        }
    }

    func pickSettingsImport() {
        pickRestoreFile(mode: .transfer)
    }

    func pickLocalRestore() {
        pickRestoreFile(mode: .backup)
    }

    func confirmPendingRestore() {
        guard let data = pendingRestoreData, !restoreBusy else { return }
        let preview = restorePreview
        if preview?.isLegacySecretBackup == true && !restoreLegacyAcknowledged {
            return
        }
        restoreBusy = true
        let includeUsage = pendingRestoreMode == .backup && restoreIncludeUsage
        let allowLegacy = preview?.isLegacySecretBackup == true && restoreLegacyAcknowledged
        var prepared = preview
        prepared?.settings.windowPinned = false
        prepared?.settings.apiQueryEnabled = true
        let token = restoreSession.begin()
        restoreTask?.cancel()
        restoreTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome: RestoreOutcome
            if let prepared {
                outcome = await self.restoreCoordinator.restore(
                    preview: prepared,
                    confirmed: true,
                    includeUsage: includeUsage,
                    allowLegacyNonSensitive: allowLegacy
                )
            } else {
                outcome = await self.restoreCoordinator.restore(
                    from: data,
                    confirmed: true,
                    includeUsage: includeUsage,
                    allowLegacyNonSensitive: allowLegacy
                )
            }
            guard self.restoreSession.isCurrent(token), !Task.isCancelled else { return }
            self.restoreBusy = false
            self.restoreTask = nil
            self.restoreOutcome = outcome
            if outcome.status == .succeeded {
                self.applyRestoredState(outcome)
                self.banner = L10n.shared.t("restore.result.ok")
            } else if outcome.status == .cancelled {
                self.banner = L10n.shared.t("restore.result.cancelled")
            } else {
                self.banner = L10n.shared.t(self.restoreFailureKey(outcome.failureReason))
            }
        }
    }

    func cancelPendingRestore() {
        abortInFlightRestore()
        restoreOutcome = RestoreOutcome.cancelled()
        pendingRestoreData = nil
        restorePreview = nil
        restoreLegacyAcknowledged = false
        banner = L10n.shared.t("restore.result.cancelled")
    }

    func openBackupDirectory() {
        let directory = store.fileURL.deletingLastPathComponent()
        NSWorkspace.shared.activateFileViewerSelecting([directory])
        AppLog.info("Opened backup directory")
    }

    func isCredentialMissing(for account: BalanceAccount) -> Bool {
        secrets.credentialPresence(for: account.secretRef) == .missing
    }

    private func pickRestoreFile(mode: SettingsSupportPage) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = L10n.shared.t(mode == .transfer ? "settings.transfer.import_title" : "settings.backup.restore_title")
        panel.message = L10n.shared.t(mode == .transfer ? "settings.transfer.import_message" : "settings.backup.restore_message")
        panel.allowedContentTypes = [.json]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            banner = L10n.shared.t("restore.error.read")
            AppLog.error("Restore file read failed", category: .backup, event: "restore_read_failed")
            return
        }
        do {
            let preview = try SettingsTransferService.preview(from: data)
            pendingRestoreData = data
            pendingRestoreMode = mode
            restoreIncludeUsage = mode == .backup && preview.includesUsageHistory
            restoreLegacyAcknowledged = false
            restoreOutcome = nil
            restorePreview = preview
            AppLog.info(
                "Restore preview format=\(preview.format) v\(preview.formatVersion) legacy=\(preview.isLegacySecretBackup)"
            )
        } catch SettingsTransferError.formatMismatch {
            banner = L10n.shared.t("restore.error.format")
        } catch SettingsTransferError.versionTooNew {
            banner = L10n.shared.t("restore.error.version")
        } catch SettingsTransferError.corruptUsage {
            banner = L10n.shared.t("restore.error.usage")
        } catch {
            banner = L10n.shared.t("restore.error.decode")
        }
    }

    private func applyRestoredState(_ outcome: RestoreOutcome) {
        let next = outcome.settings ?? store.reloadFromDisk()
        invalidateActiveRefresh()
        settings = next
        pinWindowOpen = false
        selectedAccountId = next.enabledAccounts.first?.id
        snapshots = Self.placeholderSnapshots(from: next)
        lastRefreshAt = nil
        recentAlerts = []
        L10n.shared.setLanguage(next.resolvedLanguage)
        applyAppearancePreference()
        rescheduleManualReminders()
        startAutoRefreshIfNeeded()
        if outcome.includedUsage, let usage = outcome.usageHistory {
            usageHistory = usage
            usageDataError = nil
        }
        preferExpandAPIAccounts = next.accounts.contains { isCredentialMissing(for: $0) }
        objectWillChange.send()
        if RestoreApplyPolicy.shouldResetUsageBaselines(includedUsage: outcome.includedUsage) {
            requestUsageBaselineResetAndRefresh(for: Set(next.accounts.map(\.id)))
        } else {
            refresh()
        }
    }

    private func abortInFlightRestore() {
        restoreSession.cancel()
        restoreTask?.cancel()
        restoreTask = nil
        restoreBusy = false
    }

    private func clearRestorePreview(resetPage: Bool) {
        abortInFlightRestore()
        restorePreview = nil
        restoreOutcome = nil
        pendingRestoreData = nil
        restoreLegacyAcknowledged = false
        if resetPage {
            settingsSupportPage = nil
        }
    }

    private func restoreFailureKey(_ reason: RestoreFailureReason?) -> String {
        reason?.localizationKey ?? "restore.result.failed"
    }

    /// 一点「检查更新」：有新版本则直接下 pkg 静默安装，中间不弹任何窗。
    func checkForUpdates() {
        guard !updateChecking else { return }
        updateChecking = true
        updateMessage = "正在检查更新…"
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
            if result.status == .available {
                await downloadAndInstallUpdate(result: result)
            } else {
                await MainActor.run { self.updateChecking = false }
            }
        }
    }

    @MainActor
    private func downloadAndInstallUpdate(result: UpdateCheckResult) async {
        guard let remote = result.downloadURL else {
            updateChecking = false
            updateMessage = (result.message) + "（无安装包）"
            return
        }
        guard remote.scheme?.lowercased() == "https" else {
            updateChecking = false
            updateMessage = "下载地址必须为 HTTPS"
            return
        }
        let ver = result.latestVersion ?? ""
        updateMessage = "正在下载 \(ver)…"
        updateDownloadProgress = 0
        do {
            let file = try await ReleaseDownloader().download(from: remote) { [weak self] fraction in
                Task { @MainActor in
                    self?.updateDownloadProgress = fraction
                    self?.updateMessage = "下载 \(ver)  \(Int((fraction * 100).rounded()))%"
                }
            }
            updateDownloadProgress = 1
            let ext = file.pathExtension.lowercased()
            if ext == "pkg" {
                updateMessage = "正在安装 \(ver)…"
                try PackageSilentInstaller.scheduleReplace(pkgURL: file)
                updateMessage = "安装中，即将重启…"
                updateChecking = false
                try? await Task.sleep(nanoseconds: 400_000_000)
                NSApp.terminate(nil)
                return
            }
            // dmg / zip 回退：无确认框直接打开文件
            updateMessage = "已下载，正在打开安装包…"
            updateChecking = false
            NSWorkspace.shared.open(file)
            try? await Task.sleep(nanoseconds: 600_000_000)
            NSApp.terminate(nil)
        } catch {
            updateChecking = false
            updateDownloadProgress = nil
            updateMessage = "更新失败：\(error.localizedDescription)"
            AppLog.error("Update failed: \(error.localizedDescription)")
        }
    }

    func openUpdateURL() {
        if let url = updateDownloadURL ?? updateOpenURL {
            // 本地文件仍用系统打开；网页优先 Chrome
            if url.isFileURL {
                NSWorkspace.shared.open(url)
            } else {
                BrowserLauncher.open(url)
            }
        }
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
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
        secrets.credentialPresence(for: account.secretRef) == .present
    }

    func hasSMTPPassword() -> Bool {
        secrets.contains(account: settings.email.passwordRef)
    }

    func persist() {
        try? store.save(settings)
    }

    // MARK: - First launch / compatibility

    func prepareLaunchSession() {
        let load = firstLaunchStore.load()
        let hasExistingAccounts = !settings.accounts.isEmpty
        sessionRoute = FirstLaunchRouter.route(
            loadResult: load,
            hasExistingAccounts: hasExistingAccounts
        )
        onboardingStep = FirstLaunchRouter.initialStep(for: load)
        if FirstLaunchRouter.shouldSeedCompletedState(
            loadResult: load,
            hasExistingAccounts: hasExistingAccounts
        ) {
            try? firstLaunchStore.save(
                FirstLaunchState(
                    completedAt: Date(),
                    acknowledgedPrivacy: true,
                    lastCompatibilityReport: compatibilityReport
                )
            )
        }
    }

    func refreshCompatibilityReport() async {
        let notification = await MacNotificationService.shared.authorizationState()
        let context = CompatibilityChecker.makeLiveContext(
            notificationAuthorization: notification,
            settingsFileURL: store.fileURL,
            usageHistoryFileURL: usageStore.fileURL
        )
        compatibilityReport = compatibilityChecker.evaluate(context)
    }

    func acknowledgePrivacy() {
        persistPartialFirstLaunch(acknowledgedPrivacy: true)
        onboardingStep = FirstLaunchRouter.nextStep(after: .privacy) ?? .compatibility
        Task { await refreshCompatibilityReport() }
    }

    func continueFromCompatibility() {
        if sessionRoute == .compatibility {
            dismissCompatibilityToHome()
            return
        }
        onboardingStep = FirstLaunchRouter.nextStep(after: .compatibility) ?? .addProvider
    }

    func skipCompatibilityForNow() {
        continueFromCompatibility()
    }

    func chooseAddFirstProvider() {
        pendingOpenSettingsAfterOnboarding = true
        preferExpandAPIAccounts = true
        onboardingStep = FirstLaunchRouter.nextStep(after: .addProvider) ?? .notifications
    }

    func chooseOpenExistingConfiguration() {
        pendingOpenSettingsAfterOnboarding = true
        onboardingStep = FirstLaunchRouter.nextStep(after: .addProvider) ?? .notifications
    }

    func continueFromProviderStep() {
        onboardingStep = FirstLaunchRouter.nextStep(after: .addProvider) ?? .notifications
    }

    func enableNotificationsFromOnboarding() {
        Task {
            _ = await MacNotificationService.shared.requestAuthorizationIfNeeded()
            settings.alertChannels.macNotificationEnabled = true
            persist()
            await refreshNotificationStatus()
            rescheduleManualReminders()
            finishOnboarding()
        }
    }

    func skipNotificationsFromOnboarding() {
        finishOnboarding()
    }

    func openCompatibilityFromSettings() {
        Task { await refreshCompatibilityReport() }
    }

    func openSettingsFromCompatibility() {
        repairCorruptFirstLaunchStateIfNeeded()
        sessionRoute = .home
        selectedTab = .settings
        startAutoRefreshIfNeeded()
    }

    func dismissCompatibilityToHome() {
        repairCorruptFirstLaunchStateIfNeeded()
        sessionRoute = .home
        startAutoRefreshIfNeeded()
    }

    private func repairCorruptFirstLaunchStateIfNeeded() {
        guard firstLaunchStore.load() == .corrupt else { return }
        try? firstLaunchStore.save(
            FirstLaunchState(
                completedAt: Date(),
                acknowledgedPrivacy: true,
                lastCompatibilityReport: compatibilityReport
            )
        )
    }

    private func finishOnboarding() {
        let state = FirstLaunchState(
            completedAt: Date(),
            acknowledgedPrivacy: true,
            lastCompatibilityReport: compatibilityReport
        )
        try? firstLaunchStore.save(state)
        sessionRoute = FirstLaunchRouter.route(
            loadResult: .loaded(state),
            hasExistingAccounts: !settings.accounts.isEmpty,
            completedThisSession: true
        )
        if pendingOpenSettingsAfterOnboarding {
            selectedTab = .settings
        }
        startAutoRefreshIfNeeded()
    }

    private func persistPartialFirstLaunch(acknowledgedPrivacy: Bool) {
        let state = FirstLaunchState(
            completedAt: nil,
            acknowledgedPrivacy: acknowledgedPrivacy,
            lastCompatibilityReport: compatibilityReport
        )
        try? firstLaunchStore.save(state)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
