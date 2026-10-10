import XCTest
@testable import Domain

final class SafeModeRoutingTests: XCTestCase {
    func testNormalStartAndQuitDoNotEnterSafeMode() {
        XCTAssertEqual(
            RecoveryRouter.route(decision: .normal, firstLaunchRoute: .home),
            .home
        )
        XCTAssertFalse(RecoveryMarkerLifecyclePolicy.shouldClearMarker(for: .windowHidden))
        XCTAssertTrue(RecoveryMarkerLifecyclePolicy.shouldClearMarker(for: .explicitQuit))
        XCTAssertFalse(RecoveryMarkerLifecyclePolicy.countsAsUncleanExit(.explicitQuit))
        XCTAssertFalse(RecoveryMarkerLifecyclePolicy.countsAsUncleanExit(.windowHidden))
    }

    func testUncleanCountAtThresholdRoutesToSafeMode() {
        let decision = RecoveryDecision(
            enterSafeMode: true,
            reasons: [.consecutiveUncleanExits],
            consecutiveUncleanExits: RecoveryLimits.uncleanMarkerThreshold
        )
        XCTAssertEqual(
            RecoveryRouter.route(decision: decision, firstLaunchRoute: .home),
            .safeMode
        )
        XCTAssertEqual(
            RecoveryRouter.route(decision: decision, firstLaunchRoute: .onboarding),
            .safeMode
        )
        XCTAssertEqual(RecoveryLimits.uncleanMarkerThreshold, 2)
    }

    func testContinueUsesFirstLaunchRouteAndDoesNotClearDiagnosticsPolicy() {
        let continued = RecoveryDecision(
            enterSafeMode: true,
            reasons: [.consecutiveUncleanExits],
            consecutiveUncleanExits: RecoveryLimits.uncleanMarkerThreshold,
            continuedThisSession: true
        )
        XCTAssertEqual(
            RecoveryRouter.route(decision: continued, firstLaunchRoute: .home),
            .home
        )
        XCTAssertEqual(
            RecoveryRouter.routeAfterContinue(firstLaunchRoute: .home),
            .home
        )
        XCTAssertFalse(RecoveryContinuePolicy.clearsDiagnosticLedger())
        XCTAssertFalse(RecoveryContinuePolicy.resetsUncleanCount())
        XCTAssertTrue(RecoveryContinuePolicy.clearsCurrentSessionMarker())
    }

    func testExistingAccountsStillSkipOnboardingWhenNotInSafeMode() {
        XCTAssertEqual(
            FirstLaunchRouter.route(loadResult: .missing, hasExistingAccounts: true),
            .home
        )
        XCTAssertEqual(
            RecoveryRouter.route(
                decision: .normal,
                firstLaunchRoute: FirstLaunchRouter.route(
                    loadResult: .missing,
                    hasExistingAccounts: true
                )
            ),
            .home
        )
        XCTAssertNotEqual(
            RecoveryRouter.route(
                decision: RecoveryDecision(
                    enterSafeMode: true,
                    reasons: [.settingsCorrupt]
                ),
                firstLaunchRoute: .home
            ),
            .onboarding
        )
    }

    func testSafeModeBlocksRefreshNotificationSMTPProviderAndUpdateInstall() {
        for effect in RecoverySideEffect.allCases {
            XCTAssertFalse(
                RecoveryLaunchPolicy.allows(effect, route: .safeMode),
                "safe mode must block \(effect.rawValue)"
            )
            XCTAssertTrue(
                RecoveryLaunchPolicy.allows(effect, route: .home),
                "home must allow \(effect.rawValue)"
            )
        }
        XCTAssertFalse(RecoveryLaunchPolicy.allowsBackgroundRefresh(route: .safeMode))
        XCTAssertFalse(RecoveryLaunchPolicy.allowsProviderCredentialRead(route: .safeMode))
        XCTAssertFalse(RecoveryLaunchPolicy.allowsNotificationAuthorization(route: .safeMode))
        XCTAssertFalse(RecoveryLaunchPolicy.allowsNotificationDelivery(route: .safeMode))
        XCTAssertFalse(RecoveryLaunchPolicy.allowsSMTP(route: .safeMode))
        XCTAssertFalse(RecoveryLaunchPolicy.allowsUpdateInstall(route: .safeMode))
    }

    func testResetPolicyNeverDeletesKeychainAndRequiresSnapshot() {
        XCTAssertTrue(RecoveryResetPolicy.mustCreateSnapshotFirst)
        XCTAssertFalse(RecoveryResetPolicy.deletesKeychainEntries)
        XCTAssertEqual(
            RecoveryResetPolicy.leftoverCredentialsNoticeKey,
            "recovery.action.resetSettings.keychain_notice"
        )
        XCTAssertEqual(RecoveryResetPolicy.allowedResetTargets(includeUsageHistory: false), ["settings"])
        XCTAssertEqual(
            RecoveryResetPolicy.allowedResetTargets(includeUsageHistory: true),
            ["settings", "usageHistory"]
        )
        XCTAssertFalse(RecoveryResetPolicy.allowedResetTargets(includeUsageHistory: true).contains("keychain"))
    }

    func testDangerousActionsDoNotUseVagueContinueButton() {
        XCTAssertTrue(RecoveryActionPolicy.isDangerous(.restoreLatestSnapshot))
        XCTAssertTrue(RecoveryActionPolicy.isDangerous(.resetSettings))
        XCTAssertFalse(RecoveryActionPolicy.isDangerous(.continueNormalStart))
        XCTAssertTrue(RecoveryActionPolicy.requiresConfirmation(.restoreLatestSnapshot))
        XCTAssertTrue(RecoveryActionPolicy.requiresConfirmation(.resetSettings))
        XCTAssertTrue(RecoveryActionPolicy.requiresConfirmation(.continueNormalStart))
        XCTAssertEqual(
            RecoveryActionPolicy.confirmActionKey(for: .restoreLatestSnapshot),
            "recovery.action.restoreLatestSnapshot.confirm"
        )
        XCTAssertEqual(
            RecoveryActionPolicy.confirmActionKey(for: .resetSettings),
            "recovery.action.resetSettings.confirm"
        )
        XCTAssertEqual(
            RecoveryActionPolicy.confirmActionKey(for: .continueNormalStart),
            "recovery.action.continueNormalStart.confirm"
        )
        XCTAssertFalse(RecoveryActionPolicy.usesVagueContinueLabel(.restoreLatestSnapshot))
        XCTAssertFalse(RecoveryActionPolicy.usesVagueContinueLabel(.resetSettings))
        XCTAssertFalse(RecoveryActionPolicy.usesVagueContinueLabel(.continueNormalStart))
        XCTAssertEqual(RecoveryActionPolicy.cancelActionKey(), "recovery.action.cancel")
    }

    func testMarkerLifecycleDistinguishesHideQuitAndForceKill() {
        XCTAssertFalse(RecoveryMarkerLifecyclePolicy.shouldClearMarker(for: .windowHidden))
        XCTAssertFalse(RecoveryMarkerLifecyclePolicy.countsAsUncleanExit(.windowHidden))
        XCTAssertTrue(RecoveryMarkerLifecyclePolicy.shouldClearMarker(for: .explicitQuit))
        XCTAssertFalse(RecoveryMarkerLifecyclePolicy.countsAsUncleanExit(.explicitQuit))
        XCTAssertFalse(RecoveryMarkerLifecyclePolicy.shouldClearMarker(for: .forceKill))
        XCTAssertTrue(RecoveryMarkerLifecyclePolicy.countsAsUncleanExit(.forceKill))
        XCTAssertTrue(RecoveryMarkerLifecyclePolicy.leftoverPhaseIsUnclean(.launching))
        XCTAssertTrue(RecoveryMarkerLifecyclePolicy.leftoverPhaseIsUnclean(.healthy))
        XCTAssertFalse(RecoveryMarkerLifecyclePolicy.leftoverPhaseIsUnclean(.quitting))
    }
}
