import XCTest
@testable import Domain
@testable import Infrastructure

final class BackupManagerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-BackupManager-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testSnapshotUsesTimestampReasonAndOwnerOnlyPermissions() throws {
        let source = directory.appendingPathComponent("settings.json")
        let payload = Data("{\"accounts\":[]}".utf8)
        try payload.write(to: source)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: source.path)

        let now = date(2026, 8, 14, 15, 4, 5)
        let manager = BackupManager(directory: directory)
        let snapshot = try manager.createSnapshot(of: source, reason: "schema-migration", now: now)

        XCTAssertTrue(snapshot.url.lastPathComponent.contains("20260814-150405"))
        XCTAssertTrue(snapshot.url.lastPathComponent.contains("schema-migration"))
        XCTAssertEqual(snapshot.reason, "schema-migration")
        XCTAssertEqual(try Data(contentsOf: snapshot.url), payload)
        XCTAssertEqual(posixPermissions(at: snapshot.url), 0o600)
        XCTAssertEqual(try Data(contentsOf: source), payload)
    }

    func testSettingsSaveCreatesBackupBeforeWrite() throws {
        let store = SettingsStore(directory: directory)
        let first = AppSettings(accounts: [
            BalanceAccount(kind: .deepseek, displayName: "First", secretRef: "ref-1"),
        ])
        try store.save(first)
        try store.save(AppSettings(accounts: [
            BalanceAccount(kind: .kimi, displayName: "Second", secretRef: "ref-2"),
        ], themeMode: "dark"))

        let backups = try snapshotFiles()
        XCTAssertFalse(backups.isEmpty, "save must snapshot the previous settings file")
        XCTAssertTrue(backups.contains { $0.lastPathComponent.contains("settings-write") })
        for url in backups {
            XCTAssertEqual(posixPermissions(at: url), 0o600)
        }
    }

    func testFailedWriteLeavesOriginalContentAndPermissionsUnchanged() throws {
        let store = SettingsStore(directory: directory)
        let original = AppSettings(accounts: [
            BalanceAccount(
                id: UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!,
                kind: .mimo,
                displayName: "Original",
                secretRef: "original-ref"
            ),
        ], themeMode: "light")
        try store.save(original)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: store.fileURL.path)
        let originalData = try Data(contentsOf: store.fileURL)

        let failing = SettingsStore(
            directory: directory,
            writer: { _, _ in throw TestWriteError.diskFull }
        )
        XCTAssertThrowsError(
            try failing.save(AppSettings(accounts: [
                BalanceAccount(kind: .kimi, displayName: "Should Not Persist", secretRef: "new-ref"),
            ], themeMode: "dark"))
        )

        XCTAssertEqual(try Data(contentsOf: store.fileURL), originalData)
        XCTAssertEqual(posixPermissions(at: store.fileURL), 0o600)
        let reloaded = SettingsStore(directory: directory).load()
        XCTAssertEqual(reloaded.accounts.first?.displayName, "Original")
        XCTAssertEqual(reloaded.themeMode, "light")
        XCTAssertFalse(try snapshotFiles().isEmpty)
    }

    func testSettingsWriteSnapshotsHonorRetentionLimit() throws {
        let source = directory.appendingPathComponent("settings.json")
        try Data("{\"accounts\":[]}".utf8).write(to: source)
        let manager = BackupManager(directory: directory)
        let calendar = Calendar(identifier: .gregorian)
        for index in 0..<12 {
            let now = calendar.date(
                from: DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: 2026,
                    month: 8,
                    day: 1,
                    hour: index,
                    minute: 0,
                    second: 0
                )
            )!
            _ = try manager.createSnapshot(of: source, reason: "settings-write", now: now)
        }
        _ = try manager.createSnapshot(
            of: source,
            reason: "restore",
            now: date(2026, 8, 14, 16, 0, 0)
        )

        let writes = try snapshotFiles().filter { $0.lastPathComponent.contains("settings-write") }
        let restores = try snapshotFiles().filter { $0.lastPathComponent.contains("restore") }
        XCTAssertEqual(writes.count, BackupManager.settingsWriteRetentionLimit)
        XCTAssertEqual(BackupManager.settingsWriteRetentionLimit, 8)
        XCTAssertEqual(restores.count, 1)
        XCTAssertTrue(writes.contains { $0.lastPathComponent.contains("20260801-110000") })
        XCTAssertFalse(writes.contains { $0.lastPathComponent.contains("20260801-000000") })
    }

    func testMigrationWriteFailureLeavesLegacyFileInPlace() throws {
        let source = try Data(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures/CommonCapabilities/legacy-settings-v0.json")
        )
        let fileURL = directory.appendingPathComponent("settings.json")
        try source.write(to: fileURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)

        let store = SettingsStore(
            directory: directory,
            writer: { _, _ in throw TestWriteError.diskFull }
        )
        let loaded = store.load()
        XCTAssertEqual(loaded.accounts.count, 1)
        XCTAssertEqual(try Data(contentsOf: fileURL), source)
        XCTAssertEqual(posixPermissions(at: fileURL), 0o600)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: source) as? [String: Any])
        XCTAssertNil(object["schemaVersion"])
    }

    private func snapshotFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent != "settings.json" && $0.pathExtension == "json" }
    }

    private func posixPermissions(at url: URL) -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let value = attributes?[.posixPermissions] as? NSNumber
        return (value?.intValue ?? 0) & 0o777
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return components.date!
    }
}

private enum TestWriteError: Error {
    case diskFull
}
