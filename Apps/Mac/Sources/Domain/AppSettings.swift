import Foundation

/// 应用持久化设置。
public struct AppSettings: Codable, Equatable, Sendable {
    /// API 直查账号。
    public var accounts: [BalanceAccount]
    /// 平台邮件余额源（无实时 API 的平台）。
    public var mailSources: [PlatformMailSource]
    /// IMAP 收件箱（读平台邮件）。
    public var inboundMailbox: InboundMailboxSettings
    /// SMTP 出站报警。
    public var email: EmailAlertSettings
    /// Mac 通知 + 邮件报警开关与阈值。
    public var alertChannels: AlertChannelSettings

    public var apiQueryEnabled: Bool
    public var platformMailEnabled: Bool
    public var refreshIntervalSecs: Int
    public var lastAlertAtByAccount: [String: Date]

    public init(
        accounts: [BalanceAccount] = [],
        mailSources: [PlatformMailSource] = [],
        inboundMailbox: InboundMailboxSettings = InboundMailboxSettings(),
        email: EmailAlertSettings = EmailAlertSettings(),
        alertChannels: AlertChannelSettings = AlertChannelSettings(),
        apiQueryEnabled: Bool = true,
        platformMailEnabled: Bool = true,
        refreshIntervalSecs: Int = 600,
        lastAlertAtByAccount: [String: Date] = [:]
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
    }

    public var enabledAccounts: [BalanceAccount] {
        accounts.filter(\.enabled)
    }

    public var enabledMailSources: [PlatformMailSource] {
        mailSources.filter(\.enabled)
    }

    /// 兼容旧 settings.json（仅 emailAlertModeEnabled 等字段）。
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
            alertChannels = ch
        }
        apiQueryEnabled = try c.decodeIfPresent(Bool.self, forKey: .apiQueryEnabled) ?? true
        platformMailEnabled = try c.decodeIfPresent(Bool.self, forKey: .platformMailEnabled) ?? true
        refreshIntervalSecs = try c.decodeIfPresent(Int.self, forKey: .refreshIntervalSecs) ?? 600
        lastAlertAtByAccount = try c.decodeIfPresent([String: Date].self, forKey: .lastAlertAtByAccount) ?? [:]
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
    }

    private enum CodingKeys: String, CodingKey {
        case accounts, mailSources, inboundMailbox, email, alertChannels
        case apiQueryEnabled, platformMailEnabled, refreshIntervalSecs, lastAlertAtByAccount
        case emailAlertModeEnabled
    }
}
