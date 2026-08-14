import Foundation

public enum RefreshUsageWarning: String, Sendable, Equatable {
    case saveFailed
    case loadFailed

    public var messageKey: String {
        switch self {
        case .saveFailed:
            return RefreshMessageKey.usageSaveFailed
        case .loadFailed:
            return "usage.load_failed"
        }
    }
}

public struct RefreshFetchPayload: Sendable, Equatable {
    public var snapshots: [BalanceSnapshot]
    public var alerts: [AlertEvent]
    public var lastAlertAtByAccount: [String: Date]
    public var peakConcurrency: Int

    public init(
        snapshots: [BalanceSnapshot],
        alerts: [AlertEvent] = [],
        lastAlertAtByAccount: [String: Date] = [:],
        peakConcurrency: Int = 0
    ) {
        self.snapshots = snapshots
        self.alerts = alerts
        self.lastAlertAtByAccount = lastAlertAtByAccount
        self.peakConcurrency = max(0, peakConcurrency)
    }
}

public struct RefreshOutcome: Sendable, Equatable {
    public var generation: UInt64
    public var scope: RefreshScope
    public var trigger: RefreshTrigger
    public var state: RefreshState
    public var snapshots: [BalanceSnapshot]
    public var alerts: [AlertEvent]
    public var lastAlertAtByAccount: [String: Date]
    public var usageWarning: RefreshUsageWarning?
    public var usageDocument: UsageHistoryDocument?
    public var discarded: Bool

    public init(
        generation: UInt64,
        scope: RefreshScope,
        trigger: RefreshTrigger,
        state: RefreshState,
        snapshots: [BalanceSnapshot],
        alerts: [AlertEvent] = [],
        lastAlertAtByAccount: [String: Date] = [:],
        usageWarning: RefreshUsageWarning? = nil,
        usageDocument: UsageHistoryDocument? = nil,
        discarded: Bool = false
    ) {
        self.generation = generation
        self.scope = scope
        self.trigger = trigger
        self.state = state
        self.snapshots = snapshots
        self.alerts = alerts
        self.lastAlertAtByAccount = lastAlertAtByAccount
        self.usageWarning = usageWarning
        self.usageDocument = usageDocument
        self.discarded = discarded
    }

    public var succeededCount: Int {
        snapshots.filter { !RefreshSnapshotClassification.isFailure($0) }.count
    }

    public var failedCount: Int {
        snapshots.filter { RefreshSnapshotClassification.isFailure($0) }.count
    }

    public static func make(
        generation: UInt64,
        scope: RefreshScope,
        trigger: RefreshTrigger,
        payload: RefreshFetchPayload,
        now: Date,
        usageWarning: RefreshUsageWarning? = nil,
        usageDocument: UsageHistoryDocument? = nil,
        discarded: Bool = false
    ) -> RefreshOutcome {
        let succeeded = payload.snapshots.filter { !RefreshSnapshotClassification.isFailure($0) }.count
        let failed = payload.snapshots.count - succeeded
        let state: RefreshState
        if payload.snapshots.isEmpty {
            state = .succeeded(completedAt: now, refreshedCount: 0)
        } else if failed == 0 {
            state = .succeeded(completedAt: now, refreshedCount: succeeded)
        } else if succeeded == 0 {
            state = .failed(completedAt: now, messageKey: RefreshMessageKey.failed)
        } else {
            state = .partiallyFailed(completedAt: now, succeeded: succeeded, failed: failed)
        }
        return RefreshOutcome(
            generation: generation,
            scope: scope,
            trigger: trigger,
            state: state,
            snapshots: payload.snapshots,
            alerts: payload.alerts,
            lastAlertAtByAccount: payload.lastAlertAtByAccount,
            usageWarning: usageWarning,
            usageDocument: usageDocument,
            discarded: discarded
        )
    }

    public static func cancelled(
        generation: UInt64,
        scope: RefreshScope,
        trigger: RefreshTrigger,
        snapshots: [BalanceSnapshot],
        now: Date
    ) -> RefreshOutcome {
        RefreshOutcome(
            generation: generation,
            scope: scope,
            trigger: trigger,
            state: .failed(completedAt: now, messageKey: RefreshMessageKey.cancelledKeptLast),
            snapshots: snapshots
        )
    }
}
