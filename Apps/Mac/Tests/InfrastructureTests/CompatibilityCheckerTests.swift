import XCTest
@testable import Domain
@testable import Infrastructure

final class CompatibilityCheckerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-Compat-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testUnsupportedMacOSReturnsFailedStatusAndStableMessageKey() {
        let report = CompatibilityChecker().evaluate(
            makeContext(macOSMajor: 14, macOSMinor: 6, macOSPatch: 1)
        )
        let check = check(report, .macos)
        XCTAssertEqual(check.status, .failed)
        XCTAssertEqual(check.messageKey, "compat.macos.unsupported")
        XCTAssertTrue(report.hasBlockingIssue)
    }

    func testUnwritableDirectoriesReturnFailedStatusAndStableMessageKeys() {
        let report = CompatibilityChecker().evaluate(
            makeContext(isApplicationSupportWritable: false, isLogsWritable: false)
        )
        XCTAssertEqual(check(report, .applicationSupport).status, .failed)
        XCTAssertEqual(check(report, .applicationSupport).messageKey, "compat.appSupport.unwritable")
        XCTAssertEqual(check(report, .logs).status, .failed)
        XCTAssertEqual(check(report, .logs).messageKey, "compat.logs.unwritable")
        XCTAssertTrue(report.hasBlockingIssue)
    }

    func testUnavailableKeychainReturnsFailedStatusAndStableMessageKey() {
        let report = CompatibilityChecker().evaluate(makeContext(keychainAvailable: false))
        let check = check(report, .keychain)
        XCTAssertEqual(check.status, .failed)
        XCTAssertEqual(check.messageKey, "compat.keychain.unavailable")
        XCTAssertTrue(report.hasBlockingIssue)
    }

    func testNotificationNotDeterminedIsWarningNotChannelFailure() {
        let report = CompatibilityChecker().evaluate(
            makeContext(notificationAuthorization: .notDetermined)
        )
        let check = check(report, .notifications)
        XCTAssertEqual(check.status, .warning)
        XCTAssertEqual(check.messageKey, "compat.notifications.notDetermined")
        XCTAssertFalse(report.hasBlockingIssue)
        XCTAssertNotEqual(check.status, .failed)
    }

    func testCorruptSettingsReturnsFailedStatusAndStableMessageKey() throws {
        let settingsURL = directory.appendingPathComponent("settings.json")
        try Data(contentsOf: fixture("corrupt-settings.json")).write(to: settingsURL)

        let report = CompatibilityChecker().evaluate(makeContext(settingsFileURL: settingsURL))
        let check = check(report, .settings)
        XCTAssertEqual(check.status, .failed)
        XCTAssertEqual(check.messageKey, "compat.settings.corrupt")
        XCTAssertTrue(report.hasBlockingIssue)
    }

    func testMissingUsageHistoryReturnsStableStatusAndLocalizedMessageKey() {
        let usageURL = directory.appendingPathComponent("usage-history.json")
        let report = CompatibilityChecker().evaluate(makeContext(usageHistoryFileURL: usageURL))
        let check = check(report, .usageHistory)
        XCTAssertEqual(check.status, .ok)
        XCTAssertEqual(check.messageKey, "compat.usage.missing")
        XCTAssertFalse(report.hasBlockingIssue)
    }

    func testArchitectureAndCurrentSchemaAreReportedWithStableKeys() throws {
        let settingsURL = directory.appendingPathComponent("settings.json")
        let document = SettingsDocument(settings: AppSettings())
        try SettingsDocument.encode(document).write(to: settingsURL)

        let apple = CompatibilityChecker().evaluate(
            makeContext(architecture: .appleSilicon, settingsFileURL: settingsURL)
        )
        XCTAssertEqual(check(apple, .architecture).status, .ok)
        XCTAssertEqual(check(apple, .architecture).messageKey, "compat.architecture.appleSilicon")
        XCTAssertEqual(check(apple, .schema).status, .ok)
        XCTAssertEqual(check(apple, .schema).messageKey, "compat.schema.ok")
        XCTAssertEqual(apple.architecture, CompatibilityArchitecture.appleSilicon.rawValue)

        let intel = CompatibilityChecker().evaluate(
            makeContext(architecture: .intel, settingsFileURL: settingsURL)
        )
        XCTAssertEqual(check(intel, .architecture).messageKey, "compat.architecture.intel")
        XCTAssertEqual(intel.architecture, CompatibilityArchitecture.intel.rawValue)
    }

    func testUnsupportedSettingsSchemaReturnsFailedStatusAndStableMessageKey() throws {
        let settingsURL = directory.appendingPathComponent("settings.json")
        let json = """
        {
          "schemaVersion": 99,
          "updatedAt": "2026-08-14T00:00:00Z",
          "settings": { "accounts": [] },
          "extensions": {}
        }
        """
        try Data(json.utf8).write(to: settingsURL)

        let report = CompatibilityChecker().evaluate(makeContext(settingsFileURL: settingsURL))
        XCTAssertEqual(check(report, .schema).status, .failed)
        XCTAssertEqual(check(report, .schema).messageKey, "compat.schema.unsupported")
        XCTAssertTrue(report.hasBlockingIssue)
    }

    func testReportAlwaysIncludesStableCheckIdentifiers() {
        let ids = CompatibilityChecker().evaluate(makeContext()).checks.map(\.id)
        XCTAssertEqual(ids, CompatibilityCheckID.allCases.map(\.rawValue))
    }

    private func check(_ report: CompatibilityReport, _ id: CompatibilityCheckID) -> CompatibilityCheck {
        report.checks.first { $0.id == id.rawValue } ?? CompatibilityCheck(
            id: "missing",
            status: .unknown,
            messageKey: "missing"
        )
    }

    private func makeContext(
        macOSMajor: Int = 15,
        macOSMinor: Int = 0,
        macOSPatch: Int = 0,
        architecture: CompatibilityArchitecture = .appleSilicon,
        isApplicationSupportWritable: Bool = true,
        isLogsWritable: Bool = true,
        keychainAvailable: Bool = true,
        notificationAuthorization: NotificationAuthorizationState = .authorized,
        settingsFileURL: URL? = nil,
        usageHistoryFileURL: URL? = nil
    ) -> CompatibilityContext {
        CompatibilityContext(
            now: date(2026, 8, 14, 12, 0, 0),
            macOSMajor: macOSMajor,
            macOSMinor: macOSMinor,
            macOSPatch: macOSPatch,
            minimumMacOSMajor: 15,
            minimumMacOSMinor: 0,
            minimumMacOSPatch: 0,
            architecture: architecture,
            applicationSupportDirectory: directory,
            logsDirectory: directory.appendingPathComponent("logs", isDirectory: true),
            isApplicationSupportWritable: isApplicationSupportWritable,
            isLogsWritable: isLogsWritable,
            settingsFileURL: settingsFileURL ?? directory.appendingPathComponent("settings.json"),
            usageHistoryFileURL: usageHistoryFileURL ?? directory.appendingPathComponent("usage-history.json"),
            keychainAvailable: keychainAvailable,
            notificationAuthorization: notificationAuthorization,
            currentSettingsSchemaVersion: SettingsDocument.currentSchemaVersion
        )
    }

    private func fixture(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/CommonCapabilities/\(name)")
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
