import XCTest
@testable import Domain
@testable import Infrastructure

final class DiagnosticsServiceTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-Diag-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testReportContainsOnlyAllowlistedFieldsAndNoSecretRef() throws {
        let report = DiagnosticsService().collect(makeContext())
        let data = try DiagnosticReport.encode(report)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertTrue(Set(object.keys).isSubset(of: DiagnosticReport.allowedTopLevelKeys))
        XCTAssertEqual(report.appVersion, "0.3.1")
        XCTAssertEqual(report.build, "82")
        XCTAssertEqual(report.architecture, "appleSilicon")
        XCTAssertEqual(report.launchMode, DiagnosticLaunchMode.menuBar.rawValue)
        XCTAssertEqual(report.schemaVersion, 1)
        XCTAssertEqual(report.keychainStatus, .available)
        XCTAssertEqual(Set(report.checks.map(\.id)), Set(DiagnosticCheckID.allCases.map(\.rawValue)))

        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(object.keys.contains("secretRef"))
        XCTAssertFalse(object.keys.contains("rawResponse"))
        XCTAssertFalse(json.contains("sk-test-secret-ref-must-not-export"))
        XCTAssertFalse(json.contains("/Users/"))
        XCTAssertEqual(report.providers, [
            DiagnosticProviderSummary(kind: "deepseek", enabled: true, hasCredentialRef: true),
        ])
    }

    func testFakeSecretsFromLogDoNotAppearInJSONTextOrZip() throws {
        let secrets = [
            "Bearer FAKESECRET_w3x4y5z6a7b8c9d0e1f2",
            "sk-test-fake-api-key-1234567890ABCDEF",
            "fake-cookie-value-zzzz",
            "SuperFakeSMTP-Pass-0001",
            "fake-query-token-xyz",
            "owner@example.test",
            "fake-json-secret-value",
        ]
        let log = directory.appendingPathComponent("app.log")
        let raw = """
        INFO Authorization: Bearer FAKESECRET_w3x4y5z6a7b8c9d0e1f2
        INFO api_key=sk-test-fake-api-key-1234567890ABCDEF
        INFO Cookie: session=fake-cookie-value-zzzz
        INFO smtpPassword: SuperFakeSMTP-Pass-0001
        INFO https://api.example.test/v1?token=fake-query-token-xyz
        INFO mailed owner@example.test
        INFO {"api_key":"fake-json-secret-value"}
        """
        try raw.write(to: log, atomically: true, encoding: .utf8)

        let context = makeContext(logFileURL: log)
        let report = DiagnosticsService().collect(context, options: DiagnosticOptions(maxLogLines: 50))
        let writer = DiagnosticArchiveWriter()
        let jsonURL = directory.appendingPathComponent("report.json")
        let textURL = directory.appendingPathComponent("report.txt")
        let zipURL = directory.appendingPathComponent("report.zip")
        try writer.writeJSON(report, to: jsonURL)
        try writer.writeText(report, to: textURL)
        try writer.writeZip(report, to: zipURL)

        let json = try String(contentsOf: jsonURL, encoding: .utf8)
        let text = try String(contentsOf: textURL, encoding: .utf8)
        let zip = try Data(contentsOf: zipURL)
        XCTAssertGreaterThan(zip.count, 30)
        XCTAssertTrue(text.hasPrefix("EXCLUDED") || text.contains("EXCLUDED"), text)
        for secret in secrets {
            XCTAssertFalse(json.contains(secret), "json leaked \(secret)")
            XCTAssertFalse(text.contains(secret), "txt leaked \(secret)")
            XCTAssertFalse(zipContains(zip, secret), "zip leaked \(secret)")
        }
        XCTAssertEqual(posixPermissions(at: jsonURL), 0o600)
        XCTAssertEqual(posixPermissions(at: textURL), 0o600)
        XCTAssertEqual(posixPermissions(at: zipURL), 0o600)
    }

    func testLargeLogReadsOnlyRecentFixedLineCount() throws {
        let log = directory.appendingPathComponent("app.log")
        var lines: [String] = []
        for index in 1...400 {
            lines.append("line-\(index) status=ok")
        }
        try lines.joined(separator: "\n").write(to: log, atomically: true, encoding: .utf8)

        let report = DiagnosticsService().collect(
            makeContext(logFileURL: log),
            options: DiagnosticOptions(maxLogLines: 20, maxLogReadBytes: 64 * 1024)
        )
        XCTAssertEqual(report.sanitizedLogLines.count, 20)
        XCTAssertTrue(report.sanitizedLogLines.last?.contains("line-400") == true)
        XCTAssertFalse(report.sanitizedLogLines.contains(where: { $0.contains("line-1") }))
        XCTAssertFalse(report.sanitizedLogLines.contains(where: { $0.contains("line-370") }))
    }

    func testArchiveWriteFailureDoesNotDeleteOriginalLog() throws {
        let log = directory.appendingPathComponent("app.log")
        let original = "keep-this-log-line\n"
        try original.write(to: log, atomically: true, encoding: .utf8)

        let blocked = directory.appendingPathComponent("blocked-file")
        try Data("not-a-directory".utf8).write(to: blocked)
        let destination = blocked.appendingPathComponent("report.json")

        XCTAssertThrowsError(
            try DiagnosticArchiveWriter().writeJSON(DiagnosticsService().collect(makeContext(logFileURL: log)), to: destination)
        )
        XCTAssertEqual(try String(contentsOf: log, encoding: .utf8), original)
        XCTAssertTrue(FileManager.default.fileExists(atPath: log.path))
    }

    func testTextSummarySurfacesProviderUsageAndLastRefresh() throws {
        let report = DiagnosticsService().collect(makeContext())
        let text = DiagnosticArchiveWriter.textSummary(report)
        XCTAssertTrue(text.contains("deepseek enabled=true hasCredentialRef=true"), text)
        XCTAssertTrue(text.contains("records=2"), text)
        XCTAssertTrue(text.contains("2026-08-01"), text)
        XCTAssertTrue(text.contains("2026-08-10"), text)
        XCTAssertTrue(text.contains("CNY"), text)
        XCTAssertTrue(text.contains("lastRefreshAt="), text)
        XCTAssertFalse(text.contains("secretRef="), text)
        XCTAssertEqual(report.check(.providers)?.redactedDetail?.contains("hasCredentialRef=true"), true)
        XCTAssertEqual(report.check(.usage)?.redactedDetail?.contains("2026-08-01"), true)
        XCTAssertEqual(report.check(.refresh)?.redactedDetail?.contains("lastRefreshAt="), true)
    }

    func testLatestLedgerOutcomeWinsOverOlderSnapshotFilename() throws {
        let old = directory.appendingPathComponent("settings-20260814-150405-settings-write.json")
        try Data("{}".utf8).write(to: old)
        let migration = directory.appendingPathComponent("settings-20260814-120000-schema-migration.json")
        try Data("{}".utf8).write(to: migration)
        let ledger = DiagnosticOutcomeLedger.empty
            .updated(.backup, result: .failed, at: Date(timeIntervalSince1970: 1_787_200_000))
            .updated(.migration, result: .failed, at: Date(timeIntervalSince1970: 1_787_200_100))
        try DiagnosticOutcomeStore(directory: directory).save(ledger)

        let context = DiagnosticsService.makeLiveContext(
            settings: AppSettings(),
            usage: UsageHistoryDocument(),
            usageSaveError: nil,
            refresh: DiagnosticRefreshSummary(state: "idle"),
            keychainStatus: .unknown,
            notificationAuthorization: .unknown,
            appVersion: "0.3.1",
            build: "82",
            applicationSupportDirectory: directory
        )
        XCTAssertEqual(context.lastBackupResult, "failed")
        XCTAssertEqual(context.lastMigrationResult, "failed")
        XCTAssertEqual(context.lastRestoreResult, "none")
        XCTAssertEqual(
            DiagnosticsService().collect(context).check(.backup)?.status,
            .failed
        )
    }

    func testFailedSettingsWriteRecordsFailedBackupOutcome() throws {
        let store = SettingsStore(directory: directory)
        try store.save(AppSettings(accounts: [
            BalanceAccount(kind: .deepseek, displayName: "Keep"),
        ]))
        let failing = SettingsStore(
            directory: directory,
            writer: { _, _ in throw TestWriteError.diskFull }
        )
        XCTAssertThrowsError(try failing.save(AppSettings(accounts: [
            BalanceAccount(kind: .kimi, displayName: "Nope"),
        ])))

        let context = DiagnosticsService.makeLiveContext(
            settings: AppSettings(),
            usage: UsageHistoryDocument(),
            usageSaveError: nil,
            refresh: DiagnosticRefreshSummary(state: "idle"),
            keychainStatus: .unknown,
            notificationAuthorization: .unknown,
            appVersion: "0.3.1",
            build: "82",
            applicationSupportDirectory: directory
        )
        XCTAssertEqual(context.lastBackupResult, "failed")
    }

    func testKeychainStatusNeverIncludesServiceAccountOrLength() throws {
        let report = DiagnosticsService().collect(makeContext(keychainStatus: .unavailable))
        XCTAssertEqual(report.keychainStatus, .unavailable)
        let json = try XCTUnwrap(String(data: try DiagnosticReport.encode(report), encoding: .utf8))
        XCTAssertFalse(json.contains("com.smartbalance.zhiyu.plain"))
        XCTAssertFalse(json.contains("kSecAttr"))
        XCTAssertFalse(json.lowercased().contains("key length"))
        XCTAssertEqual(report.check(.keychain)?.redactedDetail, "unavailable")
    }

    private func makeContext(
        logFileURL: URL? = nil,
        keychainStatus: DiagnosticKeychainStatus = .available
    ) -> DiagnosticsContext {
        DiagnosticsContext(
            now: Date(timeIntervalSince1970: 1_787_000_000),
            appVersion: "0.3.1",
            build: "82",
            osVersion: "15.6.0",
            architecture: "appleSilicon",
            launchMode: .menuBar,
            schemaVersion: 1,
            applicationSupport: DiagnosticDirectoryProbe(writable: true, posixPermissions: "700", fileSizeBytes: 128),
            logs: DiagnosticDirectoryProbe(writable: true, posixPermissions: "755", fileSizeBytes: 64),
            temporary: DiagnosticDirectoryProbe(writable: true, posixPermissions: "700", fileSizeBytes: 0),
            settingsReadable: true,
            settingsSchemaSupported: true,
            usageHistoryReadable: true,
            lastMigrationResult: "ok",
            lastBackupResult: "ok",
            lastRestoreResult: "none",
            keychainStatus: keychainStatus,
            notificationAuthorization: .authorized,
            refresh: DiagnosticRefreshSummary(state: "succeeded", lastRefreshAt: Date(timeIntervalSince1970: 1_787_000_100), succeededCount: 1, failedCount: 0),
            providers: [
                DiagnosticProviderSummary(kind: "deepseek", enabled: true, hasCredentialRef: true),
            ],
            usage: DiagnosticUsageSummary(
                recordCount: 2,
                earliestDate: "2026-08-01",
                latestDate: "2026-08-10",
                unitCategories: ["CNY"],
                saveErrorClassification: "none"
            ),
            logFileURL: logFileURL
        )
    }

    private func zipContains(_ data: Data, _ needle: String) -> Bool {
        guard let raw = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8) else {
            return data.range(of: Data(needle.utf8)) != nil
        }
        if raw.contains(needle) { return true }
        return data.range(of: Data(needle.utf8)) != nil
    }

    private func posixPermissions(at url: URL) -> Int {
        let value = try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        return value?.intValue ?? -1
    }
}

private enum TestWriteError: Error {
    case diskFull
}
