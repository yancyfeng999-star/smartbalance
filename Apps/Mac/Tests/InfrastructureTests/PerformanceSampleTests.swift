import XCTest
@testable import Domain
@testable import Infrastructure

final class PerformanceSampleTests: XCTestCase {
    private var directory: URL!
    private var previousOverride: URL?

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-PerfLog-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        previousOverride = AppLog.directoryOverride
        AppLog.directoryOverride = directory
        AppLog.resetForTests()
    }

    override func tearDownWithError() throws {
        AppLog.flushForTests()
        AppLog.directoryOverride = previousOverride
        AppLog.resetForTests()
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testRecordsDurationSuccessFailureAndCancelWithoutSensitiveFields() {
        let sample = PerformanceSample()
        sample.record(duration: 0.12, result: .success, accountSuccesses: 3, accountFailures: 0)
        sample.record(duration: 0.40, result: .failure, accountSuccesses: 0, accountFailures: 2)
        sample.record(duration: 0.05, result: .cancel)
        sample.recordConcurrency(3)
        sample.recordConcurrency(4)

        let counters = sample.snapshot()
        XCTAssertEqual(counters.successCount, 1)
        XCTAssertEqual(counters.failureCount, 1)
        XCTAssertEqual(counters.cancelCount, 1)
        XCTAssertEqual(counters.accountSuccessCount, 3)
        XCTAssertEqual(counters.accountFailureCount, 2)
        XCTAssertEqual(counters.sampleCount, 3)
        XCTAssertEqual(counters.peakConcurrency, 4)
        XCTAssertEqual(counters.lastDuration, 0.05, accuracy: 0.000_1)
        XCTAssertEqual(counters.totalDuration, 0.57, accuracy: 0.000_1)

        let names = sample.debugFieldNames()
        XCTAssertFalse(names.contains(where: { $0.lowercased().contains("url") }))
        XCTAssertFalse(names.contains(where: { $0.lowercased().contains("body") }))
        XCTAssertFalse(names.contains(where: { $0.lowercased().contains("keychain") }))
        XCTAssertFalse(names.contains(where: { $0.lowercased().contains("credential") }))
        let dump = sample.debugDescriptionText().lowercased()
        XCTAssertFalse(dump.contains("http"))
        XCTAssertFalse(dump.contains("bearer"))
        XCTAssertFalse(dump.contains("cookie"))
        XCTAssertFalse(dump.contains("password"))
        XCTAssertFalse(dump.contains("sk-"))
    }

    func testLogRotationKeepsRecentFilesWithCorrectPermissions() throws {
        AppLog.maxFileSizeBytesOverride = 400
        AppLog.maxRotatedFilesOverride = 2
        for index in 0..<60 {
            AppLog.info("rotate-permission-\(index) filler-abcdefghijklmnopqrstuvwxyz")
        }
        AppLog.flushForTests()

        XCTAssertTrue(FileManager.default.fileExists(atPath: AppLog.fileURL.path))
        let rotated1 = directory.appendingPathComponent("app.log.1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: rotated1.path))
        XCTAssertEqual(posixPermissions(at: AppLog.fileURL), 0o600)
        XCTAssertEqual(posixPermissions(at: rotated1), 0o600)

        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("app.log") }
            .sorted()
        XCTAssertLessThanOrEqual(names.filter { $0 != "app.log" }.count, 2)
        XCTAssertTrue(names.contains("app.log.1"))
        XCTAssertFalse(names.contains("app.log.3"))
    }

    func testLogWriteFailureDoesNotBlockRefresh() async {
        AppLog.writeShouldFailForTests = true
        let started = Date()
        AppLog.info("forced-write-failure")
        AppLog.flushForTests()
        let writeReturnMs = Date().timeIntervalSince(started) * 1_000
        XCTAssertLessThan(writeReturnMs, 200, "failed log write must not stall the caller")
        XCTAssertFalse(FileManager.default.fileExists(atPath: AppLog.fileURL.path))

        let clock = ControllableRefreshClock(Date(timeIntervalSince1970: 1_787_000_000))
        let account = BalanceAccount(
            id: UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!,
            kind: .deepseek,
            displayName: "Perf"
        )
        let coordinator = await MainActor.run {
            RefreshCoordinator(
                clock: clock,
                fetcher: ImmediateRefreshFetcher(accountID: account.id),
                metrics: PerformanceSample()
            )
        }
        let admission = await MainActor.run {
            coordinator.request(
                .init(trigger: .manual),
                settings: AppSettings(accounts: [account])
            )
        }
        XCTAssertEqual(admission, .started)
        let outcome = await coordinator.waitForCompletion()
        XCTAssertEqual(outcome?.succeededCount, 1)
        XCTAssertEqual(outcome?.snapshots.first?.amount, 8)
    }

    func testMainThreadLifecycleAndLogWriteStayBounded() async {
        let clock = ControllableRefreshClock(Date(timeIntervalSince1970: 1_787_000_000))
        let scheduler = await MainActor.run { ControllableRefreshScheduler(clock: clock) }
        let lifecycle = await MainActor.run {
            RefreshLifecycleCoordinator(
                clock: clock,
                scheduler: scheduler,
                allowsRefresh: true,
                intervalSecs: 900
            )
        }

        let handleStarted = Date()
        await MainActor.run {
            lifecycle.handle(.didWake)
            lifecycle.handle(.menuAppear)
            lifecycle.handle(.pageSwitch)
            lifecycle.handle(.notificationStateChange)
        }
        let handleMs = Date().timeIntervalSince(handleStarted) * 1_000
        XCTAssertLessThan(handleMs, 50, "lifecycle events must stay off heavy IO")

        let logStarted = Date()
        AppLog.info("menu-open-must-not-read-full-log")
        let logMs = Date().timeIntervalSince(logStarted) * 1_000
        AppLog.flushForTests()
        XCTAssertLessThan(logMs, 50, "AppLog.write must return before file IO")
    }

    private func posixPermissions(at url: URL) -> Int {
        let value = try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        return value?.intValue ?? -1
    }
}

private struct ImmediateRefreshFetcher: RefreshBalanceFetching {
    let accountID: UUID

    func fetchBalances(
        accounts: [BalanceAccount],
        settings: AppSettings
    ) async -> RefreshFetchPayload {
        RefreshFetchPayload(
            snapshots: [
                BalanceSnapshot(
                    accountId: accountID,
                    providerKind: .deepseek,
                    displayName: "Perf",
                    amount: 8,
                    unit: "¥",
                    status: .healthy
                ),
            ]
        )
    }
}
