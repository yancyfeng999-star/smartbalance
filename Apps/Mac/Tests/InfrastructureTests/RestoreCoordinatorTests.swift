import XCTest
@testable import Domain
@testable import Infrastructure

final class RestoreCoordinatorTests: XCTestCase {
    private let accountID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-Restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testCancelLeavesSettingsAndUsageUnchanged() async throws {
        let env = try await seedOriginals()
        let originalSettings = try Data(contentsOf: env.settingsStore.fileURL)
        let originalUsage = try Data(contentsOf: env.usageStore.fileURL)
        let incoming = try SettingsTransferService.exportData(
            settings: AppSettings(accounts: [
                BalanceAccount(kind: .kimi, displayName: "Should Not Apply", secretRef: "new"),
            ], themeMode: "light"),
            appVersion: "0.3.1"
        )

        let outcome = await env.coordinator.restore(
            from: incoming,
            confirmed: false,
            includeUsage: true
        )

        XCTAssertEqual(outcome.status, .cancelled)
        XCTAssertEqual(try Data(contentsOf: env.settingsStore.fileURL), originalSettings)
        XCTAssertEqual(try Data(contentsOf: env.usageStore.fileURL), originalUsage)
        XCTAssertEqual(DiagnosticOutcomeStore(directory: directory).load().restore.result, .none)
        XCTAssertEqual(SettingsStore(directory: directory).load().accounts.first?.displayName, "Original")
    }

    func testFormatMismatchLeavesOriginalsUnchanged() async throws {
        let env = try await seedOriginals()
        let originalSettings = try Data(contentsOf: env.settingsStore.fileURL)
        let originalUsage = try Data(contentsOf: env.usageStore.fileURL)

        let outcome = await env.coordinator.restore(
            from: Data("{\"format\":\"not-smartbalance\"}".utf8),
            confirmed: true,
            includeUsage: true
        )

        XCTAssertEqual(outcome.status, .failed)
        XCTAssertEqual(outcome.failureReason, .formatMismatch)
        XCTAssertEqual(try Data(contentsOf: env.settingsStore.fileURL), originalSettings)
        XCTAssertEqual(try Data(contentsOf: env.usageStore.fileURL), originalUsage)
        XCTAssertEqual(SettingsStore(directory: directory).load().themeMode, "dark")
    }

    func testVersionTooNewLeavesOriginalsUnchanged() async throws {
        let env = try await seedOriginals()
        let originalSettings = try Data(contentsOf: env.settingsStore.fileURL)
        let originalUsage = try Data(contentsOf: env.usageStore.fileURL)
        let payload = """
        {
          "format": "smartbalance.portable-settings",
          "formatVersion": 99,
          "exportedAt": "2026-08-14T00:00:00Z",
          "appVersion": "9.9.9",
          "accounts": [],
          "email": {
            "enabled": false,
            "smtpHost": "",
            "smtpPort": 465,
            "useTLS": true,
            "username": "",
            "fromAddress": "",
            "toAddresses": [],
            "defaultAmountThreshold": 10,
            "defaultPercentThreshold": 20,
            "cooldownSeconds": 3600
          },
          "alertChannels": {
            "macNotificationEnabled": true,
            "outboundEmailEnabled": false,
            "quotaThresholdAlertsEnabled": true,
            "warningAmount": 100,
            "midAmount": 50,
            "criticalAmount": 20,
            "warningPercent": 30,
            "midPercent": 15,
            "criticalPercent": 10,
            "cooldownSeconds": 3600
          },
          "apiQueryEnabled": true,
          "refreshIntervalSecs": 900,
          "windowPinned": false,
          "themeMode": "light",
          "appLanguage": "en"
        }
        """

        let outcome = await env.coordinator.restore(
            from: Data(payload.utf8),
            confirmed: true,
            includeUsage: false
        )

        XCTAssertEqual(outcome.status, .failed)
        XCTAssertEqual(outcome.failureReason, .versionTooNew)
        XCTAssertEqual(try Data(contentsOf: env.settingsStore.fileURL), originalSettings)
        XCTAssertEqual(try Data(contentsOf: env.usageStore.fileURL), originalUsage)
    }

    func testCorruptUsageLeavesOriginalsUnchanged() async throws {
        let env = try await seedOriginals()
        let originalSettings = try Data(contentsOf: env.settingsStore.fileURL)
        let originalUsage = try Data(contentsOf: env.usageStore.fileURL)
        let package = LocalRestorePackage.make(
            from: AppSettings(accounts: [
                BalanceAccount(kind: .kimi, displayName: "Incoming", secretRef: "in"),
            ], themeMode: "light"),
            usage: nil,
            appVersion: "0.3.1"
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try LocalRestorePackage.encode(package)) as? [String: Any]
        )
        object["usageHistory"] = "not-a-usage-document"
        var meta = try XCTUnwrap(object["restoreMetadata"] as? [String: Any])
        meta["includeUsageHistory"] = true
        object["restoreMetadata"] = meta
        let corrupt = try JSONSerialization.data(withJSONObject: object)

        let outcome = await env.coordinator.restore(
            from: corrupt,
            confirmed: true,
            includeUsage: true
        )

        XCTAssertEqual(outcome.status, .failed)
        XCTAssertEqual(outcome.failureReason, .corruptUsage)
        XCTAssertEqual(try Data(contentsOf: env.settingsStore.fileURL), originalSettings)
        XCTAssertEqual(try Data(contentsOf: env.usageStore.fileURL), originalUsage)
        XCTAssertEqual(SettingsStore(directory: directory).load().accounts.first?.displayName, "Original")
    }

    func testSettingsWriteFailureRollsBackAndRecordsFailedRestore() async throws {
        let env = try await seedOriginals()
        let originalSettings = try Data(contentsOf: env.settingsStore.fileURL)
        let originalUsage = try Data(contentsOf: env.usageStore.fileURL)
        let failingSettings = SettingsStore(
            directory: directory,
            writer: { _, _ in throw TestRestoreWriteError.diskFull }
        )
        let coordinator = RestoreCoordinator(
            directory: directory,
            settingsStore: failingSettings,
            usageStore: env.usageStore,
            backupManager: BackupManager(directory: directory),
            outcomes: DiagnosticOutcomeStore(directory: directory)
        )
        let incoming = try SettingsTransferService.exportData(
            settings: AppSettings(accounts: [
                BalanceAccount(kind: .kimi, displayName: "Must Not Persist", secretRef: "x"),
            ], themeMode: "light"),
            appVersion: "0.3.1"
        )

        let outcome = await coordinator.restore(
            from: incoming,
            confirmed: true,
            includeUsage: false
        )

        XCTAssertEqual(outcome.status, .failed)
        XCTAssertEqual(outcome.failureReason, .settingsWriteFailed)
        XCTAssertEqual(try Data(contentsOf: env.settingsStore.fileURL), originalSettings)
        XCTAssertEqual(try Data(contentsOf: env.usageStore.fileURL), originalUsage)
        XCTAssertEqual(posixPermissions(at: env.settingsStore.fileURL), 0o600)
        XCTAssertEqual(DiagnosticOutcomeStore(directory: directory).load().restore.result, .failed)
        XCTAssertEqual(SettingsStore(directory: directory).load().accounts.first?.displayName, "Original")
    }

    func testSuccessfulRestoreKeepsUsageSchemaUnitsAndFourHundredDayTrim() async throws {
        let env = try await seedOriginals()
        var incoming = BalanceAccount(
            id: accountID,
            kind: .deepseek,
            displayName: "Restored",
            secretRef: "old-ref"
        )
        incoming.manualAmount = 8
        incoming.manualUnit = "CNY"
        let now = date(2026, 8, 10, 9)
        let keptDay = calendar.date(byAdding: .day, value: -399, to: calendar.startOfDay(for: now))!
        let expiredDay = calendar.date(byAdding: .day, value: -500, to: calendar.startOfDay(for: now))!
        let usage = UsageHistoryDocument(
            schemaVersion: 1,
            baselines: [
                UsageBaseline(
                    accountId: accountID,
                    providerKind: .deepseek,
                    unit: "CNY",
                    method: .balanceDeltaEstimate,
                    value: 100,
                    sampledAt: now
                ),
            ],
            dailyRecords: [
                record(dayKey: dayKey(for: now), unit: "CNY", amount: 3),
                record(dayKey: dayKey(for: now), unit: "USD", amount: 1.5),
                record(dayKey: dayKey(for: now), unit: "tokens", amount: 9),
                record(dayKey: dayKey(for: keptDay), unit: "CNY", amount: 2),
                record(dayKey: dayKey(for: expiredDay), unit: "CNY", amount: 99),
            ],
            updatedAt: now
        )
        let package = LocalRestorePackage.make(
            from: AppSettings(accounts: [incoming], themeMode: "light", appLanguage: "en"),
            usage: usage,
            appVersion: "0.3.1",
            now: now
        )
        let encoded = try LocalRestorePackage.encode(package)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("old-ref"))
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("\"secrets\""))

        let outcome = await env.coordinator.restore(
            from: encoded,
            confirmed: true,
            includeUsage: true
        )

        XCTAssertEqual(outcome.status, .succeeded)
        XCTAssertTrue(outcome.credentialsNeedReentry)
        XCTAssertTrue(outcome.includedUsage)
        XCTAssertEqual(DiagnosticOutcomeStore(directory: directory).load().restore.result, .ok)

        let loadedSettings = SettingsStore(directory: directory).load()
        XCTAssertEqual(loadedSettings.accounts.first?.displayName, "Restored")
        XCTAssertEqual(loadedSettings.accounts.first?.manualAmount, 8)
        XCTAssertEqual(loadedSettings.accounts.first?.manualUnit, "CNY")
        XCTAssertNotEqual(loadedSettings.accounts.first?.secretRef, "old-ref")
        XCTAssertEqual(loadedSettings.themeMode, "light")

        let reloaded = try await UsageHistoryStore(directory: directory).load().document
        XCTAssertEqual(reloaded.schemaVersion, UsageHistoryDocument.currentSchemaVersion)
        XCTAssertEqual(reloaded.schemaVersion, 1)
        let units = Set(reloaded.dailyRecords.map { UsageUnit.normalize($0.unit) })
        XCTAssertTrue(units.contains("CNY"))
        XCTAssertTrue(units.contains("USD"))
        XCTAssertTrue(units.contains("tokens"))

        let daySummary = UsageSummaryBuilder.build(
            document: reloaded,
            period: .day,
            anchor: now,
            calendar: calendar
        )
        let weekSummary = UsageSummaryBuilder.build(
            document: reloaded,
            period: .week,
            anchor: now,
            calendar: calendar
        )
        let monthSummary = UsageSummaryBuilder.build(
            document: reloaded,
            period: .month,
            anchor: now,
            calendar: calendar
        )
        XCTAssertEqual(Set(daySummary.currencies.map(\.unit)), Set(["CNY", "USD", "tokens"]))
        XCTAssertFalse(weekSummary.currencies.isEmpty)
        XCTAssertFalse(monthSummary.currencies.isEmpty)

        let trimmed = UsageAccumulator.ingest(
            snapshots: [],
            knownAccountIDs: [accountID],
            document: reloaded,
            now: now,
            calendar: calendar,
            retentionDays: 400
        )
        XCTAssertTrue(trimmed.dailyRecords.contains { $0.dayKey == dayKey(for: keptDay) })
        XCTAssertFalse(trimmed.dailyRecords.contains { $0.dayKey == dayKey(for: expiredDay) })
        XCTAssertEqual(
            UsageAccumulator.ingest(
                snapshots: [],
                knownAccountIDs: [accountID],
                document: reloaded,
                now: now,
                calendar: calendar
            ).dailyRecords.count,
            trimmed.dailyRecords.count
        )
    }

    private struct Env {
        var settingsStore: SettingsStore
        var usageStore: UsageHistoryStore
        var coordinator: RestoreCoordinator
    }

    private func seedOriginals() async throws -> Env {
        let settingsStore = SettingsStore(directory: directory)
        try settingsStore.save(AppSettings(accounts: [
            BalanceAccount(
                id: accountID,
                kind: .deepseek,
                displayName: "Original",
                secretRef: "original-ref"
            ),
        ], themeMode: "dark"))
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: settingsStore.fileURL.path
        )
        let usageStore = UsageHistoryStore(directory: directory)
        let now = date(2026, 8, 10, 9)
        _ = try await usageStore.record(
            snapshots: [
                BalanceSnapshot(
                    accountId: accountID,
                    providerKind: .deepseek,
                    displayName: "Original",
                    amount: 100,
                    unit: "¥",
                    status: .healthy,
                    fetchedAt: now
                ),
            ],
            knownAccountIDs: [accountID],
            now: now,
            calendar: calendar
        )
        let coordinator = RestoreCoordinator(
            directory: directory,
            settingsStore: settingsStore,
            usageStore: usageStore,
            backupManager: BackupManager(directory: directory),
            outcomes: DiagnosticOutcomeStore(directory: directory)
        )
        return Env(settingsStore: settingsStore, usageStore: usageStore, coordinator: coordinator)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func record(dayKey: String, unit: String, amount: Double) -> UsageDailyRecord {
        UsageDailyRecord(
            dayKey: dayKey,
            timeZoneIdentifier: "Asia/Shanghai",
            accountId: accountID,
            providerKind: .deepseek,
            unit: unit,
            providerAmount: 0,
            estimatedAmount: amount,
            sampleCount: 1,
            hasBoundaryGap: false
        )
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    private func posixPermissions(at url: URL) -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let value = attributes?[.posixPermissions] as? NSNumber
        return (value?.intValue ?? 0) & 0o777
    }
}

private enum TestRestoreWriteError: Error {
    case diskFull
}
