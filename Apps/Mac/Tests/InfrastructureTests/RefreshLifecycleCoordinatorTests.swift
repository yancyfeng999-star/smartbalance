import XCTest
@testable import Domain
@testable import Infrastructure

@MainActor
final class RefreshLifecycleCoordinatorTests: XCTestCase {
    private var clock: ControllableRefreshClock!
    private var scheduler: ControllableRefreshScheduler!
    private var lifecycle: RefreshLifecycleCoordinator!
    private var scheduled: [RefreshTrigger] = []
    private var cancels: [RefreshCancelReason] = []

    override func setUp() async throws {
        let clock = ControllableRefreshClock(Date(timeIntervalSince1970: 1_787_000_000))
        let scheduler = ControllableRefreshScheduler(clock: clock)
        let lifecycle = RefreshLifecycleCoordinator(
            clock: clock,
            scheduler: scheduler,
            allowsRefresh: true,
            intervalSecs: 900
        )
        self.clock = clock
        self.scheduler = scheduler
        self.lifecycle = lifecycle
        scheduled = []
        cancels = []
        lifecycle.onScheduleRefresh = { [weak self] trigger in
            self?.scheduled.append(trigger)
        }
        lifecycle.onCancelInFlight = { [weak self] reason in
            self?.cancels.append(reason)
        }
    }

    func testRepeatedWakeAppearAndIntervalScheduleASingleRefresh() {
        lifecycle.start()
        lifecycle.handle(.didWake)
        lifecycle.handle(.menuAppear)
        lifecycle.handle(.intervalTick)
        scheduler.advance(by: RefreshLifecycleCoordinator.wakeDebounceInterval)

        XCTAssertEqual(scheduled.count, 1, "wake/appear/interval must coalesce to one refresh")
        XCTAssertEqual(lifecycle.scheduledRefreshCount, 1)
        XCTAssertLessThanOrEqual(lifecycle.intervalTimerCount, 1)
    }

    func testMenuPinPageAndNotificationDoNotCreateIndependentTimers() {
        lifecycle.start()
        XCTAssertEqual(lifecycle.intervalTimerCount, 1)

        lifecycle.handle(.menuAppear)
        lifecycle.handle(.windowPinned)
        lifecycle.handle(.pageSwitch)
        lifecycle.handle(.notificationStateChange)

        XCTAssertEqual(lifecycle.intervalTimerCount, 1)
        XCTAssertFalse(RefreshLifecyclePolicy.createsIndependentRefreshTimer(for: .menuAppear))
        XCTAssertFalse(RefreshLifecyclePolicy.createsIndependentRefreshTimer(for: .windowPinned))
        XCTAssertFalse(RefreshLifecyclePolicy.createsIndependentRefreshTimer(for: .pageSwitch))
        XCTAssertFalse(RefreshLifecyclePolicy.createsIndependentRefreshTimer(for: .notificationStateChange))
        XCTAssertEqual(
            scheduler.pendingIDs.filter { $0.hasPrefix("timer-") }.count,
            1,
            "UI events must not add extra named refresh timers"
        )
    }

    func testSleepCancelsInFlightAndWakeReschedulesOnce() {
        lifecycle.start()
        scheduler.advance(by: RefreshLifecycleCoordinator.initialRefreshDelay)
        XCTAssertEqual(scheduled.count, 1)

        lifecycle.handle(.willSleep)
        XCTAssertEqual(cancels, [.sleepWake])
        XCTAssertTrue(lifecycle.isSleeping)
        XCTAssertEqual(lifecycle.intervalTimerCount, 0)

        lifecycle.handle(.didWake)
        lifecycle.handle(.didWake)
        lifecycle.handle(.menuAppear)
        scheduler.advance(by: RefreshLifecycleCoordinator.wakeDebounceInterval)

        XCTAssertFalse(lifecycle.isSleeping)
        XCTAssertEqual(scheduled.count, 2, "wake burst must schedule one additional refresh")
        XCTAssertLessThanOrEqual(lifecycle.intervalTimerCount, 1)
    }

    func testSafeModeDoesNotScheduleRefresh() {
        lifecycle.updatePolicy(allowsRefresh: false, intervalSecs: 900)
        lifecycle.start()
        lifecycle.handle(.didWake)
        lifecycle.handle(.intervalTick)
        lifecycle.handle(.menuAppear)
        scheduler.advance(by: 30)

        XCTAssertEqual(scheduled.count, 0)
        XCTAssertEqual(lifecycle.scheduledRefreshCount, 0)
        XCTAssertEqual(lifecycle.intervalTimerCount, 0)
    }

    func testIntervalZeroFiresOnceAndDoesNotLoop() {
        lifecycle.updatePolicy(allowsRefresh: true, intervalSecs: 0)
        lifecycle.start()
        scheduler.advance(by: RefreshLifecycleCoordinator.initialRefreshDelay)
        XCTAssertEqual(scheduled.count, 1)
        scheduler.advance(by: 1_800)
        XCTAssertEqual(scheduled.count, 1)
        XCTAssertEqual(lifecycle.intervalTimerCount, 0)
    }

    func testTwentyAccountsThirtyMinutesStayWithinThresholds() async {
        let accounts = (0..<RefreshFetchLimits.largeAccountBenchmarkCount).map { index in
            BalanceAccount(
                id: UUID(uuidString: String(format: "aaaaaaaa-aaaa-4aaa-8aaa-%012d", index))!,
                kind: index.isMultiple(of: 2) ? .deepseek : .openrouter,
                displayName: "Fake \(index)"
            )
        }
        let settings = AppSettings(accounts: accounts, refreshIntervalSecs: 900)
        let metrics = PerformanceSample()
        let fetcher = CappedCountingRefreshFetcher()
        let coordinator = RefreshCoordinator(
            clock: clock,
            fetcher: fetcher,
            usageRecorder: NoOpRefreshUsageRecorder(),
            metrics: metrics,
            maxConcurrentAccounts: RefreshFetchLimits.maxConcurrentAccounts
        )

        lifecycle = RefreshLifecycleCoordinator(
            clock: clock,
            scheduler: scheduler,
            allowsRefresh: true,
            intervalSecs: settings.refreshIntervalSecs
        )
        scheduled = []
        lifecycle.onScheduleRefresh = { trigger in
            self.scheduled.append(trigger)
            _ = coordinator.request(
                RefreshRequest(scope: .all, trigger: trigger),
                settings: settings
            )
        }

        lifecycle.start()
        scheduler.advance(by: RefreshLifecycleCoordinator.initialRefreshDelay)
        _ = await coordinator.waitForCompletion()
        scheduler.advance(by: TimeInterval(settings.refreshIntervalSecs))
        _ = await coordinator.waitForCompletion()
        scheduler.advance(by: TimeInterval(settings.refreshIntervalSecs))
        _ = await coordinator.waitForCompletion()

        XCTAssertGreaterThanOrEqual(scheduled.count, RefreshFetchLimits.thirtyMinuteMinRefreshes)
        XCTAssertLessThanOrEqual(scheduled.count, RefreshFetchLimits.thirtyMinuteMaxRefreshes)
        let peak = await fetcher.peakConcurrency
        XCTAssertLessThanOrEqual(peak, RefreshFetchLimits.maxConcurrentAccounts)
        XCTAssertEqual(
            metrics.snapshot().peakConcurrency,
            peak,
            "coordinator must record measured in-flight peak, not min(cap, accountCount)"
        )
        XCTAssertEqual(coordinator.acceptedSnapshots.count, accounts.count)
        let retainedBytes = RefreshMemoryBudget.estimateRetainedBytes(
            snapshotCount: coordinator.acceptedSnapshots.count
        )
        XCTAssertLessThanOrEqual(
            retainedBytes,
            RefreshMemoryBudget.maxThirtyMinuteRetainedBytes,
            "20 accounts × 3 interval passes must not grow retained snapshot memory"
        )
        XCTAssertLessThanOrEqual(
            coordinator.acceptedSnapshots.count,
            accounts.count * RefreshMemoryBudget.maxRetainedSnapshotsPerAccount
        )
        XCTAssertLessThan(
            coordinator.acceptedSnapshots.count,
            accounts.count * max(2, scheduled.count),
            "memory proxy: live snapshots must not accumulate per refresh pass"
        )
        XCTAssertLessThanOrEqual(metrics.snapshot().sampleCount, RefreshFetchLimits.maxMetricsSamples)
        XCTAssertEqual(metrics.snapshot().successCount, scheduled.count)
        XCTAssertTrue(metrics.debugFieldNames().allSatisfy { name in
            let lowered = name.lowercased()
            return !lowered.contains("url")
                && !lowered.contains("body")
                && !lowered.contains("keychain")
                && !lowered.contains("credential")
                && !lowered.contains("secret")
        })
    }

    func testLimiterCancelDoesNotWaitForQueuedPermits() async {
        let limiter = RefreshConcurrencyLimiter(limit: 4)
        let bodies = BodyCounter()
        let parent = Task {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<20 {
                    group.addTask {
                        _ = try? await limiter.withPermit {
                            await bodies.increment()
                            try? await Task.sleep(nanoseconds: 5_000_000_000)
                            return 0
                        }
                    }
                }
                await group.waitForAll()
            }
        }
        await waitUntil { await bodies.value == 4 }
        let started = Date()
        parent.cancel()
        _ = await parent.result
        let elapsed = Date().timeIntervalSince(started)
        let bodyCount = await bodies.value
        let queued = await limiter.queuedWaiterCount
        XCTAssertLessThan(elapsed, 0.25, "queued acquire waiters must cancel without draining the permit queue")
        XCTAssertEqual(bodyCount, 4, "cancelled waiters must not run the fetch body")
        XCTAssertEqual(queued, 0)
    }

    func testCancelDoesNotApplyStaleWriteFromFinishedTask() async {
        let gate = LifecycleAsyncGate()
        let accountID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let settings = AppSettings(accounts: [
            BalanceAccount(id: accountID, kind: .deepseek, displayName: "A"),
        ])
        var writes = 0
        let fetcher = GatedLifecycleFetcher(
            gate: gate,
            snapshot: BalanceSnapshot(
                accountId: accountID,
                providerKind: .deepseek,
                displayName: "A",
                amount: 99,
                unit: "¥",
                status: .healthy
            )
        )
        let coordinator = RefreshCoordinator(
            clock: clock,
            fetcher: fetcher,
            metrics: PerformanceSample()
        )
        coordinator.seedAcceptedSnapshots([
            BalanceSnapshot(
                accountId: accountID,
                providerKind: .deepseek,
                displayName: "A",
                amount: 11,
                unit: "¥",
                status: .healthy
            ),
        ])
        coordinator.onSnapshotsAccepted = { _ in writes += 1 }

        XCTAssertEqual(
            coordinator.request(.init(trigger: .interval), settings: settings),
            .started
        )
        await waitUntil { await fetcher.started }
        coordinator.cancel(reason: .sleepWake)
        await gate.release()
        _ = await coordinator.waitForCompletion()

        XCTAssertEqual(writes, 0)
        XCTAssertEqual(coordinator.acceptedSnapshots.first?.amount, 11)
        XCTAssertEqual(coordinator.metrics.snapshot().cancelCount, 1)
        XCTAssertEqual(coordinator.metrics.snapshot().successCount, 0)
    }

    private func waitUntil(timeout: TimeInterval = 1, _ predicate: @escaping () async -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await predicate() { return }
            await Task.yield()
        }
        XCTFail("timed out waiting for condition")
    }
}

// MARK: - Test doubles

private actor LifecycleAsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var opened = false

    func wait() async {
        if opened { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        opened = true
        continuation?.resume()
        continuation = nil
    }
}

private final class GatedLifecycleFetcher: RefreshBalanceFetching, @unchecked Sendable {
    private let gate: LifecycleAsyncGate
    private let snapshot: BalanceSnapshot
    private let startedFlag = StartedFlag()

    init(gate: LifecycleAsyncGate, snapshot: BalanceSnapshot) {
        self.gate = gate
        self.snapshot = snapshot
    }

    var started: Bool {
        get async { await startedFlag.value }
    }

    func fetchBalances(
        accounts: [BalanceAccount],
        settings: AppSettings
    ) async -> RefreshFetchPayload {
        await startedFlag.mark()
        await gate.wait()
        return RefreshFetchPayload(snapshots: [snapshot])
    }
}

private actor StartedFlag {
    private(set) var value = false

    func mark() {
        value = true
    }
}

private final class CappedCountingRefreshFetcher: RefreshBalanceFetching, @unchecked Sendable {
    private let limiter = RefreshConcurrencyLimiter(limit: RefreshFetchLimits.maxConcurrentAccounts)
    private let stats = ConcurrencyStats()

    var peakConcurrency: Int {
        get async { await stats.peak }
    }

    func fetchBalances(
        accounts: [BalanceAccount],
        settings: AppSettings
    ) async -> RefreshFetchPayload {
        var snapshots: [BalanceSnapshot] = []
        await withTaskGroup(of: BalanceSnapshot.self) { group in
            for account in accounts {
                group.addTask {
                    do {
                        return try await self.limiter.withPermit {
                            await self.stats.enter()
                            await Task.yield()
                            await self.stats.leave()
                            return BalanceSnapshot(
                                accountId: account.id,
                                providerKind: account.kind,
                                displayName: account.title,
                                amount: 1,
                                unit: "¥",
                                status: .healthy
                            )
                        }
                    } catch {
                        return BalanceSnapshot(
                            accountId: account.id,
                            providerKind: account.kind,
                            displayName: account.title,
                            source: .api,
                            status: .unknown
                        )
                    }
                }
            }
            for await snap in group {
                snapshots.append(snap)
            }
        }
        return RefreshFetchPayload(snapshots: snapshots, peakConcurrency: await stats.peak)
    }
}

private actor BodyCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private actor ConcurrencyStats {
    private var inFlight = 0
    private(set) var peak = 0

    func enter() {
        inFlight += 1
        peak = max(peak, inFlight)
    }

    func leave() {
        inFlight = max(0, inFlight - 1)
    }
}
