import Foundation

public enum UsageStorageLastError: String, Sendable, Equatable {
    case load
    case save
}

public enum UsageStorageHealth: String, Codable, Sendable, Equatable {
    case available
    case needsRestore
    case lastSaveFailed
    case loadFailed

    public var messageKey: String {
        switch self {
        case .available:
            return "usage.health.available"
        case .needsRestore:
            return "usage.health.needs_restore"
        case .lastSaveFailed:
            return "usage.health.save_failed"
        case .loadFailed:
            return "usage.health.load_failed"
        }
    }

    public var isUserVisibleWarning: Bool { self != .available }

    public static func resolve(
        recoveredFromCorruptFile: Bool,
        lastError: UsageStorageLastError? = nil
    ) -> UsageStorageHealth {
        switch lastError {
        case .load:
            return .loadFailed
        case .save:
            return .lastSaveFailed
        case nil:
            return recoveredFromCorruptFile ? .needsRestore : .available
        }
    }
}

public struct UsageRefreshDisplay: Equatable, Sendable {
    public var showsBalances: Bool
    public var health: UsageStorageHealth
    public var balanceAndUsageIndependent: Bool

    public init(showsBalances: Bool, health: UsageStorageHealth, balanceAndUsageIndependent: Bool) {
        self.showsBalances = showsBalances
        self.health = health
        self.balanceAndUsageIndependent = balanceAndUsageIndependent
    }
}

public enum UsageRefreshDisplayPolicy: Sendable {
    public static func applyRefreshTerminal(
        balanceSucceeded: Bool,
        usageSaveFailed: Bool,
        usageLoadFailed: Bool,
        recoveredFromCorruptFile: Bool
    ) -> UsageRefreshDisplay {
        let error: UsageStorageLastError?
        if usageLoadFailed {
            error = .load
        } else if usageSaveFailed {
            error = .save
        } else {
            error = nil
        }
        let health = UsageStorageHealth.resolve(
            recoveredFromCorruptFile: recoveredFromCorruptFile,
            lastError: error
        )
        return UsageRefreshDisplay(
            showsBalances: balanceSucceeded,
            health: health,
            balanceAndUsageIndependent: true
        )
    }
}
