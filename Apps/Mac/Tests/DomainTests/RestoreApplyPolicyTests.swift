import XCTest
@testable import Domain

final class RestoreApplyPolicyTests: XCTestCase {
    func testUsageInclusiveRestoreDoesNotResetBaselines() {
        XCTAssertFalse(RestoreApplyPolicy.shouldResetUsageBaselines(includedUsage: true))
        XCTAssertTrue(RestoreApplyPolicy.shouldResetUsageBaselines(includedUsage: false))
    }

    func testCancelInvalidatesInFlightRestoreToken() {
        var session = RestoreSession()
        let token = session.begin()
        XCTAssertTrue(session.isCurrent(token))
        session.cancel()
        XCTAssertFalse(session.isCurrent(token))
        let next = session.begin()
        XCTAssertTrue(session.isCurrent(next))
        XCTAssertFalse(session.isCurrent(token))
    }

    func testSnapshotFailedHasItsOwnLocalizationKey() {
        XCTAssertEqual(RestoreFailureReason.snapshotFailed.localizationKey, "restore.error.snapshot")
        XCTAssertNotEqual(
            RestoreFailureReason.snapshotFailed.localizationKey,
            RestoreFailureReason.settingsWriteFailed.localizationKey
        )
    }

    func testCredentialReentryCountOnlyIncludesMissingRecognizedAccounts() {
        let settings = AppSettings(accounts: [
            BalanceAccount(kind: .deepseek, secretRef: "missing"),
            BalanceAccount(kind: .openrouter, secretRef: "present"),
            BalanceAccount(kind: .unsupported, secretRef: "unsupported"),
        ])

        let count = CredentialReentryPolicy.missingAccountCredentialCount(
            settings: settings,
            presence: { $0 == "present" ? .present : .missing }
        )

        XCTAssertEqual(count, 1)
    }
}
