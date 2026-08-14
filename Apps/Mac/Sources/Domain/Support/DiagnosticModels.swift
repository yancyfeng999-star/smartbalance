import Foundation

public struct DiagnosticCheck: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var titleKey: String
    public var status: DiagnosticStatus
    public var detailKey: String
    public var redactedDetail: String?

    public init(
        id: String,
        titleKey: String,
        status: DiagnosticStatus,
        detailKey: String,
        redactedDetail: String? = nil
    ) {
        self.id = id
        self.titleKey = titleKey
        self.status = status
        self.detailKey = detailKey
        self.redactedDetail = redactedDetail
    }

    public init(
        id: DiagnosticCheckID,
        status: DiagnosticStatus,
        detailKey: String,
        redactedDetail: String? = nil
    ) {
        self.init(
            id: id.rawValue,
            titleKey: "diagnostics.check.\(id.rawValue)",
            status: status,
            detailKey: detailKey,
            redactedDetail: redactedDetail
        )
    }

    public var checkID: DiagnosticCheckID? {
        DiagnosticCheckID(rawValue: id)
    }
}

public struct DiagnosticDirectoryProbe: Codable, Sendable, Equatable {
    public var writable: Bool
    public var posixPermissions: String?
    public var fileSizeBytes: Int64?

    public init(writable: Bool, posixPermissions: String? = nil, fileSizeBytes: Int64? = nil) {
        self.writable = writable
        self.posixPermissions = posixPermissions
        self.fileSizeBytes = fileSizeBytes
    }
}

public struct DiagnosticDirectories: Codable, Sendable, Equatable {
    public var applicationSupport: DiagnosticDirectoryProbe
    public var logs: DiagnosticDirectoryProbe
    public var temporary: DiagnosticDirectoryProbe

    public init(
        applicationSupport: DiagnosticDirectoryProbe,
        logs: DiagnosticDirectoryProbe,
        temporary: DiagnosticDirectoryProbe
    ) {
        self.applicationSupport = applicationSupport
        self.logs = logs
        self.temporary = temporary
    }
}

public struct DiagnosticProviderSummary: Codable, Sendable, Equatable {
    public var kind: String
    public var enabled: Bool
    public var hasCredentialRef: Bool

    public init(kind: String, enabled: Bool, hasCredentialRef: Bool) {
        self.kind = kind
        self.enabled = enabled
        self.hasCredentialRef = hasCredentialRef
    }

    public init(account: BalanceAccount) {
        self.init(
            kind: account.kind.rawValue,
            enabled: account.enabled,
            hasCredentialRef: !account.secretRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }
}

public struct DiagnosticRefreshSummary: Codable, Sendable, Equatable {
    public var state: String
    public var lastRefreshAt: Date?
    public var succeededCount: Int
    public var failedCount: Int

    public init(
        state: String,
        lastRefreshAt: Date? = nil,
        succeededCount: Int = 0,
        failedCount: Int = 0
    ) {
        self.state = state
        self.lastRefreshAt = lastRefreshAt
        self.succeededCount = succeededCount
        self.failedCount = failedCount
    }

    public init(refreshState: RefreshState, lastRefreshAt: Date? = nil, succeededCount: Int = 0, failedCount: Int = 0) {
        self.init(
            state: Self.stateName(refreshState),
            lastRefreshAt: lastRefreshAt,
            succeededCount: succeededCount,
            failedCount: failedCount
        )
    }

    public static func stateName(_ state: RefreshState) -> String {
        switch state {
        case .idle: return "idle"
        case .running: return "running"
        case .cancelling: return "cancelling"
        case .succeeded: return "succeeded"
        case .partiallyFailed: return "partiallyFailed"
        case .failed: return "failed"
        }
    }
}

public struct DiagnosticUsageSummary: Codable, Sendable, Equatable {
    public var recordCount: Int
    public var earliestDate: String?
    public var latestDate: String?
    public var unitCategories: [String]
    public var saveErrorClassification: String?

    public init(
        recordCount: Int,
        earliestDate: String? = nil,
        latestDate: String? = nil,
        unitCategories: [String] = [],
        saveErrorClassification: String? = nil
    ) {
        self.recordCount = recordCount
        self.earliestDate = earliestDate
        self.latestDate = latestDate
        self.unitCategories = unitCategories
        self.saveErrorClassification = saveErrorClassification
    }

    public init(document: UsageHistoryDocument, saveErrorClassification: String? = nil) {
        let days = document.dailyRecords.map(\.dayKey)
        let units = Set(document.dailyRecords.map { UsageUnit.normalize($0.unit) }).sorted()
        self.init(
            recordCount: document.dailyRecords.count,
            earliestDate: days.min(),
            latestDate: days.max(),
            unitCategories: units,
            saveErrorClassification: saveErrorClassification
        )
    }
}

public struct DiagnosticReport: Codable, Sendable, Equatable {
    public static let allowedTopLevelKeys: Set<String> = [
        "generatedAt",
        "appVersion",
        "build",
        "osVersion",
        "architecture",
        "launchMode",
        "schemaVersion",
        "checks",
        "sanitizedLogLines",
        "excludedFields",
        "keychainStatus",
        "notificationAuthorization",
        "refresh",
        "providers",
        "usage",
        "directories",
        "lastMigrationResult",
        "lastBackupResult",
        "lastRestoreResult",
    ]

    public static let defaultExcludedFields: [String] = [
        "secrets",
        "secretRef",
        "passwordRef",
        "Authorization",
        "Bearer",
        "Cookie",
        "api_key",
        "smtpPassword",
        "rawResponse",
        "requestURL",
        "keychainService",
        "keychainAccount",
        "secretValue",
        "fullAppLog",
    ]

    public var generatedAt: Date
    public var appVersion: String
    public var build: String
    public var osVersion: String
    public var architecture: String
    public var launchMode: String
    public var schemaVersion: Int?
    public var checks: [DiagnosticCheck]
    public var sanitizedLogLines: [String]
    public var excludedFields: [String]
    public var keychainStatus: DiagnosticKeychainStatus
    public var notificationAuthorization: String
    public var refresh: DiagnosticRefreshSummary
    public var providers: [DiagnosticProviderSummary]
    public var usage: DiagnosticUsageSummary
    public var directories: DiagnosticDirectories
    public var lastMigrationResult: String
    public var lastBackupResult: String
    public var lastRestoreResult: String

    public init(
        generatedAt: Date,
        appVersion: String,
        build: String,
        osVersion: String,
        architecture: String,
        launchMode: String,
        schemaVersion: Int? = nil,
        checks: [DiagnosticCheck],
        sanitizedLogLines: [String] = [],
        excludedFields: [String] = DiagnosticReport.defaultExcludedFields,
        keychainStatus: DiagnosticKeychainStatus,
        notificationAuthorization: String,
        refresh: DiagnosticRefreshSummary,
        providers: [DiagnosticProviderSummary],
        usage: DiagnosticUsageSummary,
        directories: DiagnosticDirectories,
        lastMigrationResult: String = "none",
        lastBackupResult: String = "none",
        lastRestoreResult: String = "none"
    ) {
        self.generatedAt = generatedAt
        self.appVersion = appVersion
        self.build = build
        self.osVersion = osVersion
        self.architecture = architecture
        self.launchMode = launchMode
        self.schemaVersion = schemaVersion
        self.checks = checks
        self.sanitizedLogLines = sanitizedLogLines
        self.excludedFields = excludedFields
        self.keychainStatus = keychainStatus
        self.notificationAuthorization = notificationAuthorization
        self.refresh = refresh
        self.providers = providers
        self.usage = usage
        self.directories = directories
        self.lastMigrationResult = lastMigrationResult
        self.lastBackupResult = lastBackupResult
        self.lastRestoreResult = lastRestoreResult
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public static func encode(_ report: DiagnosticReport) throws -> Data {
        try makeEncoder().encode(report)
    }

    public func check(_ id: DiagnosticCheckID) -> DiagnosticCheck? {
        checks.first { $0.id == id.rawValue }
    }

    public var hasBlockingIssue: Bool {
        checks.contains { $0.status == .failed }
    }
}

public struct DiagnosticsContext: Sendable, Equatable {
    public var now: Date
    public var appVersion: String
    public var build: String
    public var osVersion: String
    public var architecture: String
    public var launchMode: DiagnosticLaunchMode
    public var schemaVersion: Int?
    public var applicationSupport: DiagnosticDirectoryProbe
    public var logs: DiagnosticDirectoryProbe
    public var temporary: DiagnosticDirectoryProbe
    public var settingsReadable: Bool
    public var settingsSchemaSupported: Bool
    public var usageHistoryReadable: Bool
    public var lastMigrationResult: String
    public var lastBackupResult: String
    public var lastRestoreResult: String
    public var keychainStatus: DiagnosticKeychainStatus
    public var notificationAuthorization: NotificationAuthorizationState
    public var refresh: DiagnosticRefreshSummary
    public var providers: [DiagnosticProviderSummary]
    public var usage: DiagnosticUsageSummary
    public var logFileURL: URL?

    public init(
        now: Date,
        appVersion: String,
        build: String,
        osVersion: String,
        architecture: String,
        launchMode: DiagnosticLaunchMode,
        schemaVersion: Int? = nil,
        applicationSupport: DiagnosticDirectoryProbe,
        logs: DiagnosticDirectoryProbe,
        temporary: DiagnosticDirectoryProbe,
        settingsReadable: Bool,
        settingsSchemaSupported: Bool,
        usageHistoryReadable: Bool,
        lastMigrationResult: String,
        lastBackupResult: String,
        lastRestoreResult: String,
        keychainStatus: DiagnosticKeychainStatus,
        notificationAuthorization: NotificationAuthorizationState,
        refresh: DiagnosticRefreshSummary,
        providers: [DiagnosticProviderSummary],
        usage: DiagnosticUsageSummary,
        logFileURL: URL? = nil
    ) {
        self.now = now
        self.appVersion = appVersion
        self.build = build
        self.osVersion = osVersion
        self.architecture = architecture
        self.launchMode = launchMode
        self.schemaVersion = schemaVersion
        self.applicationSupport = applicationSupport
        self.logs = logs
        self.temporary = temporary
        self.settingsReadable = settingsReadable
        self.settingsSchemaSupported = settingsSchemaSupported
        self.usageHistoryReadable = usageHistoryReadable
        self.lastMigrationResult = lastMigrationResult
        self.lastBackupResult = lastBackupResult
        self.lastRestoreResult = lastRestoreResult
        self.keychainStatus = keychainStatus
        self.notificationAuthorization = notificationAuthorization
        self.refresh = refresh
        self.providers = providers
        self.usage = usage
        self.logFileURL = logFileURL
    }
}

public enum DiagnosticBannerPolicy: Sendable {
    public static func shouldOfferDiagnostics(
        noticeKey: String?,
        usageDataError: String?,
        usageRecoveryNotice: Bool
    ) -> Bool {
        if usageDataError != nil { return true }
        if usageRecoveryNotice { return true }
        guard let noticeKey else { return false }
        switch noticeKey {
        case RefreshMessageKey.failed,
             RefreshMessageKey.partialFailed,
             RefreshMessageKey.usageSaveFailed,
             "usage.load_failed":
            return true
        default:
            return false
        }
    }
}
