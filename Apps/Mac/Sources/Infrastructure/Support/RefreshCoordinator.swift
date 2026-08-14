import Foundation
import Domain

public protocol RefreshBalanceFetching: Sendable {
    func fetchBalances(
        accounts: [BalanceAccount],
        settings: AppSettings
    ) async -> RefreshFetchPayload
}

public protocol RefreshUsageRecording: Sendable {
    func recordUsage(
        snapshots: [BalanceSnapshot],
        knownAccountIDs: Set<UUID>,
        now: Date
    ) async -> UsageHistoryPersistResult
}

public struct BalanceServiceRefreshFetcher: RefreshBalanceFetching {
    private let service: BalanceService

    public init(service: BalanceService) {
        self.service = service
    }

    public func fetchBalances(
        accounts: [BalanceAccount],
        settings: AppSettings
    ) async -> RefreshFetchPayload {
        var scoped = settings
        let ids = Set(accounts.map(\.id))
        scoped.accounts = settings.accounts.map { account in
            var copy = account
            copy.enabled = account.enabled && ids.contains(account.id)
            return copy
        }
        let result = await service.refreshAll(settings: scoped)
        return RefreshFetchPayload(
            snapshots: result.snapshots,
            alerts: result.alerts,
            lastAlertAtByAccount: result.settings.lastAlertAtByAccount,
            peakConcurrency: result.peakConcurrency
        )
    }
}

public struct UsageHistoryRefreshRecorder: RefreshUsageRecording {
    private let store: UsageHistoryStore

    public init(store: UsageHistoryStore) {
        self.store = store
    }

    public func recordUsage(
        snapshots: [BalanceSnapshot],
        knownAccountIDs: Set<UUID>,
        now: Date
    ) async -> UsageHistoryPersistResult {
        await store.persistRecord(
            snapshots: snapshots,
            knownAccountIDs: knownAccountIDs,
            now: now
        )
    }
}

public struct NoOpRefreshUsageRecorder: RefreshUsageRecording {
    public init() {}

    public func recordUsage(
        snapshots: [BalanceSnapshot],
        knownAccountIDs: Set<UUID>,
        now: Date
    ) async -> UsageHistoryPersistResult {
        .saved(UsageHistoryDocument())
    }
}

@MainActor
public final class RefreshCoordinator {
    public private(set) var state: RefreshState = .idle
    public private(set) var generation: UInt64 = 0
    public private(set) var acceptedSnapshots: [BalanceSnapshot] = []
    public private(set) var lastAcceptedOutcome: RefreshOutcome?
    public private(set) var acceptedWriteCount = 0
    public let metrics: PerformanceSample
    public let maxConcurrentAccounts: Int

    public var onSnapshotsAccepted: ((RefreshOutcome) -> Void)?
    public var onTerminal: ((RefreshOutcome?) -> Void)?

    private let clock: any RefreshClock
    private let fetcher: any RefreshBalanceFetching
    private let usageRecorder: any RefreshUsageRecording
    private var activeTask: Task<RefreshOutcome?, Never>?
    private var activeRequest: RefreshRequest?
    private var hasAcceptedCurrentGeneration = false

    public init(
        clock: any RefreshClock = SystemRefreshClock(),
        fetcher: any RefreshBalanceFetching,
        usageRecorder: any RefreshUsageRecording = NoOpRefreshUsageRecorder(),
        metrics: PerformanceSample = PerformanceSample(),
        maxConcurrentAccounts: Int = RefreshFetchLimits.maxConcurrentAccounts
    ) {
        self.clock = clock
        self.fetcher = fetcher
        self.usageRecorder = usageRecorder
        self.metrics = metrics
        self.maxConcurrentAccounts = max(1, maxConcurrentAccounts)
    }

    public func seedAcceptedSnapshots(_ snapshots: [BalanceSnapshot]) {
        acceptedSnapshots = snapshots
    }

    @discardableResult
    public func request(
        _ request: RefreshRequest,
        settings: AppSettings,
        currentSnapshots: [BalanceSnapshot] = [],
        visibleAccountIDs: Set<UUID>? = nil
    ) -> RefreshAdmission {
        let accounts = request.scope.accounts(from: settings, visibleIDs: visibleAccountIDs)
        let decision = RefreshAdmissionPolicy.decide(
            request: request,
            current: state,
            accountCount: accounts.count
        )
        switch decision {
        case .ignoredSameScope, .skippedNoAccounts:
            return decision
        case .started:
            break
        }

        if case .running = state {
            activeTask?.cancel()
        }

        if !currentSnapshots.isEmpty, acceptedSnapshots.isEmpty {
            acceptedSnapshots = currentSnapshots
        }

        generation &+= 1
        let gen = generation
        hasAcceptedCurrentGeneration = false
        activeRequest = request
        let startedAt = clock.now
        state = .running(scope: request.scope, startedAt: startedAt)
        let knownIDs = Set(settings.accounts.map(\.id))

        activeTask = Task { [weak self] in
            guard let self else { return nil }
            let payload = await self.fetcher.fetchBalances(accounts: accounts, settings: settings)
            guard !Task.isCancelled, gen == self.generation else {
                return nil
            }

            var outcome = RefreshOutcome.make(
                generation: gen,
                scope: request.scope,
                trigger: request.trigger,
                payload: payload,
                now: self.clock.now
            )
            self.acceptedSnapshots = payload.snapshots
            self.lastAcceptedOutcome = outcome
            self.hasAcceptedCurrentGeneration = true
            self.acceptedWriteCount += 1
            self.recordMetrics(for: outcome, startedAt: startedAt, peakConcurrency: payload.peakConcurrency)
            self.onSnapshotsAccepted?(outcome)

            let persist = await self.usageRecorder.recordUsage(
                snapshots: payload.snapshots,
                knownAccountIDs: knownIDs,
                now: self.clock.now
            )
            guard !Task.isCancelled, gen == self.generation else {
                return outcome
            }

            switch persist {
            case .saved(let document):
                outcome.usageDocument = document
                outcome.usageWarning = nil
            case .failed(.cancelled):
                break
            case .failed(.load):
                outcome.usageWarning = .loadFailed
            case .failed(.save):
                outcome.usageWarning = .saveFailed
            }

            guard gen == self.generation else { return outcome }
            self.lastAcceptedOutcome = outcome
            self.state = outcome.state
            self.activeTask = nil
            self.activeRequest = nil
            self.onTerminal?(outcome)
            return outcome
        }

        return .started
    }

    public func cancel(reason: RefreshCancelReason) {
        guard case .running(let scope, let startedAt) = state else { return }
        let trigger = activeRequest?.trigger ?? .manual
        let didAccept = hasAcceptedCurrentGeneration
        let accepted = lastAcceptedOutcome
        state = .cancelling
        generation &+= 1
        let cancelledGen = generation
        activeTask?.cancel()
        let kept = acceptedSnapshots
        let previousTask = activeTask

        activeTask = Task { [weak self] in
            _ = await previousTask?.value
            guard let self, self.generation == cancelledGen else { return nil }
            if RefreshCancelPresentation.messageKey(
                reason: reason,
                didAcceptSnapshots: didAccept
            ) != nil {
                let outcome = RefreshOutcome.cancelled(
                    generation: cancelledGen,
                    scope: scope,
                    trigger: trigger,
                    snapshots: kept,
                    now: self.clock.now
                )
                self.recordCancel(startedAt: startedAt)
                self.state = outcome.state
                self.activeTask = nil
                self.activeRequest = nil
                self.onTerminal?(outcome)
                return outcome
            }
            if didAccept, let accepted {
                self.state = accepted.state
                self.activeTask = nil
                self.activeRequest = nil
                self.onTerminal?(accepted)
                return accepted
            }
            self.state = .idle
            self.activeTask = nil
            self.activeRequest = nil
            self.onTerminal?(nil)
            return nil
        }
    }

    public func waitForCompletion() async -> RefreshOutcome? {
        await activeTask?.value
    }

    private func recordMetrics(for outcome: RefreshOutcome, startedAt: Date, peakConcurrency: Int) {
        let duration = max(0, clock.now.timeIntervalSince(startedAt))
        let result: PerformanceSampleResult
        switch outcome.state {
        case .failed:
            result = .failure
        case .idle, .running, .cancelling, .succeeded, .partiallyFailed:
            result = .success
        }
        metrics.record(
            duration: duration,
            result: result,
            accountSuccesses: outcome.succeededCount,
            accountFailures: outcome.failedCount
        )
        metrics.recordConcurrency(peakConcurrency)
    }

    private func recordCancel(startedAt: Date) {
        metrics.record(
            duration: max(0, clock.now.timeIntervalSince(startedAt)),
            result: .cancel
        )
    }
}
