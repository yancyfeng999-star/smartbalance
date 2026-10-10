import XCTest
@testable import Domain

final class CompatibilityMigrationResultTests: XCTestCase {
    func testLegacySettingsAndHealthyUsageProduceReadableCompatibilityResult() throws {
        let outcome = try SettingsMigration.migrate(data: fixture("legacy-settings-v0.json"))
        let result = CompatibilityMigrationResult.inspect(
            settingsOutcome: outcome,
            usageHealth: .available,
            notification: .authorized
        )

        XCTAssertTrue(result.settingsReadable)
        XCTAssertEqual(result.sourceSchemaVersion, 0)
        XCTAssertTrue(result.didMigrate)
        XCTAssertTrue(result.unknownProviderKinds.isEmpty)
        XCTAssertEqual(result.usageHealth, .available)
        XCTAssertEqual(result.usageHealth.messageKey, "usage.health.available")
        XCTAssertEqual(result.deletedAccountScope, .dropBaselineKeepDailyRecords)
        XCTAssertEqual(
            result.deletedAccountScope.messageKey,
            "compat.usage.deletedAccount.dropBaselineKeepDaily"
        )
        XCTAssertFalse(result.notification.blocksBalanceRefresh)
        XCTAssertFalse(result.notification.containsSensitivePayload)
        XCTAssertEqual(result.notification.state, .authorized)
        XCTAssertFalse(result.hasBlockingIssue)
    }

    func testUnknownProviderAndCurrencyAppearInCompatibilityResult() throws {
        let outcome = try SettingsMigration.migrate(
            data: fixture("legacy-settings-unknown-provider-currency.json")
        )
        let result = CompatibilityMigrationResult.inspect(
            settingsOutcome: outcome,
            usageHealth: .available,
            notification: .notDetermined
        )

        XCTAssertEqual(result.unknownProviderKinds, ["future-provider"])
        XCTAssertEqual(result.unknownCurrencyUnits, ["TOKENS"])
        XCTAssertTrue(result.settingsReadable)
        XCTAssertEqual(result.notification.state, .notDetermined)
        XCTAssertFalse(result.notification.blocksBalanceRefresh)
        XCTAssertFalse(result.hasBlockingIssue)

        let encoded = String(describing: result)
        XCTAssertFalse(encoded.contains("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"))
    }

    func testUsageNeedsRestoreIsWarningNotSilentEmptyHistory() {
        let result = CompatibilityMigrationResult.inspect(
            settingsOutcome: nil,
            usageHealth: .needsRestore,
            notification: .authorized
        )
        XCTAssertEqual(result.usageHealth, .needsRestore)
        XCTAssertEqual(result.usageHealth.messageKey, "usage.health.needs_restore")
        XCTAssertNotEqual(result.usageHealth, .available)
        XCTAssertTrue(result.usageHealth.isUserVisibleWarning)
        XCTAssertEqual(
            result.checks.first { $0.id == CompatibilityCheckID.usageHistory.rawValue }?.status,
            .warning
        )
    }

    func testUsageSaveFailureStaysIndependentOfSuccessfulBalances() {
        let display = UsageRefreshDisplayPolicy.applyRefreshTerminal(
            balanceSucceeded: true,
            usageSaveFailed: true,
            usageLoadFailed: false,
            recoveredFromCorruptFile: false
        )
        XCTAssertTrue(display.showsBalances)
        XCTAssertEqual(display.health, .lastSaveFailed)
        XCTAssertEqual(display.health.messageKey, "usage.health.save_failed")
        XCTAssertTrue(display.balanceAndUsageIndependent)

        let result = CompatibilityMigrationResult.inspect(
            settingsOutcome: nil,
            usageHealth: display.health,
            notification: .denied
        )
        XCTAssertEqual(result.usageHealth, .lastSaveFailed)
        XCTAssertFalse(result.notification.blocksBalanceRefresh)
        XCTAssertEqual(
            result.checks.first { $0.id == CompatibilityCheckID.usageHistory.rawValue }?.status,
            .warning
        )
    }

    func testCorruptSettingsAreFailedWithoutTreatingAsEmptyAccounts() {
        let result = CompatibilityMigrationResult.inspect(
            settingsOutcome: nil,
            settingsError: .invalidJSON,
            usageHealth: .available,
            notification: .authorized
        )
        XCTAssertFalse(result.settingsReadable)
        XCTAssertTrue(result.hasBlockingIssue)
        XCTAssertEqual(
            result.checks.first { $0.id == CompatibilityCheckID.settings.rawValue }?.status,
            .failed
        )
    }

    private func fixture(_ name: String) throws -> Data {
        try CommonCapabilityFixture.data(named: name, filePath: #filePath)
    }
}
