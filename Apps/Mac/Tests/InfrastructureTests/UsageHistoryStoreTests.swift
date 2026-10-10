import Darwin
import XCTest
@testable import Infrastructure
@testable import Domain

final class UsageHistoryStoreTests: XCTestCase {
    private let accountID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-UsageHistoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testMissingFileLoadsEmptyDocument() async throws {
        let store = UsageHistoryStore(directory: directory)

        let result = try await store.load()

        XCTAssertEqual(result.document, UsageHistoryDocument())
        XCTAssertNil(result.recovery)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testRecordRoundTripsDocument() async throws {
        let store = UsageHistoryStore(directory: directory)
        let firstDate = date(2026, 8, 10, 9)
        _ = try await store.record(
            snapshots: [snapshot(amount: 100, fetchedAt: firstDate)],
            knownAccountIDs: [accountID],
            now: firstDate,
            calendar: calendar
        )
        let secondDate = date(2026, 8, 10, 10)
        let saved = try await store.record(
            snapshots: [snapshot(amount: 96.5, fetchedAt: secondDate)],
            knownAccountIDs: [accountID],
            now: secondDate,
            calendar: calendar
        )

        let reloaded = try await UsageHistoryStore(directory: directory).load().document

        XCTAssertEqual(reloaded, saved)
        XCTAssertEqual(reloaded.dailyRecords.first?.estimatedAmount, 3.5)
    }

    func testSavedFileUsesOwnerReadWritePermissions() async throws {
        let store = UsageHistoryStore(directory: directory)
        let now = date(2026, 8, 10, 9)
        _ = try await store.record(
            snapshots: [snapshot(amount: 100, fetchedAt: now)],
            knownAccountIDs: [accountID],
            now: now,
            calendar: calendar
        )

        let attributes = try FileManager.default.attributesOfItem(atPath: store.fileURL.path)
        let permissions = attributes[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
    }

    func testCorruptFileIsBackedUpAndReturnsEmptyDocument() async throws {
        let fileURL = directory.appendingPathComponent("usage-history.json")
        try Data("not-json".utf8).write(to: fileURL)
        let store = UsageHistoryStore(directory: directory)

        let result = try await store.load()
        let filenames = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).map(\.lastPathComponent)

        XCTAssertEqual(result.document, UsageHistoryDocument())
        XCTAssertEqual(result.recovery, .corruptFileBackedUp)
        XCTAssertTrue(filenames.contains { $0.hasPrefix("usage-history.corrupt-") && $0.hasSuffix(".json") })
    }

    func testUnreadableExistingPathThrowsAndRecordDoesNotReplaceIt() async throws {
        let store = UsageHistoryStore(directory: directory)
        try FileManager.default.createDirectory(at: store.fileURL, withIntermediateDirectories: false)

        do {
            _ = try await store.load()
            XCTFail("expected existing unreadable path to fail")
        } catch {
            // Expected.
        }

        do {
            _ = try await store.record(
                snapshots: [snapshot(amount: 100, fetchedAt: date(2026, 8, 10, 9))],
                knownAccountIDs: [accountID],
                now: date(2026, 8, 10, 9),
                calendar: calendar
            )
            XCTFail("record must not overwrite history that failed to load")
        } catch {
            // Expected.
        }

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testRecordCallsAreSerialized() async throws {
        let probe = WriterProbe()
        let store = UsageHistoryStore(
            filename: "usage-history.json",
            directory: directory,
            writer: probe.write
        )
        let now = date(2026, 8, 10, 9)
        _ = try await store.record(
            snapshots: [snapshot(amount: 100, fetchedAt: now)],
            knownAccountIDs: [accountID],
            now: now,
            calendar: calendar
        )
        let repeatedSnapshot = snapshot(amount: 99, fetchedAt: date(2026, 8, 10, 10))
        let accountID = accountID
        let calendar = calendar

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    _ = try await store.record(
                        snapshots: [repeatedSnapshot],
                        knownAccountIDs: [accountID],
                        now: repeatedSnapshot.fetchedAt,
                        calendar: calendar
                    )
                }
            }
            try await group.waitForAll()
        }

        let document = await store.currentDocument()
        XCTAssertEqual(probe.maximumConcurrentWrites, 1)
        XCTAssertEqual(document.dailyRecords.first?.estimatedAmount, 1)
    }

    func testRemovedAccountDropsBaselineButKeepsDailyHistory() async throws {
        let store = UsageHistoryStore(directory: directory)
        let firstDate = date(2026, 8, 10, 9)
        _ = try await store.record(
            snapshots: [snapshot(amount: 100, fetchedAt: firstDate)],
            knownAccountIDs: [accountID],
            now: firstDate,
            calendar: calendar
        )
        let secondDate = date(2026, 8, 10, 10)
        _ = try await store.record(
            snapshots: [snapshot(amount: 98, fetchedAt: secondDate)],
            knownAccountIDs: [accountID],
            now: secondDate,
            calendar: calendar
        )

        let removed = try await store.record(
            snapshots: [],
            knownAccountIDs: [],
            now: secondDate,
            calendar: calendar
        )

        XCTAssertTrue(removed.baselines.isEmpty)
        XCTAssertEqual(removed.dailyRecords.count, 1)
        XCTAssertEqual(removed.dailyRecords[0].estimatedAmount, 2)
    }

    func testResetBaselineForChangedCredentialKeepsDailyHistory() async throws {
        let store = UsageHistoryStore(directory: directory)
        let firstDate = date(2026, 8, 10, 9)
        _ = try await store.record(
            snapshots: [snapshot(amount: 100, fetchedAt: firstDate)],
            knownAccountIDs: [accountID],
            now: firstDate,
            calendar: calendar
        )
        let secondDate = date(2026, 8, 10, 10)
        _ = try await store.record(
            snapshots: [snapshot(amount: 98, fetchedAt: secondDate)],
            knownAccountIDs: [accountID],
            now: secondDate,
            calendar: calendar
        )

        let reset = try await store.resetBaselines(for: [accountID])
        let reloaded = try await UsageHistoryStore(directory: directory).load().document

        XCTAssertTrue(reset.baselines.isEmpty)
        XCTAssertEqual(reset.dailyRecords.count, 1)
        XCTAssertEqual(reset.dailyRecords[0].estimatedAmount, 2)
        XCTAssertEqual(reloaded, reset)
    }

    func testFailedSaveKeepsLastCommittedInMemoryDocument() async throws {
        let writer = FailAfterFirstWriter()
        let store = UsageHistoryStore(
            filename: "usage-history.json",
            directory: directory,
            writer: writer.write
        )
        let firstDate = date(2026, 8, 10, 9)
        let committed = try await store.record(
            snapshots: [snapshot(amount: 100, fetchedAt: firstDate)],
            knownAccountIDs: [accountID],
            now: firstDate,
            calendar: calendar
        )
        let diskBeforeFailure = try Data(contentsOf: store.fileURL)

        do {
            _ = try await store.record(
                snapshots: [snapshot(amount: 90, fetchedAt: date(2026, 8, 10, 10))],
                knownAccountIDs: [accountID],
                now: date(2026, 8, 10, 10),
                calendar: calendar
            )
            XCTFail("expected injected writer failure")
        } catch TestError.writeFailed {
            // Expected.
        }

        let current = await store.currentDocument()
        let diskAfterFailure = try Data(contentsOf: store.fileURL)
        XCTAssertEqual(current, committed)
        XCTAssertEqual(diskAfterFailure, diskBeforeFailure)
        XCTAssertTrue(current.dailyRecords.isEmpty)
    }

    func testSchemaV1FixtureLoadsWithoutChangingDailyAmounts() async throws {
        try writeFixture("usage-history-v1.json")
        let store = UsageHistoryStore(directory: directory)

        let result = try await store.load()

        XCTAssertEqual(result.health, .available)
        XCTAssertNil(result.recovery)
        XCTAssertEqual(result.document.schemaVersion, UsageHistoryDocument.currentSchemaVersion)
        XCTAssertEqual(result.document.dailyRecords.count, 2)
        XCTAssertEqual(result.document.dailyRecords.first { $0.unit == "CNY" }?.estimatedAmount, 3.5)
        XCTAssertEqual(result.document.dailyRecords.first { $0.unit == "USD" }?.providerAmount, 1.25)
        XCTAssertEqual(Set(result.document.dailyRecords.map(\.unit)), ["CNY", "USD"])
    }

    func testFourHundredDayTrimDoesNotChangeKeptAmounts() async throws {
        try writeFixture("usage-history-v1.json")
        let store = UsageHistoryStore(directory: directory)
        var document = try await store.load().document
        let now = date(2026, 8, 10, 9)
        let oldestKeptDate = calendar.date(byAdding: .day, value: -399, to: calendar.startOfDay(for: now))!
        let expiredDate = calendar.date(byAdding: .day, value: -400, to: calendar.startOfDay(for: now))!
        document.dailyRecords.append(contentsOf: [
            UsageDailyRecord(
                dayKey: dayKey(oldestKeptDate),
                timeZoneIdentifier: "Asia/Shanghai",
                accountId: accountID,
                providerKind: .deepseek,
                unit: "CNY",
                providerAmount: 0,
                estimatedAmount: 9,
                sampleCount: 1,
                hasBoundaryGap: false
            ),
            UsageDailyRecord(
                dayKey: dayKey(expiredDate),
                timeZoneIdentifier: "Asia/Shanghai",
                accountId: accountID,
                providerKind: .deepseek,
                unit: "CNY",
                providerAmount: 0,
                estimatedAmount: 99,
                sampleCount: 1,
                hasBoundaryGap: false
            ),
        ])
        try await store.replaceDocument(document)

        let next = try await store.record(
            snapshots: [],
            knownAccountIDs: [accountID],
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(next.dailyRecords.contains { $0.dayKey == dayKey(expiredDate) })
        XCTAssertEqual(
            next.dailyRecords.first { $0.dayKey == dayKey(oldestKeptDate) }?.estimatedAmount,
            9
        )
        XCTAssertEqual(
            next.dailyRecords.first { $0.dayKey == "2026-08-10" }?.estimatedAmount,
            3.5
        )
    }

    func testUnknownUnitIsPreservedAndNotConverted() async throws {
        try writeFixture("usage-history-unknown-unit.json")
        let store = UsageHistoryStore(directory: directory)
        let loaded = try await store.load().document

        XCTAssertEqual(loaded.dailyRecords.map(\.unit), ["TOKENS"])
        XCTAssertEqual(loaded.baselines.map(\.unit), ["TOKENS"])
        XCTAssertEqual(loaded.dailyRecords.first?.estimatedAmount, 20)

        let summary = UsageSummaryBuilder.build(
            document: loaded,
            period: .day,
            anchor: date(2026, 8, 10, 12),
            calendar: calendar
        )
        XCTAssertEqual(summary.currencies.map(\.unit), ["TOKENS"])
        XCTAssertEqual(summary.currencies.first?.totalAmount, 20)
        XCTAssertFalse(summary.currencies.contains { $0.unit == "CNY" || $0.unit == "USD" })
    }

    func testCorruptUsageFixtureBacksUpAndReturnsHealthWarning() async throws {
        try writeFixture("corrupt-usage-history.json", as: "usage-history.json")
        let store = UsageHistoryStore(directory: directory)

        let result = try await store.load()
        let filenames = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).map(\.lastPathComponent)

        XCTAssertEqual(result.document, UsageHistoryDocument())
        XCTAssertEqual(result.recovery, .corruptFileBackedUp)
        XCTAssertEqual(result.health, .needsRestore)
        XCTAssertEqual(result.health.messageKey, "usage.health.needs_restore")
        XCTAssertTrue(result.health.isUserVisibleWarning)
        XCTAssertTrue(filenames.contains { $0.hasPrefix("usage-history.corrupt-") && $0.hasSuffix(".json") })
    }

    func testCancelledRecordDoesNotWriteHistory() async throws {
        let store = UsageHistoryStore(directory: directory)
        let gate = CancellationGate()
        let now = date(2026, 8, 10, 9)
        let sample = snapshot(amount: 100, fetchedAt: now)
        let accountID = accountID
        let calendar = calendar
        let task = Task {
            await gate.wait()
            return try await store.record(
                snapshots: [sample],
                knownAccountIDs: [accountID],
                now: now,
                calendar: calendar
            )
        }

        while !(await gate.hasWaiter) {
            await Task.yield()
        }
        task.cancel()
        await gate.release()

        do {
            _ = try await task.value
            XCTFail("cancelled record must not write")
        } catch is CancellationError {
            // Expected.
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func snapshot(amount: Double, fetchedAt: Date) -> BalanceSnapshot {
        BalanceSnapshot(
            accountId: accountID,
            providerKind: .deepseek,
            displayName: "DeepSeek",
            amount: amount,
            unit: "¥",
            status: .healthy,
            fetchedAt: fetchedAt
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    private func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func writeFixture(_ name: String, as filename: String = "usage-history.json") throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/CommonCapabilities/\(name)")
        try Data(contentsOf: source).write(to: directory.appendingPathComponent(filename))
    }
}

private actor CancellationGate {
    private var continuation: CheckedContinuation<Void, Never>?

    var hasWaiter: Bool { continuation != nil }

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

private enum TestError: Error {
    case writeFailed
}

private final class WriterProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var concurrentWrites = 0
    private var maximum = 0

    var maximumConcurrentWrites: Int {
        lock.withLock { maximum }
    }

    func write(_ data: Data, _ url: URL) throws {
        lock.withLock {
            concurrentWrites += 1
            maximum = max(maximum, concurrentWrites)
        }
        defer {
            lock.withLock { concurrentWrites -= 1 }
        }
        usleep(10_000)
        try data.write(to: url, options: .atomic)
    }
}

private final class FailAfterFirstWriter: @unchecked Sendable {
    private let lock = NSLock()
    private var writes = 0

    func write(_ data: Data, _ url: URL) throws {
        let shouldFail = lock.withLock {
            writes += 1
            return writes > 1
        }
        if shouldFail { throw TestError.writeFailed }
        try data.write(to: url, options: .atomic)
    }
}
