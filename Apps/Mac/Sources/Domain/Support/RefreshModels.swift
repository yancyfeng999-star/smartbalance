import Foundation

public enum RefreshScope: Sendable, Equatable {
    case all
    case account(UUID)
    case visible

    public func accounts(
        from settings: AppSettings,
        visibleIDs: Set<UUID>? = nil
    ) -> [BalanceAccount] {
        let enabled = settings.enabledAccounts
        switch self {
        case .all:
            return enabled
        case .account(let id):
            return enabled.filter { $0.id == id }
        case .visible:
            guard let visibleIDs else { return enabled }
            return enabled.filter { visibleIDs.contains($0.id) }
        }
    }

    public func accountIDs(
        from settings: AppSettings,
        visibleIDs: Set<UUID>? = nil
    ) -> [UUID] {
        accounts(from: settings, visibleIDs: visibleIDs).map(\.id)
    }
}

public enum RefreshState: Sendable, Equatable {
    case idle
    case running(scope: RefreshScope, startedAt: Date)
    case cancelling
    case succeeded(completedAt: Date, refreshedCount: Int)
    case partiallyFailed(completedAt: Date, succeeded: Int, failed: Int)
    case failed(completedAt: Date, messageKey: String)
}

public enum RefreshTrigger: String, Sendable, Equatable {
    case manual
    case menuOpen
    case interval
}

public struct RefreshRequest: Sendable, Equatable {
    public var scope: RefreshScope
    public var trigger: RefreshTrigger

    public init(scope: RefreshScope = .all, trigger: RefreshTrigger) {
        self.scope = scope
        self.trigger = trigger
    }
}

public enum RefreshAdmission: Sendable, Equatable {
    case started
    case ignoredSameScope
    case skippedNoAccounts
}

public enum RefreshAdmissionPolicy: Sendable {
    public static func decide(
        request: RefreshRequest,
        current: RefreshState,
        accountCount: Int
    ) -> RefreshAdmission {
        if accountCount == 0 {
            return .skippedNoAccounts
        }
        if case .running(let scope, _) = current, scope == request.scope {
            return .ignoredSameScope
        }
        return .started
    }
}

public enum RefreshCancelReason: String, Sendable, Equatable {
    case user
    case windowClosed
    case background
    case sleepWake
    case superseded

    public var keepsLastSnapshot: Bool { true }

    public var showsCancelledMessage: Bool {
        switch self {
        case .user, .windowClosed, .background, .sleepWake:
            return true
        case .superseded:
            return false
        }
    }
}

public enum RefreshMessageKey: Sendable {
    public static let cancelledKeptLast = "refresh.cancelled_kept_last"
    public static let failed = "refresh.failed"
    public static let partialFailed = "refresh.partial_failed"
    public static let running = "refresh.running"
    public static let usageSaveFailed = "usage.save_failed"
    public static let cancelAction = "refresh.cancel"
    public static let refreshAction = "refresh.action"
    public static let lastPrefix = "refresh.last_prefix"
}

public enum RefreshPresentation: Sendable {
    public static let lastRefreshPrefixKey = RefreshMessageKey.lastPrefix

    public static func isBusy(_ state: RefreshState) -> Bool {
        switch state {
        case .running, .cancelling:
            return true
        case .idle, .succeeded, .partiallyFailed, .failed:
            return false
        }
    }

    public static func canStartNewRequest(_ state: RefreshState) -> Bool {
        if case .running = state { return false }
        return true
    }

    public static func refreshButtonCancels(_ state: RefreshState) -> Bool {
        if case .running = state { return true }
        return false
    }

    public static func statusMessageKey(_ state: RefreshState) -> String? {
        switch state {
        case .idle, .succeeded:
            return nil
        case .running:
            return RefreshMessageKey.running
        case .cancelling:
            return RefreshMessageKey.cancelledKeptLast
        case .partiallyFailed:
            return RefreshMessageKey.partialFailed
        case .failed(_, let messageKey):
            return messageKey
        }
    }

    public static func refreshButtonHelpKey(_ state: RefreshState) -> String {
        refreshButtonCancels(state) ? RefreshMessageKey.cancelAction : RefreshMessageKey.refreshAction
    }
}

public enum RefreshLoadingOwner: Sendable, Equatable {
    case none
    case refresh
    case usageBaselineReset
}

public enum RefreshLoadingPolicy: Sendable {
    public static func shouldApplyRefreshTerminalToLoading(owner: RefreshLoadingOwner) -> Bool {
        owner == .refresh
    }
}

public enum RefreshCancelPresentation: Sendable {
    public static func messageKey(
        reason: RefreshCancelReason,
        didAcceptSnapshots: Bool
    ) -> String? {
        if didAcceptSnapshots { return nil }
        return reason.showsCancelledMessage ? RefreshMessageKey.cancelledKeptLast : nil
    }
}

public enum RefreshLifecycleEvent: Sendable, Equatable {
    case userCancel
    case windowClosed
    case applicationDidResignActive
    case themeIdentityRebuild
    case willSleep
}

public enum RefreshLifecyclePolicy: Sendable {
    public static func cancelReason(for event: RefreshLifecycleEvent) -> RefreshCancelReason? {
        switch event {
        case .userCancel:
            return .user
        case .windowClosed:
            return .windowClosed
        case .willSleep:
            return .sleepWake
        case .applicationDidResignActive, .themeIdentityRebuild:
            return nil
        }
    }
}

public enum RefreshSnapshotClassification: Sendable {
    public static func isFailure(_ snapshot: BalanceSnapshot) -> Bool {
        snapshot.errorMessage != nil || snapshot.status == .error || snapshot.status == .setup
    }
}
