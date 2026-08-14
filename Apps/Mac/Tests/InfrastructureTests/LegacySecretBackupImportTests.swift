import XCTest
@testable import Domain
@testable import Infrastructure

final class LegacySecretBackupImportTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-LegacyImport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testLegacyV1IsRecognizedAndPreviewOmitsSecrets() throws {
        let data = try fixture("legacy-secret-backup-v1.json")
        let preview = try SettingsTransferService.preview(from: data)

        XCTAssertTrue(preview.isLegacySecretBackup)
        XCTAssertEqual(preview.format, "smartbalance.backup")
        XCTAssertEqual(preview.formatVersion, 1)
        XCTAssertFalse(preview.defaultImportEnabled)
        XCTAssertEqual(preview.legacyWarning, TransferPreview.legacyPlaintextWarning)
        XCTAssertEqual(preview.accountCount, 1)
        XCTAssertEqual(preview.providers, [.openrouter])
        XCTAssertEqual(preview.credentialsNeedReentryNames, ["Fixture OpenRouter"])
        XCTAssertTrue(preview.coverage.contains(.accounts))
        XCTAssertTrue(preview.excludedFields.contains("secrets"))
        XCTAssertFalse(preview.settings.accounts.isEmpty)
        XCTAssertNotEqual(
            preview.settings.accounts[0].secretRef,
            "66666666-6666-4666-8666-666666666666"
        )
        XCTAssertFalse(preview.settings.accounts[0].secretRef.contains("REDACTED"))
        XCTAssertNotEqual(preview.settings.email.passwordRef, "smtp-password")
    }

    func testConfirmedLegacyImportCarriesCredentialsForKeychainWrite() throws {
        let imported = try DataBackupService.importSettings(
            from: fixture("legacy-secret-backup-v1.json"),
            allowLegacyNonSensitive: true
        )

        XCTAssertEqual(imported.secrets.count, 2)
        XCTAssertTrue(imported.secrets.keys.contains(imported.settings.accounts[0].secretRef))
        XCTAssertTrue(imported.secrets.keys.contains(imported.settings.email.passwordRef))
    }

    func testDefaultRestoreOmitsLegacySecretsUntilConfirmed() async throws {
        let sourceURL = directory.appendingPathComponent("legacy-secret-backup-v1.json")
        let data = try fixture("legacy-secret-backup-v1.json")
        try data.write(to: sourceURL)

        let settingsStore = SettingsStore(directory: directory)
        try settingsStore.save(AppSettings(accounts: [
            BalanceAccount(kind: .deepseek, displayName: "Keep Original", secretRef: "keep-ref"),
        ], themeMode: "dark"))
        let original = try Data(contentsOf: settingsStore.fileURL)
        let secrets = LocalSecretStore()
        let probe = "legacy-import-probe-\(UUID().uuidString)"
        try secrets.set("pre-existing-value", account: probe)
        defer { secrets.delete(account: probe) }

        let coordinator = RestoreCoordinator(
            directory: directory,
            settingsStore: settingsStore,
            usageStore: UsageHistoryStore(directory: directory),
            backupManager: BackupManager(directory: directory),
            outcomes: DiagnosticOutcomeStore(directory: directory),
            secretStore: secrets
        )
        let denied = await coordinator.restore(
            from: data,
            confirmed: true,
            includeUsage: false,
            allowLegacyNonSensitive: false
        )
        XCTAssertEqual(denied.status, .cancelled)
        XCTAssertEqual(try Data(contentsOf: settingsStore.fileURL), original)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), "must not delete the user's v1 file")
        XCTAssertEqual(secrets.credentialPresence(for: probe), .present)
        XCTAssertEqual(secrets.get(account: probe), "pre-existing-value")
        XCTAssertEqual(secrets.credentialPresence(for: "66666666-6666-4666-8666-666666666666"), .missing)
        XCTAssertNotEqual(secrets.get(account: "smtp-password"), "REDACTED_TEST_TOKEN")

        let allowed = await coordinator.restore(
            from: data,
            confirmed: true,
            includeUsage: false,
            allowLegacyNonSensitive: true
        )
        XCTAssertEqual(allowed.status, .succeeded)
        XCTAssertFalse(allowed.credentialsNeedReentry)
        let imported = SettingsStore(directory: directory).load()
        XCTAssertEqual(imported.accounts.first?.displayName, "Fixture OpenRouter")
        let importedAccountRef = imported.accounts[0].secretRef
        let importedPasswordRef = imported.email.passwordRef
        defer {
            secrets.delete(account: importedAccountRef)
            secrets.delete(account: importedPasswordRef)
        }
        XCTAssertEqual(secrets.credentialPresence(for: importedAccountRef), .present)
        XCTAssertEqual(secrets.credentialPresence(for: importedPasswordRef), .present)
        XCTAssertEqual(secrets.get(account: probe), "pre-existing-value")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        let disk = try String(contentsOf: settingsStore.fileURL, encoding: .utf8)
        XCTAssertFalse(disk.contains("REDACTED_TEST_TOKEN"))
        XCTAssertFalse(disk.contains("\"secrets\""))
    }

    func testLegacyInspectDoesNotCallReplaceAllContract() throws {
        let data = try fixture("legacy-secret-backup-v1.json")
        XCTAssertThrowsError(
            try DataBackupService.importSettings(from: data)
        ) { error in
            XCTAssertEqual(error as? DataBackupService.BackupError, .legacyImportNotConfirmed)
        }
        let imported = try DataBackupService.importSettings(from: data, allowLegacyNonSensitive: true)
        XCTAssertFalse(imported.credentialsNeedReentry)
        XCTAssertNotEqual(
            imported.settings.accounts[0].secretRef,
            "66666666-6666-4666-8666-666666666666"
        )
    }

    private func fixture(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/CommonCapabilities/\(name)")
        return try Data(contentsOf: url)
    }
}
