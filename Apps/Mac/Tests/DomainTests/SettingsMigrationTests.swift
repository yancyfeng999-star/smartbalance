import XCTest
@testable import Domain

final class SettingsMigrationTests: XCTestCase {
    func testLegacyV0RootMigratesAccountsAlertsThemeLanguageAndInterval() throws {
        let outcome = try SettingsMigration.migrate(data: fixture("legacy-settings-v0.json"))

        XCTAssertEqual(outcome.sourceSchemaVersion, 0)
        XCTAssertTrue(outcome.didMigrate)
        XCTAssertEqual(outcome.document.schemaVersion, SettingsDocument.currentSchemaVersion)

        let settings = outcome.document.settings
        XCTAssertEqual(settings.accounts.count, 1)
        XCTAssertEqual(settings.accounts[0].id.uuidString.lowercased(), "11111111-1111-4111-8111-111111111111")
        XCTAssertEqual(settings.accounts[0].kind, .deepseek)
        XCTAssertEqual(settings.accounts[0].displayName, "Fixture DeepSeek")
        XCTAssertEqual(settings.accounts[0].secretRef, "22222222-2222-4222-8222-222222222222")
        XCTAssertTrue(settings.accounts[0].enabled)
        XCTAssertEqual(settings.themeMode, ThemeMode.system.rawValue)
        XCTAssertEqual(settings.appLanguage, AppLanguage.zhHans.rawValue)
        XCTAssertEqual(settings.refreshIntervalSecs, 900)
        XCTAssertTrue(settings.apiQueryEnabled)
        XCTAssertFalse(settings.windowPinned)

        XCTAssertTrue(settings.alertChannels.outboundEmailEnabled)
        XCTAssertTrue(settings.alertChannels.macNotificationEnabled)
        XCTAssertTrue(settings.alertChannels.quotaThresholdAlertsEnabled)
        XCTAssertEqual(settings.alertChannels.cooldownSeconds, 3600)
        XCTAssertEqual(settings.alertChannels.warningAmount, 10)
        XCTAssertEqual(settings.alertChannels.warningPercent, 20)

        XCTAssertEqual(settings.email.smtpHost, "smtp.example.test")
        XCTAssertEqual(settings.email.smtpPort, 465)
        XCTAssertEqual(settings.email.passwordRef, "smtp-password")
    }

    func testMissingFieldsUseCurrentDefaults() throws {
        let data = Data("{}".utf8)
        let outcome = try SettingsMigration.migrate(data: data)
        let settings = outcome.document.settings
        let expected = AppSettings()

        XCTAssertTrue(outcome.didMigrate)
        XCTAssertEqual(settings.accounts, [])
        XCTAssertEqual(settings.email, expected.email)
        XCTAssertEqual(settings.alertChannels.outboundEmailEnabled, true)
        XCTAssertEqual(settings.alertChannels.macNotificationEnabled, true)
        XCTAssertEqual(settings.apiQueryEnabled, true)
        XCTAssertEqual(settings.refreshIntervalSecs, 900)
        XCTAssertEqual(settings.lastAlertAtByAccount, [:])
        XCTAssertEqual(settings.windowPinned, false)
        XCTAssertEqual(settings.themeMode, ThemeMode.system.rawValue)
        XCTAssertEqual(settings.appLanguage, AppLanguage.zhHans.rawValue)
        XCTAssertEqual(settings.email.smtpPort, 465)
        XCTAssertTrue(settings.email.useTLS)
        XCTAssertEqual(settings.email.passwordRef, "smtp-password")
    }

    func testEmailAlertModeEnabledMapsWhenAlertChannelsMissing() throws {
        let json = """
        {
          "emailAlertModeEnabled": false,
          "email": {
            "enabled": false,
            "smtpHost": "",
            "smtpPort": 465,
            "useTLS": true,
            "username": "",
            "passwordRef": "smtp-password",
            "fromAddress": "",
            "toAddresses": [],
            "defaultAmountThreshold": 10,
            "defaultPercentThreshold": 20,
            "cooldownSeconds": 3600
          }
        }
        """
        let outcome = try SettingsMigration.migrate(data: Data(json.utf8))

        XCTAssertFalse(outcome.document.settings.alertChannels.outboundEmailEnabled)
        XCTAssertFalse(outcome.document.extensions.keys.contains("emailAlertModeEnabled"))
        XCTAssertFalse(outcome.document.extensions.keys.contains("mailSources"))
        XCTAssertFalse(outcome.document.extensions.keys.contains("inboundMailbox"))
        XCTAssertFalse(outcome.document.extensions.keys.contains("platformMailEnabled"))
    }

    func testUnknownTopLevelAndAccountFieldsSurviveEncodeDecode() throws {
        let first = try SettingsMigration.migrate(data: fixture("legacy-settings-with-unknown-fields.json"))
        XCTAssertEqual(first.sourceSchemaVersion, 0)
        XCTAssertEqual(first.document.extensions["unknownTopLevelSetting"], .string("keep-me"))
        XCTAssertEqual(first.document.extensions["experimentalCloudSync"], .bool(false))
        guard case let .object(hint) = first.document.extensions["futureSchemaHint"] else {
            return XCTFail("futureSchemaHint must be preserved as an object")
        }
        XCTAssertEqual(hint["vendor"], .string("fixture-only"))
        XCTAssertEqual(hint["note"], .string("must-survive-round-trip"))

        let account = try XCTUnwrap(first.document.settings.accounts.first)
        XCTAssertEqual(account.displayName, "Fixture MiMo")
        XCTAssertEqual(account.userId, "fixture-user-42")
        XCTAssertEqual(account.extensions["legacyNotes"], .string("keep-unknown-account-field"))
        XCTAssertEqual(account.extensions["futureExperimentalFlag"], .bool(true))
        XCTAssertEqual(first.document.settings.themeMode, ThemeMode.dark.rawValue)
        XCTAssertEqual(first.document.settings.appLanguage, AppLanguage.en.rawValue)
        XCTAssertEqual(first.document.settings.refreshIntervalSecs, 1800)
        XCTAssertFalse(first.document.settings.alertChannels.outboundEmailEnabled)

        let encoded = try SettingsDocument.encode(first.document)
        let second = try SettingsMigration.migrate(data: encoded)

        XCTAssertEqual(second.document.schemaVersion, SettingsDocument.currentSchemaVersion)
        XCTAssertFalse(second.didMigrate)
        XCTAssertEqual(second.document.extensions["unknownTopLevelSetting"], .string("keep-me"))
        XCTAssertEqual(second.document.extensions["experimentalCloudSync"], .bool(false))
        XCTAssertEqual(second.document.settings.accounts.first?.extensions["legacyNotes"], .string("keep-unknown-account-field"))
        XCTAssertEqual(second.document.settings.accounts.first?.extensions["futureExperimentalFlag"], .bool(true))
        XCTAssertEqual(second.document.settings.accounts.first?.userId, "fixture-user-42")
        XCTAssertEqual(second.document.settings.themeMode, "dark")
        XCTAssertEqual(second.document.settings.refreshIntervalSecs, 1800)
    }

    func testLegacyIgnoredMailFieldsDoNotBlockKnownValidation() throws {
        let outcome = try SettingsMigration.migrate(data: fixture("legacy-settings-v0.json"))
        XCTAssertEqual(outcome.document.settings.accounts.count, 1)
        XCTAssertFalse(outcome.document.extensions.keys.contains("mailSources"))
        XCTAssertFalse(outcome.document.extensions.keys.contains("inboundMailbox"))
        XCTAssertFalse(outcome.document.extensions.keys.contains("platformMailEnabled"))
    }

    private func fixture(_ name: String) throws -> Data {
        try CommonCapabilityFixture.data(named: name, filePath: #filePath)
    }
}

enum CommonCapabilityFixture {
    static func data(named name: String, filePath: String) throws -> Data {
        let url = URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/CommonCapabilities/\(name)")
        return try Data(contentsOf: url)
    }
}
