import Foundation

public enum DeletedAccountCompatibilityScope: String, Codable, Sendable, Equatable {
    case dropBaselineKeepDailyRecords

    public var messageKey: String {
        "compat.usage.deletedAccount.dropBaselineKeepDaily"
    }
}

public enum NotificationPermissionInput: String, Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case provisional
    case ephemeral
    case unknown
}

public struct NotificationPermissionStatus: Equatable, Sendable, Codable {
    public var state: NotificationAuthorizationState
    public var messageKey: String
    public var blocksBalanceRefresh: Bool
    public var containsSensitivePayload: Bool

    public init(
        state: NotificationAuthorizationState,
        messageKey: String,
        blocksBalanceRefresh: Bool = false,
        containsSensitivePayload: Bool = false
    ) {
        self.state = state
        self.messageKey = messageKey
        self.blocksBalanceRefresh = blocksBalanceRefresh
        self.containsSensitivePayload = containsSensitivePayload
    }
}

public enum NotificationPermissionMapping: Sendable {
    public static func state(from input: NotificationPermissionInput) -> NotificationAuthorizationState {
        switch input {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .provisional:
            return .provisional
        case .ephemeral:
            return .authorized
        case .unknown:
            return .unknown
        }
    }

    public static func status(from state: NotificationAuthorizationState) -> NotificationPermissionStatus {
        let key: String
        switch state {
        case .authorized, .provisional:
            key = "compat.notifications.authorized"
        case .notDetermined:
            key = "compat.notifications.notDetermined"
        case .denied:
            key = "compat.notifications.denied"
        case .restricted:
            key = "compat.notifications.restricted"
        case .unknown:
            key = "compat.notifications.unknown"
        }
        return NotificationPermissionStatus(
            state: state,
            messageKey: key,
            blocksBalanceRefresh: false,
            containsSensitivePayload: false
        )
    }

    public static func allowsBalanceRefresh(_ state: NotificationAuthorizationState) -> Bool {
        true
    }
}

public struct CompatibilityMigrationResult: Equatable, Sendable {
    public var settingsReadable: Bool
    public var sourceSchemaVersion: Int?
    public var didMigrate: Bool
    public var unknownProviderKinds: [String]
    public var unknownCurrencyUnits: [String]
    public var usageHealth: UsageStorageHealth
    public var notification: NotificationPermissionStatus
    public var deletedAccountScope: DeletedAccountCompatibilityScope
    public var checks: [CompatibilityCheck]

    public init(
        settingsReadable: Bool,
        sourceSchemaVersion: Int?,
        didMigrate: Bool,
        unknownProviderKinds: [String],
        unknownCurrencyUnits: [String],
        usageHealth: UsageStorageHealth,
        notification: NotificationPermissionStatus,
        deletedAccountScope: DeletedAccountCompatibilityScope = .dropBaselineKeepDailyRecords,
        checks: [CompatibilityCheck]
    ) {
        self.settingsReadable = settingsReadable
        self.sourceSchemaVersion = sourceSchemaVersion
        self.didMigrate = didMigrate
        self.unknownProviderKinds = unknownProviderKinds
        self.unknownCurrencyUnits = unknownCurrencyUnits
        self.usageHealth = usageHealth
        self.notification = notification
        self.deletedAccountScope = deletedAccountScope
        self.checks = checks
    }

    public var hasBlockingIssue: Bool {
        checks.contains { $0.status == .failed }
    }

    public static func inspect(
        settingsOutcome: SettingsMigrationOutcome?,
        settingsError: SettingsMigrationError? = nil,
        usageHealth: UsageStorageHealth,
        notification: NotificationAuthorizationState
    ) -> CompatibilityMigrationResult {
        let permission = NotificationPermissionMapping.status(from: notification)
        let settingsReadable: Bool
        let sourceSchemaVersion: Int?
        let didMigrate: Bool
        let unknownProviders: [String]
        let unknownUnits: [String]
        let settingsCheck: CompatibilityCheck
        let schemaCheck: CompatibilityCheck

        if let settingsError {
            settingsReadable = false
            sourceSchemaVersion = nil
            didMigrate = false
            unknownProviders = []
            unknownUnits = []
            switch settingsError {
            case .invalidJSON:
                settingsCheck = CompatibilityCheck(
                    id: CompatibilityCheckID.settings.rawValue,
                    status: .failed,
                    messageKey: "compat.settings.corrupt"
                )
                schemaCheck = CompatibilityCheck(
                    id: CompatibilityCheckID.schema.rawValue,
                    status: .warning,
                    messageKey: "compat.schema.unreadable"
                )
            case .unsupportedSchemaVersion:
                settingsCheck = CompatibilityCheck(
                    id: CompatibilityCheckID.settings.rawValue,
                    status: .ok,
                    messageKey: "compat.settings.ok"
                )
                schemaCheck = CompatibilityCheck(
                    id: CompatibilityCheckID.schema.rawValue,
                    status: .failed,
                    messageKey: "compat.schema.unsupported"
                )
            }
        } else if let outcome = settingsOutcome {
            settingsReadable = true
            sourceSchemaVersion = outcome.sourceSchemaVersion
            didMigrate = outcome.didMigrate
            unknownProviders = Self.unknownProviders(in: outcome.document.settings)
            unknownUnits = Self.unknownCurrencies(in: outcome.document.settings)
            settingsCheck = CompatibilityCheck(
                id: CompatibilityCheckID.settings.rawValue,
                status: .ok,
                messageKey: "compat.settings.ok"
            )
            schemaCheck = CompatibilityCheck(
                id: CompatibilityCheckID.schema.rawValue,
                status: .ok,
                messageKey: outcome.sourceSchemaVersion == 0 ? "compat.schema.legacy" : "compat.schema.ok"
            )
        } else {
            settingsReadable = true
            sourceSchemaVersion = nil
            didMigrate = false
            unknownProviders = []
            unknownUnits = []
            settingsCheck = CompatibilityCheck(
                id: CompatibilityCheckID.settings.rawValue,
                status: .warning,
                messageKey: "compat.settings.missing"
            )
            schemaCheck = CompatibilityCheck(
                id: CompatibilityCheckID.schema.rawValue,
                status: .warning,
                messageKey: "compat.schema.missing"
            )
        }

        let usageCheck = CompatibilityCheck(
            id: CompatibilityCheckID.usageHistory.rawValue,
            status: usageHealth.isUserVisibleWarning ? .warning : .ok,
            messageKey: Self.usageMessageKey(usageHealth)
        )
        let notificationCheck = CompatibilityCheck(
            id: CompatibilityCheckID.notifications.rawValue,
            status: notification == .authorized || notification == .provisional ? .ok : .warning,
            messageKey: permission.messageKey
        )
        let providerCheck = CompatibilityCheck(
            id: CompatibilityCheckID.schema.rawValue + ".providers",
            status: unknownProviders.isEmpty ? .ok : .warning,
            messageKey: unknownProviders.isEmpty ? "compat.providers.ok" : "compat.providers.unknown"
        )

        return CompatibilityMigrationResult(
            settingsReadable: settingsReadable,
            sourceSchemaVersion: sourceSchemaVersion,
            didMigrate: didMigrate,
            unknownProviderKinds: unknownProviders,
            unknownCurrencyUnits: unknownUnits,
            usageHealth: usageHealth,
            notification: permission,
            deletedAccountScope: .dropBaselineKeepDailyRecords,
            checks: [settingsCheck, schemaCheck, usageCheck, notificationCheck, providerCheck]
        )
    }

    public static func unknownProviders(in settings: AppSettings) -> [String] {
        settings.accounts.compactMap { account in
            guard !account.kind.isRecognized else { return nil }
            let raw = account.unrecognizedKind?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return raw.isEmpty ? account.kind.rawValue : raw
        }
        .sorted()
    }

    public static func unknownCurrencies(in settings: AppSettings) -> [String] {
        let units = settings.accounts.compactMap { account -> String? in
            guard let raw = account.manualUnit?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty
            else { return nil }
            let normalized = UsageUnit.normalize(raw)
            if normalized == "CNY" || normalized == "USD" { return nil }
            return normalized
        }
        return Array(Set(units)).sorted()
    }

    private static func usageMessageKey(_ health: UsageStorageHealth) -> String {
        switch health {
        case .available:
            return "compat.usage.ok"
        case .needsRestore:
            return "compat.usage.needsRestore"
        case .lastSaveFailed:
            return "compat.usage.saveFailed"
        case .loadFailed:
            return "compat.usage.unreadable"
        }
    }
}
