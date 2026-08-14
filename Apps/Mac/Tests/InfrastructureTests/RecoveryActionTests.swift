import XCTest
@testable import Domain
@testable import Infrastructure

final class RecoveryActionTests: XCTestCase {
    private let accountID = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartBalance-RecoveryAction-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    func testSafeModeDoesNotInvokeRefreshNotificationSMTOrProvider() throws {
        let recorder = RecoverySideEffectRecorder()
        RecoverySafeModeLaunch.perform(route: .safeMode, effects: recorder)
        XCTAssertEqual(recorder.refreshStarts, 0)
        XCTAssertEqual(recorder.notificationAuthorizations, 0)
        XCTAssertEqual(recorder.notificationDeliveries, 0)
        XCTAssertEqual(recorder.smtpSends, 0)
        XCTAssertEqual(recorder.providerCredentialReads, 0)
        XCTAssertEqual(recorder.updateInstalls, 0)

        RecoverySafeModeLaunch.perform(route: .home, effects: recorder)
        XCTAssertEqual(recorder.refreshStarts, 1)
        XCTAssertEqual(recorder.notificationAuthorizations, 1)
        XCTAssertEqual(recorder.smtpSends, 1)
        XCTAssertEqual(recorder.providerCredentialReads, 1)
        XCTAssertEqual(recorder.updateInstalls, 1)
    }

    func testResetCreatesSnapshotFirstAndDoesNotDeleteKeychain() async throws {
        let env = try await seedOriginals()
        let secret = LocalSecretStore()
        let secretAccount = "recovery.reset.\(UUID().uuidString)"
        try secret.set("keep-this-secret", account: secretAccount)
        defer { secret.delete(account: secretAccount) }

        let beforeSnapshots = try snapshotFiles()
        let outcome = try await env.store.resetSettings(includeUsageHistory: true)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.keychainEntriesDeleted, 0)
        XCTAssertFalse(RecoveryResetPolicy.deletesKeychainEntries)
        XCTAssertNotNil(outcome.settingsSnapshotURL)
        XCTAssertTrue(try snapshotFiles().count > beforeSnapshots.count)
        XCTAssertTrue(
            try snapshotFiles().contains { $0.lastPathComponent.contains(RecoveryResetPolicy.snapshotReason) }
        )
        XCTAssertEqual(secret.get(account: secretAccount), "keep-this-secret")
        XCTAssertTrue(env.settingsStore.load().accounts.isEmpty)
        let usage = try await env.usageStore.reloadFromDisk().document
        XCTAssertTrue(usage.dailyRecords.isEmpty)
        XCTAssertTrue(usage.baselines.isEmpty)
    }

    func testRestoreValidationFailureKeepsOriginalFileHashes() async throws {
        let env = try await seedOriginals()
        let settingsHash = try SHA256Verifier.hexDigest(ofFile: env.settingsStore.fileURL)
        let usageHash = try SHA256Verifier.hexDigest(ofFile: env.usageStore.fileURL)
        let snapshot = try BackupManager(directory: directory).createSnapshot(
            of: env.settingsStore.fileURL,
            reason: "tamper"
        )
        try Data("not-json".utf8).write(to: snapshot.url)

        let outcome = await env.store.restoreLatestSnapshot(includeUsage: true)

        XCTAssertEqual(outcome.status, .failed)
        XCTAssertEqual(outcome.failureReason, .validationFailed)
        XCTAssertEqual(try SHA256Verifier.hexDigest(ofFile: env.settingsStore.fileURL), settingsHash)
        XCTAssertEqual(try SHA256Verifier.hexDigest(ofFile: env.usageStore.fileURL), usageHash)
        XCTAssertEqual(env.settingsStore.load().accounts.first?.displayName, "Original")
        XCTAssertEqual(env.store.currentRoute(firstLaunch: .home), .safeMode)
    }

    func testRestoreSuccessAllowsHomeAfterContinue() async throws {
        let env = try await seedOriginals()
        let backup = BackupManager(directory: directory)
        _ = try backup.createSnapshot(of: env.settingsStore.fileURL, reason: "settings-write")

        let incoming = AppSettings(accounts: [
            BalanceAccount(id: accountID, kind: .kimi, displayName: "Should Be Replaced", secretRef: "new"),
        ], themeMode: "light")
        try env.settingsStore.save(incoming)
        XCTAssertEqual(env.settingsStore.load().accounts.first?.displayName, "Should Be Replaced")

        let outcome = await env.store.restoreLatestSnapshot(includeUsage: false)
        XCTAssertEqual(outcome.status, .succeeded)
        XCTAssertEqual(env.settingsStore.load().accounts.first?.displayName, "Original")
        XCTAssertEqual(env.store.currentRoute(firstLaunch: .home), .safeMode)

        let continued = env.store.continueNormalStart()
        XCTAssertEqual(env.store.route(decision: continued, firstLaunch: .home), .home)
    }

    func testExportIsNonSensitive() throws {
        let store = SettingsStore(directory: directory)
        try store.save(AppSettings(accounts: [
            BalanceAccount(id: accountID, kind: .deepseek, displayName: "DS", secretRef: "secret-ref-value"),
        ]))
        let recovery = CrashRecoveryStore(directory: directory)
        _ = recovery.beginSession()
        let dest = directory.appendingPathComponent("export.json")
        try recovery.exportNonSensitiveSettings(to: dest, appVersion: "0.3.1")
        let text = try String(contentsOf: dest, encoding: .utf8)
        XCTAssertFalse(text.contains("secret-ref-value"))
        XCTAssertFalse(text.contains("\"secrets\""))
        XCTAssertTrue(text.contains("smartbalance.portable-settings") || text.contains("DS"))
    }

    func testPackageScheduleWritesUpdateMarkerAndValidationFailureDoesNot() throws {
        let pkg = directory.appendingPathComponent("bad.pkg")
        try Data("pkg".utf8).write(to: pkg)
        let app = directory.appendingPathComponent("智余.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        let info = app.appendingPathComponent("Contents/Info.plist")
        try FileManager.default.createDirectory(at: info.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("<plist/>".utf8).write(to: info)

        XCTAssertThrowsError(
            try PackageSilentInstaller.scheduleReplace(
                pkgURL: pkg,
                destinationApp: app,
                candidate: UpdateCandidate(
                    currentVersion: "1.0.0",
                    targetVersion: "1.0.0",
                    minimumMacOS: "15.0",
                    currentMacOS: "15.0",
                    assetURL: URL(string: "https://example.test/bad.pkg")!,
                    assetFileName: "bad.pkg",
                    assetByteSize: 4,
                    downloadedFileURL: pkg
                ),
                environment: PackageInstallEnvironment(
                    inspector: AlwaysValidInspector(),
                    markerDirectory: directory
                )
            )
        )
        XCTAssertFalse(PackageSilentInstaller.updateInProgressMarkerExists(in: directory))
    }

    private func seedOriginals() async throws -> RecoveryEnv {
        let settingsStore = SettingsStore(directory: directory)
        let usageStore = UsageHistoryStore(directory: directory)
        try settingsStore.save(AppSettings(accounts: [
            BalanceAccount(id: accountID, kind: .deepseek, displayName: "Original", secretRef: "orig"),
        ], themeMode: "dark"))
        var usage = UsageHistoryDocument()
        usage.dailyRecords = [
            UsageDailyRecord(
                dayKey: "2026-08-01",
                timeZoneIdentifier: "Asia/Shanghai",
                accountId: accountID,
                providerKind: .deepseek,
                unit: "USD",
                providerAmount: 0,
                estimatedAmount: 1.5,
                sampleCount: 1,
                hasBoundaryGap: false
            ),
        ]
        try await usageStore.replaceDocument(usage)
        let recovery = CrashRecoveryStore(
            directory: directory,
            settingsStore: settingsStore,
            usageStore: usageStore
        )
        try leaveUncleanUntilSafeMode(recovery)
        return RecoveryEnv(store: recovery, settingsStore: settingsStore, usageStore: usageStore)
    }

    private func leaveUncleanUntilSafeMode(_ store: CrashRecoveryStore) throws {
        _ = store.beginSession()
        store.handleLifecycle(.forceKill)
        _ = store.beginSession()
        store.handleLifecycle(.forceKill)
        let started = store.beginSession()
        XCTAssertTrue(started.decision.enterSafeMode)
    }

    private func snapshotFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.contains("-") }
            .filter {
                $0.lastPathComponent != "settings.json"
                    && $0.lastPathComponent != "usage-history.json"
                    && !$0.lastPathComponent.hasPrefix("session.")
                    && $0.lastPathComponent != RecoveryLedger.fileName
            }
    }
}

private struct RecoveryEnv {
    var store: CrashRecoveryStore
    var settingsStore: SettingsStore
    var usageStore: UsageHistoryStore
}

private struct AlwaysValidInspector: PackageIntegrityInspecting {
    func inspect(fileURL: URL) -> PackageIntegrityReport {
        PackageIntegrityReport(structureValid: true, signatureValid: true)
    }
}

final class RecoverySideEffectRecorder: @unchecked Sendable {
    var refreshStarts = 0
    var notificationAuthorizations = 0
    var notificationDeliveries = 0
    var smtpSends = 0
    var providerCredentialReads = 0
    var updateInstalls = 0
}

enum RecoverySafeModeLaunch {
    static func perform(route: SessionRoute, effects: RecoverySideEffectRecorder) {
        if RecoveryLaunchPolicy.allowsBackgroundRefresh(route: route) {
            effects.refreshStarts += 1
        }
        if RecoveryLaunchPolicy.allowsNotificationAuthorization(route: route) {
            effects.notificationAuthorizations += 1
        }
        if RecoveryLaunchPolicy.allowsNotificationDelivery(route: route) {
            effects.notificationDeliveries += 1
        }
        if RecoveryLaunchPolicy.allowsSMTP(route: route) {
            effects.smtpSends += 1
        }
        if RecoveryLaunchPolicy.allowsProviderCredentialRead(route: route) {
            effects.providerCredentialReads += 1
        }
        if RecoveryLaunchPolicy.allowsUpdateInstall(route: route) {
            effects.updateInstalls += 1
        }
    }
}
