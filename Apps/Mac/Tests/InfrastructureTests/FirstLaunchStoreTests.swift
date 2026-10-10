import XCTest
@testable import Domain
@testable import Infrastructure

final class FirstLaunchStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-FirstLaunch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testMissingStateFileIsTreatedAsFirstRun() {
        let store = FirstLaunchStore(directory: directory)
        XCTAssertEqual(store.load(), .missing)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testCompletedStateReloadsAndUsesOwnerOnlyPermissions() throws {
        let store = FirstLaunchStore(directory: directory)
        let completedAt = date(2026, 8, 14, 9, 30, 0)
        let state = FirstLaunchState(
            schemaVersion: FirstLaunchState.currentSchemaVersion,
            completedAt: completedAt,
            acknowledgedPrivacy: true,
            lastCompatibilityReport: nil
        )

        try store.save(state)

        XCTAssertEqual(posixPermissions(at: store.fileURL), 0o600)
        let loaded = store.load()
        guard case .loaded(let restored) = loaded else {
            return XCTFail("expected loaded first-launch state, got \(loaded)")
        }
        XCTAssertEqual(restored.schemaVersion, FirstLaunchState.currentSchemaVersion)
        XCTAssertEqual(restored.completedAt, completedAt)
        XCTAssertTrue(restored.acknowledgedPrivacy)
        XCTAssertTrue(restored.isCompleted)
    }

    func testCorruptStateDoesNotWipeSettingsFile() throws {
        let store = FirstLaunchStore(directory: directory)
        let settingsURL = directory.appendingPathComponent("settings.json")
        let settingsData = Data("{\"accounts\":[{\"id\":\"11111111-1111-4111-8111-111111111111\"}]}".utf8)
        try settingsData.write(to: settingsURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settingsURL.path)

        try Data("{".utf8).write(to: store.fileURL)

        XCTAssertEqual(store.load(), .corrupt)
        XCTAssertEqual(try Data(contentsOf: settingsURL), settingsData)
        XCTAssertEqual(posixPermissions(at: settingsURL), 0o600)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testSaveDoesNotWriteOnboardingFlagsIntoSettingsJSON() throws {
        let store = FirstLaunchStore(directory: directory)
        try store.save(
            FirstLaunchState(
                completedAt: date(2026, 8, 14, 10, 0, 0),
                acknowledgedPrivacy: true
            )
        )

        let settingsURL = directory.appendingPathComponent("settings.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: settingsURL.path))
        let text = try String(contentsOf: store.fileURL, encoding: .utf8)
        XCTAssertFalse(text.contains("accounts"))
        XCTAssertTrue(text.contains("acknowledgedPrivacy"))
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
