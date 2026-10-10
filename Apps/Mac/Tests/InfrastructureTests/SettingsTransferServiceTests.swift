import XCTest
@testable import Domain
@testable import Infrastructure

final class SettingsTransferServiceTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-SettingsTransfer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testExportV2OmitsSecretsRefsAndKeepsManualAmounts() throws {
        var account = BalanceAccount(
            id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            kind: .deepseek,
            displayName: "Export Probe",
            secretRef: "sk-live-secret-ref-must-not-export",
            enabled: true
        )
        account.userId = "fixture-user-7"
        account.manualAmount = 42.5
        account.manualUnit = "USD"
        var email = EmailAlertSettings()
        email.enabled = true
        email.smtpHost = "smtp.example.test"
        email.username = "alerts@example.test"
        email.passwordRef = "smtp-secret-ref-must-not-export"
        email.fromAddress = "alerts@example.test"
        email.toAddresses = ["owner@example.test"]
        let settings = AppSettings(
            accounts: [account],
            email: email,
            themeMode: ThemeMode.light.rawValue,
            appLanguage: AppLanguage.en.rawValue
        )

        let data = try SettingsTransferService.exportData(
            settings: settings,
            appVersion: "0.3.1",
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("smartbalance.portable-settings"))
        XCTAssertFalse(json.contains("secretRef"), json)
        XCTAssertFalse(json.contains("passwordRef"), json)
        XCTAssertFalse(json.contains("\"secrets\""), json)
        XCTAssertFalse(json.contains("sk-live-secret-ref-must-not-export"), json)
        XCTAssertFalse(json.contains("smtp-secret-ref-must-not-export"), json)
        XCTAssertFalse(json.contains("Bearer "), json)
        XCTAssertFalse(json.contains("Cookie"), json)
        XCTAssertFalse(json.contains("api_key"), json)
        XCTAssertFalse(json.contains("usageHistory"), json)
        XCTAssertTrue(json.contains("42.5"), json)
        XCTAssertTrue(json.contains("USD"), json)
        XCTAssertTrue(json.contains("fixture-user-7"), json)

        let preview = try SettingsTransferService.preview(from: data)
        XCTAssertEqual(preview.settings.accounts[0].manualAmount, 42.5)
        XCTAssertEqual(preview.settings.accounts[0].manualUnit, "USD")
        XCTAssertNotEqual(preview.settings.accounts[0].secretRef, "sk-live-secret-ref-must-not-export")
        XCTAssertTrue(preview.credentialsNeedReentry)
    }

    func testExportFileUsesOwnerOnlyPermissions() throws {
        let url = directory.appendingPathComponent("transfer.json")
        try SettingsTransferService.writeExport(
            settings: AppSettings(accounts: [
                BalanceAccount(kind: .kimi, displayName: "Kimi", secretRef: "must-not-leave"),
            ]),
            appVersion: "0.3.1",
            to: url
        )
        XCTAssertEqual(posixPermissions(at: url), 0o600)
        let json = try XCTUnwrap(String(data: Data(contentsOf: url), encoding: .utf8))
        XCTAssertFalse(json.contains("must-not-leave"))
        XCTAssertFalse(json.contains("secretRef"))
    }

    func testPreviewListsCoverageAndDoesNotWrite() throws {
        let settingsStore = SettingsStore(directory: directory)
        let original = AppSettings(accounts: [
            BalanceAccount(
                id: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
                kind: .openrouter,
                displayName: "Keep Me",
                secretRef: "keep-ref"
            ),
        ], themeMode: "dark")
        try settingsStore.save(original)
        let settingsBefore = try Data(contentsOf: settingsStore.fileURL)
        let namesBefore = try fileNames()

        var incoming = EmailAlertSettings()
        incoming.smtpHost = "smtp.example.test"
        incoming.enabled = true
        let incomingSettings = AppSettings(
            accounts: [
                BalanceAccount(kind: .deepseek, displayName: "DeepSeek A", secretRef: "a"),
                BalanceAccount(kind: .kimi, displayName: "Kimi B", secretRef: "b"),
            ],
            email: incoming,
            themeMode: "light",
            appLanguage: "en"
        )
        let data = try SettingsTransferService.exportData(settings: incomingSettings, appVersion: "0.3.1")

        let preview = try SettingsTransferService.preview(from: data)

        XCTAssertEqual(preview.accountCount, 2)
        XCTAssertEqual(Set(preview.providers), Set([.deepseek, .kimi]))
        XCTAssertEqual(Set(preview.credentialsNeedReentryNames), Set(["DeepSeek A", "Kimi B"]))
        XCTAssertTrue(preview.coverage.contains(.accounts))
        XCTAssertTrue(preview.coverage.contains(.alertsAndMail))
        XCTAssertTrue(preview.coverage.contains(.refreshThemeLanguage))
        XCTAssertFalse(preview.coverage.contains(.usageHistory))
        XCTAssertTrue(preview.excludedFields.contains("secrets"))
        XCTAssertTrue(preview.excludedFields.contains("secretRef"))
        XCTAssertTrue(preview.excludedFields.contains("passwordRef"))
        XCTAssertTrue(preview.credentialsNeedReentry)
        XCTAssertTrue(preview.defaultImportEnabled)
        XCTAssertFalse(preview.isLegacySecretBackup)
        XCTAssertFalse(preview.includesUsageHistory)

        XCTAssertEqual(try Data(contentsOf: settingsStore.fileURL), settingsBefore)
        XCTAssertEqual(try fileNames(), namesBefore)
        XCTAssertEqual(SettingsStore(directory: directory).load().accounts.first?.displayName, "Keep Me")
    }

    private func fileNames() throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).map(\.lastPathComponent))
    }

    private func posixPermissions(at url: URL) -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let value = attributes?[.posixPermissions] as? NSNumber
        return (value?.intValue ?? 0) & 0o777
    }
}
