import Foundation

/// 应用持久化设置。
public struct AppSettings: Codable, Equatable, Sendable {
    public var accounts: [BalanceAccount]
    public var email: EmailAlertSettings
    public var alertChannels: AlertChannelSettings

    public var apiQueryEnabled: Bool
    /// 后台同步间隔秒；0 = 关闭（仅手动/打开菜单时）。
    public var refreshIntervalSecs: Int
    public var lastAlertAtByAccount: [String: Date]
    public var windowPinned: Bool
    /// 外观：`light` / `dark` / `system`
    public var themeMode: String
    /// 界面语言：`zh-Hans` / `en` / …
    public var appLanguage: String

    public init(
        accounts: [BalanceAccount] = [],
        email: EmailAlertSettings = EmailAlertSettings(),
        alertChannels: AlertChannelSettings = AlertChannelSettings(),
        apiQueryEnabled: Bool = true,
        refreshIntervalSecs: Int = 900,
        lastAlertAtByAccount: [String: Date] = [:],
        windowPinned: Bool = false,
        themeMode: String = ThemeMode.system.rawValue,
        appLanguage: String = AppLanguage.default.rawValue
    ) {
        self.accounts = accounts
        self.email = email
        self.alertChannels = alertChannels
        self.apiQueryEnabled = apiQueryEnabled
        self.refreshIntervalSecs = refreshIntervalSecs
        self.lastAlertAtByAccount = lastAlertAtByAccount
        self.windowPinned = windowPinned
        self.themeMode = themeMode
        self.appLanguage = appLanguage
    }

    public var resolvedThemeMode: ThemeMode {
        ThemeMode.resolve(themeMode)
    }

    public var resolvedLanguage: AppLanguage {
        AppLanguage.resolve(appLanguage)
    }

    public var enabledAccounts: [BalanceAccount] {
        accounts.filter(\.enabled)
    }

    public var refreshInterval: RefreshInterval {
        get { RefreshInterval.from(seconds: refreshIntervalSecs) }
        set { refreshIntervalSecs = newValue.seconds ?? 0 }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try c.decodeIfPresent([BalanceAccount].self, forKey: .accounts) ?? []
        email = try c.decodeIfPresent(EmailAlertSettings.self, forKey: .email) ?? EmailAlertSettings()
        if let channels = try c.decodeIfPresent(AlertChannelSettings.self, forKey: .alertChannels) {
            alertChannels = channels
        } else {
            var ch = AlertChannelSettings()
            ch.defaultAmountThreshold = email.defaultAmountThreshold
            ch.defaultPercentThreshold = email.defaultPercentThreshold
            ch.cooldownSeconds = email.cooldownSeconds
            ch.outboundEmailEnabled = try c.decodeIfPresent(Bool.self, forKey: .emailAlertModeEnabled) ?? true
            ch.macNotificationEnabled = true
            ch.quotaThresholdAlertsEnabled = true
            alertChannels = ch
        }
        apiQueryEnabled = try c.decodeIfPresent(Bool.self, forKey: .apiQueryEnabled) ?? true
        // 旧版 platformMailEnabled / mailSources / inboundMailbox 直接忽略
        refreshIntervalSecs = try c.decodeIfPresent(Int.self, forKey: .refreshIntervalSecs) ?? 900
        lastAlertAtByAccount = try c.decodeIfPresent([String: Date].self, forKey: .lastAlertAtByAccount) ?? [:]
        windowPinned = try c.decodeIfPresent(Bool.self, forKey: .windowPinned) ?? false
        themeMode = try c.decodeIfPresent(String.self, forKey: .themeMode) ?? ThemeMode.system.rawValue
        appLanguage = try c.decodeIfPresent(String.self, forKey: .appLanguage) ?? AppLanguage.default.rawValue
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(accounts, forKey: .accounts)
        try c.encode(email, forKey: .email)
        try c.encode(alertChannels, forKey: .alertChannels)
        try c.encode(apiQueryEnabled, forKey: .apiQueryEnabled)
        try c.encode(refreshIntervalSecs, forKey: .refreshIntervalSecs)
        try c.encode(lastAlertAtByAccount, forKey: .lastAlertAtByAccount)
        try c.encode(windowPinned, forKey: .windowPinned)
        try c.encode(themeMode, forKey: .themeMode)
        try c.encode(appLanguage, forKey: .appLanguage)
    }

    private enum CodingKeys: String, CodingKey {
        case accounts, email, alertChannels
        case apiQueryEnabled, refreshIntervalSecs, lastAlertAtByAccount
        case windowPinned, themeMode, appLanguage
        case emailAlertModeEnabled
        // 旧字段仅解码忽略
        case mailSources, inboundMailbox, platformMailEnabled
    }
}
