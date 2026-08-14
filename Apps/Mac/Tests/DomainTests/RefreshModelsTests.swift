import XCTest
@testable import Domain

final class RefreshModelsTests: XCTestCase {
    private let accountA = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
    private let accountB = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
    private let now = Date(timeIntervalSince1970: 1_787_000_000)

    func testRefreshScopeSelectsEnabledAccounts() {
        let disabled = BalanceAccount(
            id: UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!,
            kind: .kimi,
            displayName: "Off",
            enabled: false
        )
        let settings = AppSettings(accounts: [
            BalanceAccount(id: accountA, kind: .deepseek, displayName: "A"),
            BalanceAccount(id: accountB, kind: .openrouter, displayName: "B"),
            disabled,
        ])

        XCTAssertEqual(RefreshScope.all.accountIDs(from: settings), [accountA, accountB])
        XCTAssertEqual(RefreshScope.account(accountB).accountIDs(from: settings), [accountB])
        XCTAssertEqual(
            RefreshScope.visible.accountIDs(from: settings, visibleIDs: [accountA]),
            [accountA]
        )
        XCTAssertEqual(RefreshScope.visible.accountIDs(from: settings), [accountA, accountB])
    }

    func testAllSuccessSnapshotsClassifyAsSucceeded() {
        let outcome = RefreshOutcome.make(
            generation: 3,
            scope: .all,
            trigger: .manual,
            payload: RefreshFetchPayload(
                snapshots: [
                    snapshot(id: accountA, amount: 12, status: .healthy),
                    snapshot(id: accountB, amount: 4, status: .warning),
                ]
            ),
            now: now
        )

        XCTAssertEqual(outcome.state, .succeeded(completedAt: now, refreshedCount: 2))
        XCTAssertNil(outcome.usageWarning)
        XCTAssertFalse(outcome.discarded)
        XCTAssertEqual(outcome.succeededCount, 2)
        XCTAssertEqual(outcome.failedCount, 0)
    }

    func testMixedSnapshotsClassifyAsPartialFailure() {
        let outcome = RefreshOutcome.make(
            generation: 1,
            scope: .all,
            trigger: .interval,
            payload: RefreshFetchPayload(
                snapshots: [
                    snapshot(id: accountA, amount: 20, status: .healthy),
                    snapshot(id: accountB, status: .error, error: "timeout"),
                ]
            ),
            now: now
        )

        XCTAssertEqual(
            outcome.state,
            .partiallyFailed(completedAt: now, succeeded: 1, failed: 1)
        )
        XCTAssertEqual(outcome.succeededCount, 1)
        XCTAssertEqual(outcome.failedCount, 1)
    }

    func testAllFailedSnapshotsClassifyAsFailed() {
        let outcome = RefreshOutcome.make(
            generation: 2,
            scope: .all,
            trigger: .menuOpen,
            payload: RefreshFetchPayload(
                snapshots: [
                    snapshot(id: accountA, status: .setup, error: "未配置密钥"),
                    snapshot(id: accountB, status: .error, error: "HTTP 401"),
                ]
            ),
            now: now
        )

        XCTAssertEqual(
            outcome.state,
            .failed(completedAt: now, messageKey: RefreshMessageKey.failed)
        )
        XCTAssertEqual(outcome.failedCount, 2)
        XCTAssertEqual(outcome.succeededCount, 0)
    }

    func testUsageHistorySaveFailureDoesNotMarkBalanceResultFailed() {
        var outcome = RefreshOutcome.make(
            generation: 4,
            scope: .all,
            trigger: .manual,
            payload: RefreshFetchPayload(
                snapshots: [snapshot(id: accountA, amount: 88, status: .healthy)]
            ),
            now: now
        )
        outcome.usageWarning = .saveFailed

        XCTAssertEqual(outcome.state, .succeeded(completedAt: now, refreshedCount: 1))
        XCTAssertNotEqual(
            outcome.state,
            .failed(completedAt: now, messageKey: RefreshMessageKey.failed)
        )
        XCTAssertEqual(outcome.usageWarning?.messageKey, RefreshMessageKey.usageSaveFailed)
        XCTAssertEqual(outcome.snapshots.first?.amount, 88)
    }

    func testCancelledOutcomeKeepsSnapshotsAndUsesStableMessageKey() {
        let kept = snapshot(id: accountA, amount: 15, status: .healthy)
        let outcome = RefreshOutcome.cancelled(
            generation: 8,
            scope: .all,
            trigger: .manual,
            snapshots: [kept],
            now: now
        )

        XCTAssertEqual(
            outcome.state,
            .failed(completedAt: now, messageKey: RefreshMessageKey.cancelledKeptLast)
        )
        XCTAssertEqual(outcome.snapshots, [kept])
        XCTAssertEqual(outcome.snapshots.first?.amount, 15)
        XCTAssertEqual(
            RefreshPresentation.statusMessageKey(outcome.state),
            RefreshMessageKey.cancelledKeptLast
        )
    }

    func testBaselineResetOwnerIgnoresRefreshTerminalLoading() {
        XCTAssertTrue(
            RefreshLoadingPolicy.shouldApplyRefreshTerminalToLoading(owner: .refresh)
        )
        XCTAssertFalse(
            RefreshLoadingPolicy.shouldApplyRefreshTerminalToLoading(owner: .usageBaselineReset)
        )
        XCTAssertFalse(
            RefreshLoadingPolicy.shouldApplyRefreshTerminalToLoading(owner: .none)
        )
    }

    func testLifecycleUIEventsDoNotCreateTimersAndWakeDoesNotCancel() {
        XCTAssertNil(RefreshLifecyclePolicy.cancelReason(for: .didWake))
        XCTAssertNil(RefreshLifecyclePolicy.cancelReason(for: .menuAppear))
        XCTAssertNil(RefreshLifecyclePolicy.cancelReason(for: .windowPinned))
        XCTAssertNil(RefreshLifecyclePolicy.cancelReason(for: .pageSwitch))
        XCTAssertNil(RefreshLifecyclePolicy.cancelReason(for: .notificationStateChange))
        XCTAssertNil(RefreshLifecyclePolicy.cancelReason(for: .intervalTick))
        XCTAssertFalse(RefreshLifecyclePolicy.createsIndependentRefreshTimer(for: .menuAppear))
        XCTAssertFalse(RefreshLifecyclePolicy.createsIndependentRefreshTimer(for: .windowPinned))
        XCTAssertFalse(RefreshLifecyclePolicy.createsIndependentRefreshTimer(for: .pageSwitch))
        XCTAssertFalse(RefreshLifecyclePolicy.createsIndependentRefreshTimer(for: .notificationStateChange))
        XCTAssertTrue(RefreshLifecyclePolicy.shouldScheduleRefresh(for: .didWake))
        XCTAssertTrue(RefreshLifecyclePolicy.shouldScheduleRefresh(for: .intervalTick))
        XCTAssertFalse(RefreshLifecyclePolicy.shouldScheduleRefresh(for: .windowPinned))
        XCTAssertFalse(RefreshLifecyclePolicy.shouldScheduleRefresh(for: .pageSwitch))
        XCTAssertFalse(RefreshLifecyclePolicy.shouldScheduleRefresh(for: .notificationStateChange))
        XCTAssertEqual(RefreshFetchLimits.maxConcurrentAccounts, 4)
        XCTAssertEqual(RefreshFetchLimits.largeAccountBenchmarkCount, 20)
        XCTAssertEqual(RefreshFetchLimits.thirtyMinuteBenchmarkSeconds, 1_800)
    }

    func testCancelAfterAcceptedSnapshotsDoesNotUseKeptLastCopy() {
        XCTAssertEqual(
            RefreshCancelPresentation.messageKey(reason: .user, didAcceptSnapshots: false),
            RefreshMessageKey.cancelledKeptLast
        )
        XCTAssertNil(
            RefreshCancelPresentation.messageKey(reason: .user, didAcceptSnapshots: true)
        )
        XCTAssertNil(
            RefreshCancelPresentation.messageKey(reason: .windowClosed, didAcceptSnapshots: true)
        )
        XCTAssertNil(
            RefreshCancelPresentation.messageKey(reason: .superseded, didAcceptSnapshots: false)
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
}
