import XCTest
@testable import Domain
@testable import Infrastructure

final class AppLogDiagnosticsTests: XCTestCase {
    private var directory: URL!
    private var previousOverride: URL?

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-AppLog-\(UUID().uuidString)", isDirectory: true)
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

    func testErrorLinesIncludeUnifiedCategoryAndDoNotKeepRawSecrets() throws {
        AppLog.error(
            "smtpPassword: SuperFakeSMTP-Pass-0001 api_key=sk-test-fake-api-key-1234567890ABCDEF",
            category: .smtp,
            event: "smtp_send_failed"
        )
        AppLog.flushForTests()
        let text = try String(contentsOf: AppLog.fileURL, encoding: .utf8)
        XCTAssertTrue(text.contains("[ERROR]"), text)
        XCTAssertTrue(text.contains("[smtp]"), text)
        XCTAssertTrue(text.contains("event=smtp_send_failed"), text)
        XCTAssertFalse(text.contains("SuperFakeSMTP-Pass-0001"), text)
        XCTAssertFalse(text.contains("sk-test-fake-api-key-1234567890ABCDEF"), text)
    }

    func testRotationRunsOffTheCallingThread() throws {
        let calling = Thread.current
        let box = ThreadBox()
        let done = expectation(description: "log-io")
        AppLog.fileIOThreadObserverForTests = {
            box.thread = Thread.current
            done.fulfill()
        }
        AppLog.maxFileSizeBytesOverride = 200
        try Data(repeating: 0x61, count: 240).write(to: AppLog.fileURL)
        AppLog.info("force-rotate-off-caller")
        wait(for: [done], timeout: 2)
        AppLog.flushForTests()
        XCTAssertNotNil(box.thread)
        XCTAssertFalse(box.thread === calling, "rotation/write must leave the caller thread")
        AppLog.fileIOThreadObserverForTests = nil
    }

    func testRotatesWhenFileExceedsSizeAndKeepsFixedRotatedCount() throws {
        AppLog.maxFileSizeBytesOverride = 800
        AppLog.maxRotatedFilesOverride = 2
        for index in 0..<80 {
            AppLog.info("rotation-probe-\(index) filler-abcdefghijklmnopqrstuvwxyz")
        }
        AppLog.flushForTests()

        XCTAssertTrue(FileManager.default.fileExists(atPath: AppLog.fileURL.path))
        let rotated1 = directory.appendingPathComponent("app.log.1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: rotated1.path))
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("app.log") }
            .sorted()
        XCTAssertLessThanOrEqual(names.filter { $0 != "app.log" }.count, 2, "\(names)")
        XCTAssertFalse(names.contains("app.log.3"))
    }

    func testTailLinesReadsOnlyRecentCapWithoutRequiringFullFileInResult() throws {
        var payload = ""
        for index in 1...300 {
            payload += "keep-line-\(index)\n"
        }
        try payload.write(to: AppLog.fileURL, atomically: true, encoding: .utf8)

        let lines = AppLog.tailLines(maxLines: 15, maxBytes: 64 * 1024)
        XCTAssertEqual(lines.count, 15)
        XCTAssertTrue(lines.last?.contains("keep-line-300") == true)
        XCTAssertFalse(lines.contains(where: { $0.contains("keep-line-1") }))
    }

    func testFailedDiagnosticWriteLeavesCurrentLogInPlace() throws {
        AppLog.info("original-log-must-remain")
        AppLog.flushForTests()
        let before = try Data(contentsOf: AppLog.fileURL)

        let blocked = directory.appendingPathComponent("not-a-dir")
        try Data("x".utf8).write(to: blocked)
        XCTAssertThrowsError(
            try DiagnosticArchiveWriter().writeText(
                DiagnosticsService().collect(
                    DiagnosticsContext(
                        now: Date(),
                        appVersion: "0.3.1",
                        build: "82",
                        osVersion: "15.0.0",
                        architecture: "appleSilicon",
                        launchMode: .menuBar,
                        applicationSupport: DiagnosticDirectoryProbe(writable: true),
                        logs: DiagnosticDirectoryProbe(writable: true),
                        temporary: DiagnosticDirectoryProbe(writable: true),
                        settingsReadable: true,
                        settingsSchemaSupported: true,
                        usageHistoryReadable: true,
                        lastMigrationResult: "none",
                        lastBackupResult: "none",
                        lastRestoreResult: "none",
                        keychainStatus: .unknown,
                        notificationAuthorization: .unknown,
                        refresh: DiagnosticRefreshSummary(state: "idle"),
                        providers: [],
                        usage: DiagnosticUsageSummary(recordCount: 0),
                        logFileURL: AppLog.fileURL
                    )
                ),
                to: blocked.appendingPathComponent("summary.txt")
            )
        )
        XCTAssertEqual(try Data(contentsOf: AppLog.fileURL), before)
    }
}

private final class ThreadBox: @unchecked Sendable {
    var thread: Thread?
}
