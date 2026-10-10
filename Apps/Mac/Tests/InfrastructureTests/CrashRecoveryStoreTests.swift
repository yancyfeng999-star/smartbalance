import XCTest
@testable import Domain
@testable import Infrastructure

final class CrashRecoveryStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-CrashRecovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testNormalStartAndExplicitQuitDoNotEnterSafeMode() throws {
        let store = CrashRecoveryStore(directory: directory)
        let first = store.beginSession()
        XCTAssertFalse(first.decision.enterSafeMode)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.markerURL.path))
        XCTAssertEqual(posixPermissions(at: store.markerURL), 0o600)

        store.markSessionHealthy()
        store.markCleanQuit()

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.markerURL.path))
        let second = CrashRecoveryStore(directory: directory).beginSession()
        XCTAssertFalse(second.decision.enterSafeMode)
        XCTAssertEqual(second.decision.consecutiveUncleanExits, 0)
        XCTAssertEqual(second.route(firstLaunch: .home), .home)
    }

    func testUncleanMarkersAtThresholdEnterSafeMode() throws {
        try leaveUncleanMarker()
        let afterOneStore = CrashRecoveryStore(directory: directory)
        let afterOne = afterOneStore.beginSession()
        XCTAssertFalse(afterOne.decision.enterSafeMode)
        XCTAssertEqual(afterOne.decision.consecutiveUncleanExits, 1)
        afterOneStore.handleLifecycle(.forceKill)

        let afterTwo = CrashRecoveryStore(directory: directory).beginSession()
        XCTAssertTrue(afterTwo.decision.enterSafeMode)
        XCTAssertEqual(afterTwo.decision.consecutiveUncleanExits, RecoveryLimits.uncleanMarkerThreshold)
        XCTAssertTrue(afterTwo.decision.reasons.contains(.consecutiveUncleanExits))
        XCTAssertEqual(afterTwo.route(firstLaunch: .home), .safeMode)
        XCTAssertEqual(afterTwo.route(firstLaunch: .onboarding), .safeMode)
    }

    func testContinueClearsOnlyCurrentMarkerAndPreservesDiagnostics() throws {
        let outcomes = DiagnosticOutcomeStore(directory: directory)
        outcomes.record(.restore, result: .failed, at: Date(timeIntervalSince1970: 1_787_000_000))
        try leaveUncleanMarker()
        try leaveUncleanMarker()

        let store = CrashRecoveryStore(directory: directory)
        let started = store.beginSession()
        XCTAssertTrue(started.decision.enterSafeMode)

        let continued = store.continueNormalStart()
        XCTAssertTrue(continued.continuedThisSession)
        XCTAssertFalse(continued.enterSafeMode)
        XCTAssertEqual(store.route(decision: continued, firstLaunch: .home), .home)
        XCTAssertEqual(store.loadLedger().consecutiveUncleanExits, RecoveryLimits.uncleanMarkerThreshold)
        XCTAssertEqual(outcomes.load().restore.result, .failed)
        XCTAssertEqual(outcomes.load().restore.at, Date(timeIntervalSince1970: 1_787_000_000))
        XCTAssertEqual(store.loadMarker()?.phase, .healthy)
        XCTAssertEqual(store.loadMarker()?.continuedFromSafeMode, true)
    }

    func testWindowHideDoesNotClearMarkerOrCountAsQuit() throws {
        let store = CrashRecoveryStore(directory: directory)
        _ = store.beginSession()
        store.markSessionHealthy()
        let before = try Data(contentsOf: store.markerURL)

        store.handleLifecycle(.windowHidden)

        XCTAssertEqual(try Data(contentsOf: store.markerURL), before)
        XCTAssertEqual(store.loadMarker()?.phase, .healthy)
        XCTAssertEqual(store.loadLedger().consecutiveUncleanExits, 0)
    }

    func testForceKillLeavesMarkerForNextLaunch() throws {
        let store = CrashRecoveryStore(directory: directory)
        _ = store.beginSession()
        store.markSessionHealthy()
        store.handleLifecycle(.forceKill)

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.markerURL.path))
        XCTAssertNotEqual(store.loadMarker()?.phase, .quitting)

        let next = CrashRecoveryStore(directory: directory).beginSession()
        XCTAssertEqual(next.decision.consecutiveUncleanExits, 1)
    }

    func testCorruptSettingsEnterSafeModeWithoutWaitingForCrashThreshold() throws {
        try Data("{".utf8).write(to: directory.appendingPathComponent("settings.json"))
        let store = CrashRecoveryStore(directory: directory)
        let started = store.beginSession()
        XCTAssertTrue(started.decision.enterSafeMode)
        XCTAssertTrue(started.decision.reasons.contains(.settingsCorrupt))
        XCTAssertEqual(started.route(firstLaunch: .home), .safeMode)
    }

    func testInterruptedUpdateMarkerEntersSafeMode() throws {
        try PackageSilentInstaller.writeUpdateInProgressMarker(
            directory: directory,
            destinationApp: URL(fileURLWithPath: "/tmp/Zhiyu.app")
        )
        let store = CrashRecoveryStore(directory: directory)
        let started = store.beginSession()
        XCTAssertTrue(started.decision.enterSafeMode)
        XCTAssertTrue(started.decision.reasons.contains(.interruptedUpdate))

        _ = store.continueNormalStart()
        XCTAssertFalse(PackageSilentInstaller.updateInProgressMarkerExists(in: directory))
    }

    func testQuittingPhaseMarkerIsNotUnclean() throws {
        let store = CrashRecoveryStore(directory: directory)
        _ = store.beginSession()
        store.handleLifecycle(.explicitQuit)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.markerURL.path))

        let next = CrashRecoveryStore(directory: directory).beginSession()
        XCTAssertFalse(next.decision.enterSafeMode)
        XCTAssertEqual(next.decision.consecutiveUncleanExits, 0)
    }

    private func leaveUncleanMarker() throws {
        let store = CrashRecoveryStore(directory: directory)
        _ = store.beginSession()
        store.markSessionHealthy()
        store.handleLifecycle(.forceKill)
    }

    private func posixPermissions(at url: URL) -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let value = attributes?[.posixPermissions] as? NSNumber
        return (value?.intValue ?? 0) & 0o777
    }
}
