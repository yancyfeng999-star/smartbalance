import Foundation

public enum CompatibilityStatus: String, Codable, Sendable, Equatable {
    case ok
    case warning
    case failed
    case unknown
}

public enum CompatibilityArchitecture: String, Codable, Sendable, Equatable {
    case appleSilicon
    case intel
    case unknown
}

public enum CompatibilityCheckID: String, Codable, Sendable, Equatable, CaseIterable {
    case macos
    case architecture
    case applicationSupport
    case logs
    case keychain
    case notifications
    case settings
    case usageHistory
    case schema
}

public enum NotificationAuthorizationState: String, Codable, Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case provisional
    case restricted
    case unknown
}

public struct CompatibilityCheck: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var status: CompatibilityStatus
    public var messageKey: String

    public init(id: String, status: CompatibilityStatus, messageKey: String) {
        self.id = id
        self.status = status
        self.messageKey = messageKey
    }

    public var checkID: CompatibilityCheckID? {
        CompatibilityCheckID(rawValue: id)
    }
}

public struct CompatibilityReport: Codable, Sendable, Equatable {
    public var generatedAt: Date
    public var osVersion: String
    public var architecture: String
    public var schemaVersion: Int?
    public var checks: [CompatibilityCheck]

    public init(
        generatedAt: Date,
        osVersion: String,
        architecture: String,
        schemaVersion: Int? = nil,
        checks: [CompatibilityCheck]
    ) {
        self.generatedAt = generatedAt
        self.osVersion = osVersion
        self.architecture = architecture
        self.schemaVersion = schemaVersion
        self.checks = checks
    }

    public var hasBlockingIssue: Bool {
        checks.contains { $0.status == .failed }
    }

    public func check(_ id: CompatibilityCheckID) -> CompatibilityCheck? {
        checks.first { $0.id == id.rawValue }
    }
}

public struct CompatibilityContext: Sendable, Equatable {
    public var now: Date
    public var macOSMajor: Int
    public var macOSMinor: Int
    public var macOSPatch: Int
    public var minimumMacOSMajor: Int
    public var minimumMacOSMinor: Int
    public var minimumMacOSPatch: Int
    public var architecture: CompatibilityArchitecture
    public var applicationSupportDirectory: URL
    public var logsDirectory: URL
    public var isApplicationSupportWritable: Bool
    public var isLogsWritable: Bool
    public var settingsFileURL: URL
    public var usageHistoryFileURL: URL
    public var keychainAvailable: Bool
    public var notificationAuthorization: NotificationAuthorizationState
    public var currentSettingsSchemaVersion: Int
    public var usageStorageHealth: UsageStorageHealth?

    public init(
        now: Date,
        macOSMajor: Int,
        macOSMinor: Int,
        macOSPatch: Int,
        minimumMacOSMajor: Int,
        minimumMacOSMinor: Int,
        minimumMacOSPatch: Int,
        architecture: CompatibilityArchitecture,
        applicationSupportDirectory: URL,
        logsDirectory: URL,
        isApplicationSupportWritable: Bool,
        isLogsWritable: Bool,
        settingsFileURL: URL,
        usageHistoryFileURL: URL,
        keychainAvailable: Bool,
        notificationAuthorization: NotificationAuthorizationState,
        currentSettingsSchemaVersion: Int,
        usageStorageHealth: UsageStorageHealth? = nil
    ) {
        self.now = now
        self.macOSMajor = macOSMajor
        self.macOSMinor = macOSMinor
        self.macOSPatch = macOSPatch
        self.minimumMacOSMajor = minimumMacOSMajor
        self.minimumMacOSMinor = minimumMacOSMinor
        self.minimumMacOSPatch = minimumMacOSPatch
        self.architecture = architecture
        self.applicationSupportDirectory = applicationSupportDirectory
        self.logsDirectory = logsDirectory
        self.isApplicationSupportWritable = isApplicationSupportWritable
        self.isLogsWritable = isLogsWritable
        self.settingsFileURL = settingsFileURL
        self.usageHistoryFileURL = usageHistoryFileURL
        self.keychainAvailable = keychainAvailable
        self.notificationAuthorization = notificationAuthorization
        self.currentSettingsSchemaVersion = currentSettingsSchemaVersion
        self.usageStorageHealth = usageStorageHealth
    }
}
