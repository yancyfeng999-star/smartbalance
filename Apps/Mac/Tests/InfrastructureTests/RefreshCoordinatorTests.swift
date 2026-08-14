import XCTest
@testable import Domain
@testable import Infrastructure

@MainActor
final class RefreshCoordinatorTests: XCTestCase {
    private let accountA = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
    private let accountB = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
    private let clockStart = Date(timeIntervalSince1970: 1_787_000_000)

    func testDuplicateAllScopeCallsProviderOnce() async {
        let gate = AsyncGate()
        let http = MockHTTPClient(statusCode: 200, json: Self.deepSeekJSON)
        let delayed = GatedHTTPClient(inner: http, gate: gate)
        let provider = DeepSeekBalanceProvider(http: delayed)
        let fetcher = ProviderBackedRefreshFetcher(providers: [accountA: provider])
        let coordinator = makeCoordinator(fetcher: fetcher)

        let first = coordinator.request(.init(trigger: .manual), settings: settings([accountA]))
        XCTAssertEqual(first, .started)
        await waitUntil { delayed.entered }
        let second = coordinator.request(.init(trigger: .manual), settings: settings([accountA]))
        XCTAssertEqual(second, .ignoredSameScope)
        await gate.release()
        _ = await coordinator.waitForCompletion()

        XCTAssertEqual(http.callCount, 1)
        XCTAssertEqual(delayed.enterCount, 1)
        if case .succeeded(_, let count) = coordinator.state {
            XCTAssertEqual(count, 1)
        } else {
            XCTFail("expected succeeded, got \(coordinator.state)")
        }
    }

    func testCancelDiscardsLateProviderResultAndKeepsLastSnapshot() async {
        let gate = AsyncGate()
        let provider = ControllableFakeProvider(
            kind: .openrouter,
            gate: gate,
            snapshot: snapshot(id: accountA, amount: 99, status: .healthy)
        )
        let coordinator = makeCoordinator(
            fetcher: ProviderBackedRefreshFetcher(providers: [accountA: provider])
        )
        let kept = snapshot(id: accountA, amount: 15, status: .healthy)
        coordinator.seedAcceptedSnapshots([kept])

        XCTAssertEqual(
            coordinator.request(.init(trigger: .manual), settings: settings([accountA])),
            .started
        )
        await waitUntil { provider.callCount == 1 }
        coordinator.cancel(reason: .user)
        await gate.release()
        _ = await coordinator.waitForCompletion()

        XCTAssertEqual(coordinator.acceptedSnapshots, [kept])
        XCTAssertEqual(coordinator.acceptedSnapshots.first?.amount, 15)
        XCTAssertNotEqual(coordinator.acceptedSnapshots.first?.amount, 99)
        XCTAssertEqual(
            RefreshPresentation.statusMessageKey(coordinator.state),
            RefreshMessageKey.cancelledKeptLast
        )
    }

    func testOldGenerationResultIsDiscarded() async {
        let firstGate = AsyncGate()
        let secondGate = AsyncGate()
        let staleProvider = ControllableFakeProvider(
            kind: .deepseek,
            gate: firstGate,
            snapshot: snapshot(id: accountA, amount: 1, status: .healthy)
        )
        let freshProvider = ControllableFakeProvider(
            kind: .openrouter,
            gate: secondGate,
            snapshot: snapshot(id: accountB, amount: 42, status: .healthy)
        )
        let fetcher = SwitchingRefreshFetcher(
            first: ProviderBackedRefreshFetcher(providers: [accountA: staleProvider]),
            second: ProviderBackedRefreshFetcher(providers: [accountB: freshProvider])
        )
        let coordinator = makeCoordinator(fetcher: fetcher)
        coordinator.seedAcceptedSnapshots([snapshot(id: accountA, amount: 7, status: .healthy)])

        XCTAssertEqual(
            coordinator.request(.init(scope: .all, trigger: .manual), settings: settings([accountA])),
            .started
        )
        await waitUntil { staleProvider.callCount == 1 }

        XCTAssertEqual(
            coordinator.request(
                .init(scope: .account(accountB), trigger: .manual),
                settings: settings([accountA, accountB])
            ),
            .started
        )
        await waitUntil { freshProvider.callCount == 1 }

        await firstGate.release()
        await secondGate.release()
        _ = await coordinator.waitForCompletion()

        XCTAssertEqual(coordinator.acceptedSnapshots.count, 1)
        XCTAssertEqual(coordinator.acceptedSnapshots.first?.accountId, accountB)
        XCTAssertEqual(coordinator.acceptedSnapshots.first?.amount, 42)
        XCTAssertFalse(coordinator.acceptedSnapshots.contains(where: { $0.amount == 1 }))
        XCTAssertEqual(staleProvider.callCount, 1)
        XCTAssertEqual(freshProvider.callCount, 1)
    }

    func testPartialChannelFailureProducesPartialOutcome() async {
        let ok = ControllableFakeProvider(
            kind: .deepseek,
            snapshot: snapshot(id: accountA, amount: 30, status: .healthy)
        )
        let bad = ControllableFakeProvider(
            kind: .kimi,
            snapshot: snapshot(id: accountB, status: .error, error: "boom")
        )
        let coordinator = makeCoordinator(
            fetcher: ProviderBackedRefreshFetcher(providers: [
                accountA: ok,
                accountB: bad,
            ])
        )

        XCTAssertEqual(
            coordinator.request(.init(trigger: .manual), settings: settings([accountA, accountB])),
            .started
        )
        let outcome = await coordinator.waitForCompletion()

        XCTAssertEqual(
            outcome?.state,
            .partiallyFailed(completedAt: clockStart, succeeded: 1, failed: 1)
        )
        XCTAssertEqual(coordinator.acceptedSnapshots.count, 2)
        XCTAssertEqual(coordinator.acceptedSnapshots.first(where: { $0.accountId == accountA })?.amount, 30)
    }

    func testUsageHistorySaveFailureDoesNotFailBalanceResult() async {
        let provider = ControllableFakeProvider(
            kind: .deepseek,
            snapshot: snapshot(id: accountA, amount: 50, status: .healthy)
        )
        let usage = FakeUsageRecorder(result: .failed(.save))
        let coordinator = makeCoordinator(
            fetcher: ProviderBackedRefreshFetcher(providers: [accountA: provider]),
            usage: usage
        )

        XCTAssertEqual(
            coordinator.request(.init(trigger: .manual), settings: settings([accountA])),
            .started
        )
        let outcome = await coordinator.waitForCompletion()

        XCTAssertEqual(outcome?.state, .succeeded(completedAt: clockStart, refreshedCount: 1))
        XCTAssertEqual(outcome?.usageWarning, .saveFailed)
        XCTAssertEqual(coordinator.acceptedSnapshots.first?.amount, 50)
        XCTAssertEqual(usage.calls, 1)
    }

    func testUsageStorePersistFailureIsIndependentWarning() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-RefreshUsage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = UsageHistoryStore(
            filename: "usage-history.json",
            directory: directory,
            writer: { _, _ in throw POSIXError(.EIO) }
        )
        let provider = ControllableFakeProvider(
            kind: .deepseek,
            snapshot: snapshot(id: accountA, amount: 12, status: .healthy)
        )
        let coordinator = makeCoordinator(
            fetcher: ProviderBackedRefreshFetcher(providers: [accountA: provider]),
            usage: UsageHistoryRefreshRecorder(store: store)
        )

        XCTAssertEqual(
            coordinator.request(.init(trigger: .manual), settings: settings([accountA])),
            .started
        )
        let outcome = await coordinator.waitForCompletion()

        XCTAssertEqual(outcome?.state, .succeeded(completedAt: clockStart, refreshedCount: 1))
        XCTAssertEqual(outcome?.usageWarning, .saveFailed)
        XCTAssertEqual(coordinator.acceptedSnapshots.first?.amount, 12)
    }

    func testManualAndIntervalAtTheSameTimeKeepOneTask() async {
        let gate = AsyncGate()
        let provider = ControllableFakeProvider(
            kind: .deepseek,
            gate: gate,
            snapshot: snapshot(id: accountA, amount: 8, status: .healthy)
        )
        let coordinator = makeCoordinator(
            fetcher: ProviderBackedRefreshFetcher(providers: [accountA: provider])
        )

        XCTAssertEqual(
            coordinator.request(.init(trigger: .manual), settings: settings([accountA])),
            .started
        )
        await waitUntil { provider.callCount == 1 }
        XCTAssertEqual(
            coordinator.request(.init(trigger: .interval), settings: settings([accountA])),
            .ignoredSameScope
        )
        await gate.release()
        _ = await coordinator.waitForCompletion()

        XCTAssertEqual(provider.callCount, 1)
    }

    func testFailureAllowsAnotherRefresh() async {
        let failing = ControllableFakeProvider(
            kind: .deepseek,
            snapshot: snapshot(id: accountA, status: .error, error: "down")
        )
        let fetcher = ProviderBackedRefreshFetcher(providers: [accountA: failing])
        let coordinator = makeCoordinator(fetcher: fetcher)

        XCTAssertEqual(
            coordinator.request(.init(trigger: .manual), settings: settings([accountA])),
            .started
        )
        _ = await coordinator.waitForCompletion()
        XCTAssertEqual(
            RefreshPresentation.statusMessageKey(coordinator.state),
            RefreshMessageKey.failed
        )

        XCTAssertEqual(
            coordinator.request(.init(trigger: .manual), settings: settings([accountA])),
            .started
        )
        _ = await coordinator.waitForCompletion()
        XCTAssertEqual(failing.callCount, 2)
    }

    func testNoAccountsDoesNotTouchProvidersOrHTTP() async {
        let http = MockHTTPClient(statusCode: 200, json: Self.deepSeekJSON)
        let provider = DeepSeekBalanceProvider(http: http)
        let fetcher = ProviderBackedRefreshFetcher(providers: [accountA: provider])
        let coordinator = makeCoordinator(fetcher: fetcher)

        XCTAssertEqual(
            coordinator.request(.init(trigger: .interval), settings: AppSettings(accounts: [])),
            .skippedNoAccounts
        )
        XCTAssertEqual(http.callCount, 0)
        XCTAssertEqual(fetcher.fetchCount, 0)
        XCTAssertEqual(coordinator.state, .idle)
    }

    private func makeCoordinator(
        fetcher: any RefreshBalanceFetching,
        usage: any RefreshUsageRecording = FakeUsageRecorder()
    ) -> RefreshCoordinator {
        RefreshCoordinator(
            clock: ControllableRefreshClock(clockStart),
            fetcher: fetcher,
            usageRecorder: usage
        )
    }

    private func settings(_ ids: [UUID]) -> AppSettings {
        AppSettings(
            accounts: ids.enumerated().map { index, id in
                BalanceAccount(
                    id: id,
                    kind: index == 0 ? .deepseek : .openrouter,
                    displayName: "A\(index)"
                )
            }
        )
    }

    private func snapshot(
        id: UUID,
        amount: Double? = nil,
        status: BalanceStatus,
        error: String? = nil
    ) -> BalanceSnapshot {
        BalanceSnapshot(
            accountId: id,
            providerKind: .deepseek,
            displayName: "Card",
            amount: amount,
            unit: amount == nil ? "" : "¥",
            status: status,
            errorMessage: error
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        _ predicate: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return }
            await Task.yield()
        }
        XCTFail("timed out waiting for condition")
    }

    private static let deepSeekJSON = """
    {"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"18.5","granted_balance":"0","topped_up_balance":"18.5"}]}
    """
}

// MARK: - Test doubles

private actor AsyncGate {
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

private final class GatedHTTPClient: HTTPClient, @unchecked Sendable {
    let inner: MockHTTPClient
    let gate: AsyncGate
    private let lock = NSLock()
    private var _enterCount = 0
    private var _entered = false

    init(inner: MockHTTPClient, gate: AsyncGate) {
        self.inner = inner
        self.gate = gate
    }

    var enterCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _enterCount
    }

    var entered: Bool {
        lock.lock(); defer { lock.unlock() }
        return _entered
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        markEntered()
        await gate.wait()
        return try await inner.data(for: request)
    }

    private func markEntered() {
        lock.lock()
        _enterCount += 1
        _entered = true
        lock.unlock()
    }
}

private final class ControllableFakeProvider: BalanceProvider, @unchecked Sendable {
    let kind: ProviderKind
    private let gate: AsyncGate?
    private let snapshot: BalanceSnapshot
    private let lock = NSLock()
    private var _callCount = 0

    init(kind: ProviderKind, gate: AsyncGate? = nil, snapshot: BalanceSnapshot) {
        self.kind = kind
        self.gate = gate
        self.snapshot = snapshot
    }

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _callCount
    }

    func fetchBalance(
        account: BalanceAccount,
        credentials: ProviderCredentials
    ) async throws -> BalanceSnapshot {
        increment()
        if let gate {
            await gate.wait()
        }
        var snap = snapshot
        snap.accountId = account.id
        snap.displayName = account.title
        snap.providerKind = kind
        return snap
    }

    private func increment() {
        lock.lock()
        _callCount += 1
        lock.unlock()
    }
}

private final class ProviderBackedRefreshFetcher: RefreshBalanceFetching, @unchecked Sendable {
    private let providers: [UUID: any BalanceProvider]
    private let lock = NSLock()
    private var _fetchCount = 0

    init(providers: [UUID: any BalanceProvider]) {
        self.providers = providers
    }

    var fetchCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _fetchCount
    }

    func fetchBalances(
        accounts: [BalanceAccount],
        settings: AppSettings
    ) async -> RefreshFetchPayload {
        increment()
        var snapshots: [BalanceSnapshot] = []
        for account in accounts {
            guard let provider = providers[account.id] else { continue }
            do {
                snapshots.append(
                    try await provider.fetchBalance(
                        account: account,
                        credentials: ProviderCredentials(apiKey: "sk-test")
                    )
                )
            } catch {
                snapshots.append(
                    BalanceSnapshot(
                        accountId: account.id,
                        providerKind: account.kind,
                        displayName: account.title,
                        source: .api,
                        status: .error,
                        errorMessage: error.localizedDescription
                    )
                )
            }
        }
        return RefreshFetchPayload(
            snapshots: snapshots,
            alerts: [],
            lastAlertAtByAccount: settings.lastAlertAtByAccount
        )
    }

    private func increment() {
        lock.lock()
        _fetchCount += 1
        lock.unlock()
    }
}

private final class SwitchingRefreshFetcher: RefreshBalanceFetching, @unchecked Sendable {
    private let first: ProviderBackedRefreshFetcher
    private let second: ProviderBackedRefreshFetcher
    private let lock = NSLock()
    private var usesSecond = false

    init(first: ProviderBackedRefreshFetcher, second: ProviderBackedRefreshFetcher) {
        self.first = first
        self.second = second
    }

    func fetchBalances(
        accounts: [BalanceAccount],
        settings: AppSettings
    ) async -> RefreshFetchPayload {
        let useSecond = takeBranch()
        if useSecond {
            return await second.fetchBalances(accounts: accounts, settings: settings)
        }
        return await first.fetchBalances(accounts: accounts, settings: settings)
    }

    private func takeBranch() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let useSecond = usesSecond
        usesSecond = true
        return useSecond
    }
}

private final class FakeUsageRecorder: RefreshUsageRecording, @unchecked Sendable {
    private let result: UsageHistoryPersistResult
    private let lock = NSLock()
    private var _calls = 0

    init(result: UsageHistoryPersistResult = .saved(UsageHistoryDocument())) {
        self.result = result
    }

    var calls: Int {
        lock.lock(); defer { lock.unlock() }
        return _calls
    }

    func recordUsage(
        snapshots: [BalanceSnapshot],
        knownAccountIDs: Set<UUID>,
        now: Date
    ) async -> UsageHistoryPersistResult {
        increment()
        return result
    }

    private func increment() {
        lock.lock()
        _calls += 1
        lock.unlock()
    }
}
