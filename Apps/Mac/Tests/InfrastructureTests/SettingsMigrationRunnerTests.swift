import XCTest
@testable import Domain
@testable import Infrastructure

final class SettingsMigrationRunnerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-SettingsMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testRunnerMigratesLegacyV0WithoutTouchingSourceFile() throws {
        let source = try fixture("legacy-settings-v0.json")
        let fileURL = directory.appendingPathComponent("settings.json")
        try source.write(to: fileURL)

        let outcome = try SettingsMigrationRunner().migrate(data: source)

        XCTAssertTrue(outcome.didMigrate)
        XCTAssertEqual(outcome.sourceSchemaVersion, 0)
        XCTAssertEqual(outcome.document.settings.accounts.count, 1)
        XCTAssertEqual(outcome.document.settings.accounts[0].displayName, "Fixture DeepSeek")
        XCTAssertEqual(outcome.document.settings.themeMode, "system")
        XCTAssertEqual(try Data(contentsOf: fileURL), source)
    }

    func testRunnerLeavesCurrentEnvelopeUnchanged() throws {
        let migrated = try SettingsMigration.migrate(data: fixture("legacy-settings-v0.json"))
        let encoded = try SettingsDocument.encode(migrated.document)

        let outcome = try SettingsMigrationRunner().migrate(data: encoded)

        XCTAssertFalse(outcome.didMigrate)
        XCTAssertEqual(outcome.sourceSchemaVersion, SettingsDocument.currentSchemaVersion)
        XCTAssertEqual(outcome.document.settings.accounts[0].displayName, "Fixture DeepSeek")
    }

    func testStoreRoundTripPreservesUnknownFields() throws {
        try writeFixture("legacy-settings-with-unknown-fields.json")
        let store = SettingsStore(directory: directory)
        let loaded = store.load()
        XCTAssertEqual(loaded.accounts.count, 1)
        XCTAssertEqual(loaded.extensions["unknownTopLevelSetting"], .string("keep-me"))
        XCTAssertEqual(loaded.accounts[0].extensions["legacyNotes"], .string("keep-unknown-account-field"))
        XCTAssertEqual(loaded.themeMode, "dark")
        XCTAssertEqual(loaded.refreshIntervalSecs, 1800)

        try store.save(loaded)
        let reloaded = SettingsStore(directory: directory).load()
        XCTAssertEqual(reloaded.extensions["unknownTopLevelSetting"], .string("keep-me"))
        XCTAssertEqual(reloaded.extensions["experimentalCloudSync"], .bool(false))
        XCTAssertEqual(reloaded.accounts[0].extensions["legacyNotes"], .string("keep-unknown-account-field"))
        XCTAssertEqual(reloaded.accounts[0].extensions["futureExperimentalFlag"], .bool(true))
        XCTAssertEqual(reloaded.accounts[0].userId, "fixture-user-42")
        XCTAssertEqual(reloaded.appLanguage, "en")
    }

    func testStoreRewritesLegacyRootAsEnvelopeAfterSuccessfulWrite() throws {
        try writeFixture("legacy-settings-v0.json")
        let store = SettingsStore(directory: directory)
        let loaded = store.load()
        XCTAssertEqual(loaded.accounts.count, 1)

        let raw = try Data(contentsOf: store.fileURL)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, SettingsDocument.currentSchemaVersion)
        XCTAssertNotNil(object["settings"])
        XCTAssertNotNil(object["updatedAt"])
        XCTAssertNotNil(object["extensions"])
    }

    func testEmptyAccountsCannotOverwriteExistingAccounts() throws {
        let store = SettingsStore(directory: directory)
        let account = BalanceAccount(
            id: UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!,
            kind: .deepseek,
            displayName: "Keep Me",
            secretRef: "keep-ref",
            enabled: true
        )
        try store.save(AppSettings(accounts: [account], themeMode: "system"))
        try store.save(AppSettings(accounts: [], themeMode: "dark", appLanguage: "en"))

        let reloaded = SettingsStore(directory: directory).load()
        XCTAssertEqual(reloaded.accounts.count, 1)
        XCTAssertEqual(reloaded.accounts[0].displayName, "Keep Me")
        XCTAssertEqual(reloaded.themeMode, "dark")
        XCTAssertEqual(reloaded.appLanguage, "en")
    }

    func testCorruptFileIsBackedUpAndReturnsDefaults() throws {
        try writeFixture("corrupt-settings.json")
        let store = SettingsStore(directory: directory)
        let loaded = store.load()
        XCTAssertEqual(loaded, AppSettings())

        let names = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
        XCTAssertTrue(names.contains { $0.hasPrefix("settings.corrupt-") && $0.hasSuffix(".json") })
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testPortableDefaultBuilderDoesNotIncludeSecrets() throws {
        let settings = AppSettings(accounts: [
            BalanceAccount(kind: .openrouter, secretRef: "sk-live-must-not-export"),
        ])
        let package = DataBackupService.makePackage(settings: settings, appVersion: "0.3.1")
        XCTAssertEqual(package.format, "smartbalance.portable-settings")
        XCTAssertEqual(package.formatVersion, 2)

        let encoded = try DataBackupService.encode(package)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        XCTAssertFalse(json.contains("secretRef"))
        XCTAssertFalse(json.contains("passwordRef"))
        XCTAssertFalse(json.contains("\"secrets\""))
        XCTAssertFalse(json.contains("sk-live-must-not-export"))
    }

    func testLegacyV1BackupIsRecognizedButSecretsAreNotImported() throws {
        let data = try fixture("legacy-secret-backup-v1.json")
        let inspection = try DataBackupService.inspect(data)

        guard case let .legacySecret(warning) = inspection else {
            return XCTFail("v1 backup must be recognized as legacy secret package")
        }
        XCTAssertEqual(warning.formatVersion, 1)
        XCTAssertEqual(warning.secretEntryCount, 2)
        XCTAssertTrue(warning.warningMessage.contains("不会导入"))
        XCTAssertEqual(warning.preview.accounts.count, 1)
        XCTAssertEqual(warning.preview.accounts[0].displayName, "Fixture OpenRouter")

        let imported = try DataBackupService.importSettings(from: data)
        XCTAssertTrue(imported.credentialsNeedReentry)
        XCTAssertEqual(imported.settings.accounts.count, 1)
        XCTAssertNotEqual(
            imported.settings.accounts[0].secretRef,
            "66666666-6666-4666-8666-666666666666"
        )
        XCTAssertNotEqual(imported.settings.email.passwordRef, "smtp-password")

        let encodedPreview = try PortableSettings.encode(warning.preview)
        let previewJSON = try XCTUnwrap(String(data: encodedPreview, encoding: .utf8))
        XCTAssertFalse(previewJSON.contains("REDACTED_TEST_TOKEN"))
        XCTAssertFalse(previewJSON.contains("\"secrets\""))
    }

    private func writeFixture(_ name: String) throws {
        try fixture(name).write(to: directory.appendingPathComponent("settings.json"))
    }

    private func fixture(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/CommonCapabilities/\(name)")
        return try Data(contentsOf: url)
    }
}
