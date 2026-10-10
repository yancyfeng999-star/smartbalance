import XCTest
@testable import Domain

final class AppSettingsMigrationTests: XCTestCase {
    func testLegacyAlertLanguageAndThemeFieldsReadWithStableDefaults() throws {
        let outcome = try SettingsMigration.migrate(data: fixture("legacy-settings-v0.json"))
        let settings = outcome.document.settings

        XCTAssertEqual(outcome.sourceSchemaVersion, 0)
        XCTAssertTrue(outcome.didMigrate)
        XCTAssertEqual(settings.themeMode, ThemeMode.system.rawValue)
        XCTAssertEqual(settings.appLanguage, AppLanguage.zhHans.rawValue)
        XCTAssertEqual(settings.refreshIntervalSecs, 900)
        XCTAssertTrue(settings.alertChannels.outboundEmailEnabled)
        XCTAssertTrue(settings.alertChannels.macNotificationEnabled)
        XCTAssertEqual(settings.alertChannels.warningAmount, 10)
        XCTAssertEqual(settings.alertChannels.warningPercent, 20)
        XCTAssertEqual(settings.alertChannels.cooldownSeconds, 3600)
        XCTAssertEqual(settings.email.smtpPort, 465)
        XCTAssertTrue(settings.email.useTLS)
        XCTAssertEqual(settings.email.passwordRef, "smtp-password")
    }

    func testMissingOptionalFieldsUseCurrentDefaults() throws {
        let json = """
        {
          "accounts": [
            {
              "id": "11111111-1111-4111-8111-111111111111",
              "kind": "deepseek",
              "displayName": "Sparse DeepSeek"
            }
          ]
        }
        """
        let outcome = try SettingsMigration.migrate(data: Data(json.utf8))
        let account = try XCTUnwrap(outcome.document.settings.accounts.first)
        let defaults = AppSettings()

        XCTAssertEqual(account.kind, .deepseek)
        XCTAssertTrue(account.enabled)
        XCTAssertNil(account.alertThreshold)
        XCTAssertNil(account.manualAmount)
        XCTAssertNil(account.manualUnit)
        XCTAssertFalse(account.secretRef.isEmpty)
        XCTAssertEqual(outcome.document.settings.themeMode, defaults.themeMode)
        XCTAssertEqual(outcome.document.settings.appLanguage, defaults.appLanguage)
        XCTAssertEqual(outcome.document.settings.refreshIntervalSecs, 900)
        XCTAssertEqual(outcome.document.settings.apiQueryEnabled, true)
        XCTAssertEqual(outcome.document.settings.alertChannels.outboundEmailEnabled, true)
        XCTAssertEqual(outcome.document.settings.email.smtpPort, 465)
        XCTAssertEqual(outcome.document.settings.email.passwordRef, "smtp-password")
    }

    func testUnknownProviderAndUnknownCurrencyRemainReadable() throws {
        let outcome = try SettingsMigration.migrate(
            data: fixture("legacy-settings-unknown-provider-currency.json")
        )
        let settings = outcome.document.settings
        XCTAssertEqual(settings.accounts.count, 2)

        let future = try XCTUnwrap(settings.accounts.first { $0.displayName == "Fixture Future" })
        XCTAssertFalse(future.kind.isRecognized)
        XCTAssertEqual(future.unrecognizedKind, "future-provider")
        XCTAssertEqual(future.manualUnit, "TOKENS")
        XCTAssertEqual(future.manualAmount, 3.25)
        XCTAssertTrue(future.enabled)

        let known = try XCTUnwrap(settings.accounts.first { $0.kind == .deepseek })
        XCTAssertEqual(known.displayName, "Fixture DeepSeek")
        XCTAssertEqual(settings.themeMode, ThemeMode.light.rawValue)
        XCTAssertEqual(settings.appLanguage, AppLanguage.en.rawValue)
        XCTAssertFalse(settings.alertChannels.outboundEmailEnabled)

        let encoded = try SettingsDocument.encode(outcome.document)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        XCTAssertTrue(json.contains("future-provider"))
        XCTAssertTrue(json.contains("TOKENS"))

        let roundTrip = try SettingsMigration.migrate(data: encoded)
        let again = try XCTUnwrap(
            roundTrip.document.settings.accounts.first { $0.displayName == "Fixture Future" }
        )
        XCTAssertEqual(again.unrecognizedKind, "future-provider")
        XCTAssertEqual(again.manualUnit, "TOKENS")
        XCTAssertFalse(again.kind.isRecognized)
    }

    func testOldThemeAndLanguageStringsResolveWithoutFailingDecode() throws {
        let json = """
        {
          "themeMode": "dark",
          "appLanguage": "en",
          "refreshIntervalSecs": 1800
        }
        """
        let outcome = try SettingsMigration.migrate(data: Data(json.utf8))
        XCTAssertEqual(outcome.document.settings.resolvedThemeMode, .dark)
        XCTAssertEqual(outcome.document.settings.resolvedLanguage, .en)
        XCTAssertEqual(outcome.document.settings.refreshIntervalSecs, 1800)
    }

    private func fixture(_ name: String) throws -> Data {
        try CommonCapabilityFixture.data(named: name, filePath: #filePath)
    }
}
