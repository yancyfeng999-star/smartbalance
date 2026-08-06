import Foundation

/// 应用持久化设置。
public struct AppSettings: Codable, Equatable, Sendable {
    public var accounts: [BalanceAccount]
    public var mailSources: [PlatformMailSource]
    public var inboundMailbox: InboundMailboxSettings
    public var email: EmailAlertSettings
    public var alertChannels: AlertChannelSettings

    public var apiQueryEnabled: Bool
    public var platformMailEnabled: Bool
    /// 后台同步间隔秒；0 = 关闭（仅手动/打开菜单时）。
    public var refreshIntervalSecs: Int
    public var lastAlertAtByAccount: [String: Date]
    public var windowPinned: Bool

    public init(
        accounts: [BalanceAccount] = [],
        mailSources: [PlatformMailSource] = [],
        inboundMailbox: InboundMailboxSettings = InboundMailboxSettings(),
        email: EmailAlertSettings = EmailAlertSettings(),
        alertChannels: AlertChannelSettings = AlertChannelSettings(),
        apiQueryEnabled: Bool = true,
        platformMailEnabled: Bool = true,
        refreshIntervalSecs: Int = 900,
        lastAlertAtByAccount: [String: Date] = [:],
        windowPinned: Bool = false
    ) {
        self.accounts = accounts
        self.mailSources = mailSources
        self.inboundMailbox = inboundMailbox
        self.email = email
        self.alertChannels = alertChannels
        self.apiQueryEnabled = apiQueryEnabled
        self.platformMailEnabled = platformMailEnabled
        self.refreshIntervalSecs = refreshIntervalSecs
        self.lastAlertAtByAccount = lastAlertAtByAccount
        self.windowPinned = windowPinned
    }

    public var enabledAccounts: [BalanceAccount] {
        accounts.filter(\.enabled)
    }

    public var enabledMailSources: [PlatformMailSource] {
        mailSources.filter(\.enabled)
    }

    public var refreshInterval: RefreshInterval {
        get { RefreshInterval.from(seconds: refreshIntervalSecs) }
        set { refreshIntervalSecs = newValue.seconds ?? 0 }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try c.decodeIfPresent([BalanceAccount].self, forKey: .accounts) ?? []
        mailSources = try c.decodeIfPresent([PlatformMailSource].self, forKey: .mailSources) ?? []
        inboundMailbox = try c.decodeIfPresent(InboundMailboxSettings.self, forKey: .inboundMailbox) ?? InboundMailboxSettings()
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
        platformMailEnabled = try c.decodeIfPresent(Bool.self, forKey: .platformMailEnabled) ?? true
        refreshIntervalSecs = try c.decodeIfPresent(Int.self, forKey: .refreshIntervalSecs) ?? 900
        lastAlertAtByAccount = try c.decodeIfPresent([String: Date].self, forKey: .lastAlertAtByAccount) ?? [:]
        windowPinned = try c.decodeIfPresent(Bool.self, forKey: .windowPinned) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(accounts, forKey: .accounts)
        try c.encode(mailSources, forKey: .mailSources)
        try c.encode(inboundMailbox, forKey: .inboundMailbox)
        try c.encode(email, forKey: .email)
        try c.encode(alertChannels, forKey: .alertChannels)
        try c.encode(apiQueryEnabled, forKey: .apiQueryEnabled)
        try c.encode(platformMailEnabled, forKey: .platformMailEnabled)
        try c.encode(refreshIntervalSecs, forKey: .refreshIntervalSecs)
        try c.encode(lastAlertAtByAccount, forKey: .lastAlertAtByAccount)
        try c.encode(windowPinned, forKey: .windowPinned)
    }

    private enum CodingKeys: String, CodingKey {
        case accounts, mailSources, inboundMailbox, email, alertChannels
        case apiQueryEnabled, platformMailEnabled, refreshIntervalSecs, lastAlertAtByAccount
        case windowPinned
        case emailAlertModeEnabled
    }
}
