import Foundation

/// 可迁移账号：不含 secretRef / 密钥值。
public struct PortableAccount: Codable, Sendable, Equatable {
    public var id: UUID
    public var kind: ProviderKind
    public var displayName: String
    public var baseURL: String?
    public var consoleURL: String?
    public var userId: String?
    public var enabled: Bool
    public var alertThreshold: Double?
    public var alertPercentThreshold: Double?
    public var manualAmount: Double?
    public var manualUnit: String?
    public var manualUpdatedAt: Date?
    public var dailyReminderEnabled: Bool?

    public init(
        id: UUID,
        kind: ProviderKind,
        displayName: String,
        baseURL: String? = nil,
        consoleURL: String? = nil,
        userId: String? = nil,
        enabled: Bool = true,
        alertThreshold: Double? = nil,
        alertPercentThreshold: Double? = nil,
        manualAmount: Double? = nil,
        manualUnit: String? = nil,
        manualUpdatedAt: Date? = nil,
        dailyReminderEnabled: Bool? = nil
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.baseURL = baseURL
        self.consoleURL = consoleURL
        self.userId = userId
        self.enabled = enabled
        self.alertThreshold = alertThreshold
        self.alertPercentThreshold = alertPercentThreshold
        self.manualAmount = manualAmount
        self.manualUnit = manualUnit
        self.manualUpdatedAt = manualUpdatedAt
        self.dailyReminderEnabled = dailyReminderEnabled
    }

    public init(account: BalanceAccount) {
        self.init(
            id: account.id,
            kind: account.kind,
            displayName: account.displayName,
            baseURL: account.baseURL,
            consoleURL: account.consoleURL,
            userId: account.userId,
            enabled: account.enabled,
            alertThreshold: account.alertThreshold,
            alertPercentThreshold: account.alertPercentThreshold,
            manualAmount: account.manualAmount,
            manualUnit: account.manualUnit,
            manualUpdatedAt: account.manualUpdatedAt,
            dailyReminderEnabled: account.dailyReminderEnabled
        )
    }

    public func materialize() -> BalanceAccount {
        BalanceAccount(
            id: id,
            kind: kind,
            displayName: displayName,
            baseURL: baseURL,
            consoleURL: consoleURL,
            userId: userId,
            secretRef: BalanceAccount.makeNewSecretRef(),
            enabled: enabled,
            alertThreshold: alertThreshold,
            alertPercentThreshold: alertPercentThreshold,
            manualAmount: manualAmount,
            manualUnit: manualUnit,
            manualUpdatedAt: manualUpdatedAt,
            dailyReminderEnabled: dailyReminderEnabled
        )
    }
}

/// 可迁移 SMTP 元数据：不含 passwordRef / 密码。
public struct PortableEmailSettings: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var smtpHost: String
    public var smtpPort: Int
    public var useTLS: Bool
    public var username: String
    public var fromAddress: String
    public var toAddresses: [String]
    public var defaultAmountThreshold: Double
    public var defaultPercentThreshold: Double
    public var cooldownSeconds: Int

    public init(
        enabled: Bool,
        smtpHost: String,
        smtpPort: Int,
        useTLS: Bool,
        username: String,
        fromAddress: String,
        toAddresses: [String],
        defaultAmountThreshold: Double,
        defaultPercentThreshold: Double,
        cooldownSeconds: Int
    ) {
        self.enabled = enabled
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.useTLS = useTLS
        self.username = username
        self.fromAddress = fromAddress
        self.toAddresses = toAddresses
        self.defaultAmountThreshold = defaultAmountThreshold
        self.defaultPercentThreshold = defaultPercentThreshold
        self.cooldownSeconds = cooldownSeconds
    }

    public init(email: EmailAlertSettings) {
        self.init(
            enabled: email.enabled,
            smtpHost: email.smtpHost,
            smtpPort: email.smtpPort,
            useTLS: email.useTLS,
            username: email.username,
            fromAddress: email.fromAddress,
            toAddresses: email.toAddresses,
            defaultAmountThreshold: email.defaultAmountThreshold,
            defaultPercentThreshold: email.defaultPercentThreshold,
            cooldownSeconds: email.cooldownSeconds
        )
    }

    public func materialize() -> EmailAlertSettings {
        EmailAlertSettings(
            enabled: enabled,
            smtpHost: smtpHost,
            smtpPort: smtpPort,
            useTLS: useTLS,
            username: username,
            passwordRef: EmailAlertSettings.makeNewPasswordRef(),
            fromAddress: fromAddress,
            toAddresses: toAddresses,
            defaultAmountThreshold: defaultAmountThreshold,
            defaultPercentThreshold: defaultPercentThreshold,
            cooldownSeconds: cooldownSeconds
        )
    }
}

public struct PortableImportResult: Equatable, Sendable {
    public var settings: AppSettings
    public var credentialsNeedReentry: Bool

    public init(settings: AppSettings, credentialsNeedReentry: Bool) {
        self.settings = settings
        self.credentialsNeedReentry = credentialsNeedReentry
    }
}

/// 非敏感设置迁移包 `smartbalance.portable-settings` v2。
public struct PortableSettings: Codable, Sendable, Equatable {
    public static let formatID = "smartbalance.portable-settings"
    public static let currentFormatVersion = 2

    public var format: String
    public var formatVersion: Int
    public var exportedAt: Date
    public var appVersion: String
    public var accounts: [PortableAccount]
    public var email: PortableEmailSettings
    public var alertChannels: AlertChannelSettings
    public var apiQueryEnabled: Bool
    public var refreshIntervalSecs: Int
    public var windowPinned: Bool
    public var themeMode: String
    public var appLanguage: String

    public init(
        format: String = PortableSettings.formatID,
        formatVersion: Int = PortableSettings.currentFormatVersion,
        exportedAt: Date = Date(),
        appVersion: String,
        accounts: [PortableAccount],
        email: PortableEmailSettings,
        alertChannels: AlertChannelSettings,
        apiQueryEnabled: Bool,
        refreshIntervalSecs: Int,
        windowPinned: Bool,
        themeMode: String,
        appLanguage: String
    ) {
        self.format = format
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.accounts = accounts
        self.email = email
        self.alertChannels = alertChannels
        self.apiQueryEnabled = apiQueryEnabled
        self.refreshIntervalSecs = refreshIntervalSecs
        self.windowPinned = windowPinned
        self.themeMode = themeMode
        self.appLanguage = appLanguage
    }

    public static func make(
        from settings: AppSettings,
        appVersion: String,
        now: Date = Date()
    ) -> PortableSettings {
        PortableSettings(
            exportedAt: now,
            appVersion: appVersion,
            accounts: settings.accounts.map(PortableAccount.init(account:)),
            email: PortableEmailSettings(email: settings.email),
            alertChannels: settings.alertChannels,
            apiQueryEnabled: settings.apiQueryEnabled,
            refreshIntervalSecs: settings.refreshIntervalSecs,
            windowPinned: settings.windowPinned,
            themeMode: settings.themeMode,
            appLanguage: settings.appLanguage
        )
    }

    public func importAsSettings() -> PortableImportResult {
        let accounts = accounts.map { $0.materialize() }
        let email = email.materialize()
        let settings = AppSettings(
            accounts: accounts,
            email: email,
            alertChannels: alertChannels,
            apiQueryEnabled: apiQueryEnabled,
            refreshIntervalSecs: refreshIntervalSecs,
            lastAlertAtByAccount: [:],
            windowPinned: windowPinned,
            themeMode: themeMode,
            appLanguage: appLanguage
        )
        let credentialsNeedReentry = !accounts.isEmpty
            || email.enabled
            || email.isConfigured
            || !email.smtpHost.isEmpty
        return PortableImportResult(settings: settings, credentialsNeedReentry: credentialsNeedReentry)
    }

    public static func encode(_ value: PortableSettings) throws -> Data {
        try SettingsDocument.makeEncoder().encode(value)
    }

    public static func decode(_ data: Data) throws -> PortableSettings {
        try SettingsDocument.makeDecoder().decode(PortableSettings.self, from: data)
    }
}
