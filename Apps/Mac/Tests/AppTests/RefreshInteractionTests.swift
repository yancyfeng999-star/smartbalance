import XCTest
@testable import Domain

final class RefreshInteractionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_787_000_100)

    func testManualMenuAndIntervalTriggersShareAllScopeAndCoalesce() {
        let running = RefreshState.running(scope: .all, startedAt: now)
        for trigger in [RefreshTrigger.manual, .menuOpen, .interval] {
            XCTAssertEqual(RefreshRequest(trigger: trigger).scope, .all)
            XCTAssertEqual(
                RefreshAdmissionPolicy.decide(
                    request: RefreshRequest(trigger: trigger),
                    current: running,
                    accountCount: 2
                ),
                .ignoredSameScope,
                "trigger \(trigger) must share the running .all task"
            )
        }
    }

    func testFailedRefreshAllowsAnotherRequest() {
        let failed = RefreshState.failed(
            completedAt: now,
            messageKey: RefreshMessageKey.failed
        )
        XCTAssertEqual(
            RefreshAdmissionPolicy.decide(
                request: RefreshRequest(trigger: .manual),
                current: failed,
                accountCount: 1
            ),
            .started
        )
        XCTAssertTrue(RefreshPresentation.canStartNewRequest(failed))
        XCTAssertFalse(RefreshPresentation.isBusy(failed))
    }

    func testNoAccountsSkipsNetworkWithoutStartingATask() {
        XCTAssertEqual(
            RefreshAdmissionPolicy.decide(
                request: RefreshRequest(trigger: .interval),
                current: .idle,
                accountCount: 0
            ),
            .skippedNoAccounts
        )
        XCTAssertFalse(RefreshPresentation.isBusy(.idle))
    }

    func testRefreshButtonCancelsWhileRunningAndShowsLoading() {
        let running = RefreshState.running(scope: .all, startedAt: now)
        XCTAssertTrue(RefreshPresentation.isBusy(running))
        XCTAssertTrue(RefreshPresentation.refreshButtonCancels(running))
        XCTAssertEqual(
            RefreshPresentation.statusMessageKey(running),
            RefreshMessageKey.running
        )
        XCTAssertEqual(
            RefreshPresentation.refreshButtonHelpKey(running),
            RefreshMessageKey.cancelAction
        )

        XCTAssertFalse(RefreshPresentation.refreshButtonCancels(.idle))
        XCTAssertEqual(
            RefreshPresentation.refreshButtonHelpKey(.idle),
            RefreshMessageKey.refreshAction
        )
    }

    func testCancelWindowCloseAndSleepUseKeptLastCopy() {
        for reason in [
            RefreshCancelReason.user,
            .windowClosed,
            .background,
            .sleepWake,
        ] {
            XCTAssertTrue(reason.keepsLastSnapshot)
            XCTAssertTrue(reason.showsCancelledMessage)
        }
        XCTAssertFalse(RefreshCancelReason.superseded.showsCancelledMessage)
        XCTAssertTrue(RefreshCancelReason.superseded.keepsLastSnapshot)

        let cancelled = RefreshState.failed(
            completedAt: now,
            messageKey: RefreshMessageKey.cancelledKeptLast
        )
        XCTAssertEqual(
            RefreshPresentation.statusMessageKey(cancelled),
            RefreshMessageKey.cancelledKeptLast
        )
        XCTAssertEqual(
            RefreshPresentation.statusMessageKey(
                .partiallyFailed(completedAt: now, succeeded: 1, failed: 1)
            ),
            RefreshMessageKey.partialFailed
        )
        XCTAssertEqual(RefreshPresentation.lastRefreshPrefixKey, "refresh.last_prefix")
    }

    func testResignActiveAndThemeRebuildDoNotCancelRefresh() {
        XCTAssertNil(RefreshLifecyclePolicy.cancelReason(for: .applicationDidResignActive))
        XCTAssertNil(RefreshLifecyclePolicy.cancelReason(for: .themeIdentityRebuild))
        XCTAssertEqual(RefreshLifecyclePolicy.cancelReason(for: .windowClosed), .windowClosed)
        XCTAssertEqual(RefreshLifecyclePolicy.cancelReason(for: .willSleep), .sleepWake)
        XCTAssertEqual(RefreshLifecyclePolicy.cancelReason(for: .userCancel), .user)
        XCTAssertNil(RefreshLifecyclePolicy.cancelReason(for: .didWake))
        XCTAssertFalse(RefreshLifecyclePolicy.createsIndependentRefreshTimer(for: .menuAppear))
        XCTAssertFalse(RefreshLifecyclePolicy.createsIndependentRefreshTimer(for: .windowPinned))
        XCTAssertFalse(RefreshLifecyclePolicy.createsIndependentRefreshTimer(for: .pageSwitch))
        XCTAssertFalse(RefreshLifecyclePolicy.createsIndependentRefreshTimer(for: .notificationStateChange))
    }

    func testSupersededTerminalMustNotClearBaselineResetLoading() {
        XCTAssertFalse(
            RefreshLoadingPolicy.shouldApplyRefreshTerminalToLoading(owner: .usageBaselineReset)
        )
        XCTAssertTrue(
            RefreshLoadingPolicy.shouldApplyRefreshTerminalToLoading(owner: .refresh)
        )
    }
}
