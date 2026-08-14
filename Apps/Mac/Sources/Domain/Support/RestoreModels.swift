import Foundation

/// What a settings-transfer or local-restore preview will overwrite.
public enum TransferCoverageItem: String, Codable, Sendable, Equatable, CaseIterable {
    case accounts
    case alertsAndMail
    case refreshThemeLanguage
    case usageHistory
}

public enum SettingsTransferError: Error, Equatable, Sendable, LocalizedError {
    case formatMismatch
    case versionTooNew(Int)
    case decodeFailed
    case encodeFailed
    case writeFailed
    case legacyImportNotConfirmed
    case corruptUsage

    public var errorDescription: String? {
        switch self {
        case .formatMismatch:
            return "backup format does not match"
        case .versionTooNew(let version):
            return "backup version \(version) is newer than supported"
        case .decodeFailed:
            return "backup decode failed"
        case .encodeFailed:
            return "backup encode failed"
        case .writeFailed:
            return "backup write failed"
        case .legacyImportNotConfirmed:
            return "legacy secret backup was not confirmed"
        case .corruptUsage:
            return "usage history in backup is corrupt"
        }
    }
}

/// Non-secret preview of a transfer or restore package. Building it must not write files.
public struct TransferPreview: Equatable, Sendable {
    public var format: String
    public var formatVersion: Int
    public var appVersion: String
    public var exportedAt: Date
    public var accountCount: Int
    public var providers: [ProviderKind]
    public var credentialsNeedReentryNames: [String]
    public var coverage: [TransferCoverageItem]
    public var excludedFields: [String]
    public var includesUsageHistory: Bool
    public var usageRecordCount: Int
    public var usageSchemaVersion: Int?
    public var isLegacySecretBackup: Bool
    public var legacyWarning: String?
    public var defaultImportEnabled: Bool
    public var settings: AppSettings
    public var usageHistory: UsageHistoryDocument?
    public var credentialsNeedReentry: Bool

    public static let defaultExcludedFields = DiagnosticReport.defaultExcludedFields

    public static let legacyPlaintextWarning =
        "该文件可能包含旧版明文密钥，智余不会导入或写入其中的密钥"

    public init(
        format: String,
        formatVersion: Int,
        appVersion: String,
        exportedAt: Date,
        accountCount: Int,
        providers: [ProviderKind],
        credentialsNeedReentryNames: [String],
        coverage: [TransferCoverageItem],
        excludedFields: [String] = TransferPreview.defaultExcludedFields,
        includesUsageHistory: Bool,
        usageRecordCount: Int = 0,
        usageSchemaVersion: Int? = nil,
        isLegacySecretBackup: Bool,
        legacyWarning: String? = nil,
        defaultImportEnabled: Bool,
        settings: AppSettings,
        usageHistory: UsageHistoryDocument? = nil,
        credentialsNeedReentry: Bool
    ) {
        self.format = format
        self.formatVersion = formatVersion
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.accountCount = accountCount
        self.providers = providers
        self.credentialsNeedReentryNames = credentialsNeedReentryNames
        self.coverage = coverage
        self.excludedFields = excludedFields
        self.includesUsageHistory = includesUsageHistory
        self.usageRecordCount = usageRecordCount
        self.usageSchemaVersion = usageSchemaVersion
        self.isLegacySecretBackup = isLegacySecretBackup
        self.legacyWarning = legacyWarning
        self.defaultImportEnabled = defaultImportEnabled
        self.settings = settings
        self.usageHistory = usageHistory
        self.credentialsNeedReentry = credentialsNeedReentry
    }

    public static func make(
        portable: PortableSettings,
        usage: UsageHistoryDocument? = nil,
        isLegacy: Bool = false,
        legacyWarning: String? = nil
    ) -> TransferPreview {
        let imported = portable.importAsSettings()
        var coverage: [TransferCoverageItem] = [.accounts, .alertsAndMail, .refreshThemeLanguage]
        if usage != nil {
            coverage.append(.usageHistory)
        }
        let names = portable.accounts.map(\.displayName)
        return TransferPreview(
            format: portable.format,
            formatVersion: portable.formatVersion,
            appVersion: portable.appVersion,
            exportedAt: portable.exportedAt,
            accountCount: portable.accounts.count,
            providers: portable.accounts.map(\.kind),
            credentialsNeedReentryNames: names,
            coverage: coverage,
            includesUsageHistory: usage != nil,
            usageRecordCount: usage?.dailyRecords.count ?? 0,
            usageSchemaVersion: usage?.schemaVersion,
            isLegacySecretBackup: isLegacy,
            legacyWarning: isLegacy ? (legacyWarning ?? legacyPlaintextWarning) : nil,
            defaultImportEnabled: !isLegacy,
            settings: imported.settings,
            usageHistory: usage,
            credentialsNeedReentry: imported.credentialsNeedReentry
        )
    }
}

public struct RestoreMetadata: Codable, Sendable, Equatable {
    public var includeUsageHistory: Bool
    public var createdReason: String

    public init(includeUsageHistory: Bool, createdReason: String = "local-backup") {
        self.includeUsageHistory = includeUsageHistory
        self.createdReason = createdReason
    }
}

/// Local restore package: portable settings fields plus optional aggregated usage.
public struct LocalRestorePackage: Codable, Sendable, Equatable {
    public static let formatID = "smartbalance.local-restore"
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
    public var usageHistory: UsageHistoryDocument?
    public var restoreMetadata: RestoreMetadata

    public init(
        format: String = LocalRestorePackage.formatID,
        formatVersion: Int = LocalRestorePackage.currentFormatVersion,
        exportedAt: Date = Date(),
        appVersion: String,
        accounts: [PortableAccount],
        email: PortableEmailSettings,
        alertChannels: AlertChannelSettings,
        apiQueryEnabled: Bool,
        refreshIntervalSecs: Int,
        windowPinned: Bool,
        themeMode: String,
        appLanguage: String,
        usageHistory: UsageHistoryDocument? = nil,
        restoreMetadata: RestoreMetadata
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
        self.usageHistory = usageHistory
        self.restoreMetadata = restoreMetadata
    }

    public static func make(
        from settings: AppSettings,
        usage: UsageHistoryDocument?,
        appVersion: String,
        now: Date = Date()
    ) -> LocalRestorePackage {
        let portable = PortableSettings.make(from: settings, appVersion: appVersion, now: now)
        return LocalRestorePackage(
            exportedAt: now,
            appVersion: appVersion,
            accounts: portable.accounts,
            email: portable.email,
            alertChannels: portable.alertChannels,
            apiQueryEnabled: portable.apiQueryEnabled,
            refreshIntervalSecs: portable.refreshIntervalSecs,
            windowPinned: portable.windowPinned,
            themeMode: portable.themeMode,
            appLanguage: portable.appLanguage,
            usageHistory: usage,
            restoreMetadata: RestoreMetadata(includeUsageHistory: usage != nil)
        )
    }

    public var asPortableSettings: PortableSettings {
        PortableSettings(
            exportedAt: exportedAt,
            appVersion: appVersion,
            accounts: accounts,
            email: email,
            alertChannels: alertChannels,
            apiQueryEnabled: apiQueryEnabled,
            refreshIntervalSecs: refreshIntervalSecs,
            windowPinned: windowPinned,
            themeMode: themeMode,
            appLanguage: appLanguage
        )
    }

    public func asPreview() -> TransferPreview {
        TransferPreview.make(
            portable: asPortableSettings,
            usage: usageHistory,
            isLegacy: false
        )
    }

    public static func encode(_ value: LocalRestorePackage) throws -> Data {
        try SettingsDocument.makeEncoder().encode(value)
    }

    public static func decode(_ data: Data) throws -> LocalRestorePackage {
        try SettingsDocument.makeDecoder().decode(LocalRestorePackage.self, from: data)
    }
}

public enum RestoreStatus: String, Sendable, Equatable {
    case cancelled
    case failed
    case succeeded
}

public enum RestoreFailureReason: String, Sendable, Equatable {
    case cancelled
    case formatMismatch
    case versionTooNew
    case corruptUsage
    case settingsWriteFailed
    case usageWriteFailed
    case snapshotFailed
    case validationFailed
}

public struct RestoreOutcome: Equatable, Sendable {
    public var status: RestoreStatus
    public var failureReason: RestoreFailureReason?
    public var settingsSnapshotURL: URL?
    public var usageSnapshotURL: URL?
    public var credentialsNeedReentry: Bool
    public var rolledBack: Bool
    public var includedUsage: Bool
    public var settings: AppSettings?
    public var usageHistory: UsageHistoryDocument?

    public init(
        status: RestoreStatus,
        failureReason: RestoreFailureReason? = nil,
        settingsSnapshotURL: URL? = nil,
        usageSnapshotURL: URL? = nil,
        credentialsNeedReentry: Bool = false,
        rolledBack: Bool = false,
        includedUsage: Bool = false,
        settings: AppSettings? = nil,
        usageHistory: UsageHistoryDocument? = nil
    ) {
        self.status = status
        self.failureReason = failureReason
        self.settingsSnapshotURL = settingsSnapshotURL
        self.usageSnapshotURL = usageSnapshotURL
        self.credentialsNeedReentry = credentialsNeedReentry
        self.rolledBack = rolledBack
        self.includedUsage = includedUsage
        self.settings = settings
        self.usageHistory = usageHistory
    }

    public static func cancelled() -> RestoreOutcome {
        RestoreOutcome(status: .cancelled, failureReason: .cancelled)
    }

    public static func failed(
        _ reason: RestoreFailureReason,
        rolledBack: Bool = false,
        settingsSnapshotURL: URL? = nil,
        usageSnapshotURL: URL? = nil
    ) -> RestoreOutcome {
        RestoreOutcome(
            status: .failed,
            failureReason: reason,
            settingsSnapshotURL: settingsSnapshotURL,
            usageSnapshotURL: usageSnapshotURL,
            rolledBack: rolledBack
        )
    }
}

/// Non-sensitive credential presence. Never carries Keychain values.
public enum CredentialPresence: String, Sendable, Equatable {
    case present
    case missing
}
