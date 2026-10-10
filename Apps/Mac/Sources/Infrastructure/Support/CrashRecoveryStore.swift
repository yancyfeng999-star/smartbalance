import Foundation
import Domain

/// Persists the launch session marker and decides whether the next start is safe mode.
/// Never reads Provider credentials or Keychain secrets.
public final class CrashRecoveryStore: @unchecked Sendable {
    public static let shared = CrashRecoveryStore(directory: SmartBalanceSupportPaths.applicationSupport)

    public let directory: URL
    public let markerURL: URL
    public let ledgerURL: URL

    private let settingsStore: SettingsStore
    private let usageStore: UsageHistoryStore
    private let backupManager: BackupManager
    private let outcomes: DiagnosticOutcomeStore
    private let lock = NSLock()
    private var lastDecision = RecoveryDecision.normal
    private var currentMarker: RecoveryMarker?

    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory
        self.markerURL = directory.appendingPathComponent(RecoveryMarker.fileName)
        self.ledgerURL = directory.appendingPathComponent(RecoveryLedger.fileName)
        self.settingsStore = SettingsStore(directory: directory)
        self.usageStore = UsageHistoryStore(directory: directory)
        self.backupManager = BackupManager(directory: directory)
        self.outcomes = DiagnosticOutcomeStore(directory: directory)
    }

    public init(
        directory: URL,
        settingsStore: SettingsStore,
        usageStore: UsageHistoryStore,
        backupManager: BackupManager? = nil,
        outcomes: DiagnosticOutcomeStore? = nil
    ) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory
        self.markerURL = directory.appendingPathComponent(RecoveryMarker.fileName)
        self.ledgerURL = directory.appendingPathComponent(RecoveryLedger.fileName)
        self.settingsStore = settingsStore
        self.usageStore = usageStore
        self.backupManager = backupManager ?? BackupManager(directory: directory)
        self.outcomes = outcomes ?? DiagnosticOutcomeStore(directory: directory)
    }

    @discardableResult
    public func beginSession(now: Date = Date()) -> RecoverySessionStart {
        lock.lock()
        defer { lock.unlock() }

        var ledger = loadLedgerLocked()
        var reasons: [RecoveryReason] = []

        if let leftover = loadMarkerLocked(),
           RecoveryMarkerLifecyclePolicy.leftoverPhaseIsUnclean(leftover.phase) {
            ledger.consecutiveUncleanExits += 1
            ledger.lastUncleanAt = now
            ledger.lastReason = .consecutiveUncleanExits
        }

        if settingsFileIsCorruptLocked() {
            reasons.append(.settingsCorrupt)
            ledger.lastReason = .settingsCorrupt
        }
        if PackageSilentInstaller.updateInProgressMarkerExists(in: directory) {
            reasons.append(.interruptedUpdate)
            ledger.lastReason = .interruptedUpdate
        }
        if ledger.consecutiveUncleanExits >= RecoveryLimits.uncleanMarkerThreshold {
            if !reasons.contains(.consecutiveUncleanExits) {
                reasons.insert(.consecutiveUncleanExits, at: 0)
            }
        }

        let enter = reasons.contains(where: \.entersSafeModeImmediately)
            || ledger.consecutiveUncleanExits >= RecoveryLimits.uncleanMarkerThreshold
        let decision = RecoveryDecision(
            enterSafeMode: enter,
            reasons: reasons,
            consecutiveUncleanExits: ledger.consecutiveUncleanExits
        )
        lastDecision = decision

        let marker = RecoveryMarker(startedAt: now, phase: .launching)
        currentMarker = marker
        try? writeLocked(marker, to: markerURL)
        try? writeLocked(ledger, to: ledgerURL)
        return RecoverySessionStart(decision: decision)
    }

    public func markSessionHealthy() {
        lock.lock()
        defer { lock.unlock() }
        guard var marker = currentMarker ?? loadMarkerLocked() else { return }
        marker.phase = .healthy
        currentMarker = marker
        try? writeLocked(marker, to: markerURL)
    }

    public func markCleanQuit() {
        handleLifecycle(.explicitQuit)
    }

    public func handleLifecycle(_ event: RecoveryLifecycleEvent) {
        lock.lock()
        defer { lock.unlock() }
        switch event {
        case .windowHidden, .forceKill:
            break
        case .explicitQuit:
            try? FileManager.default.removeItem(at: markerURL)
            currentMarker = nil
            var ledger = loadLedgerLocked()
            ledger.consecutiveUncleanExits = 0
            ledger.lastReason = nil
            try? writeLocked(ledger, to: ledgerURL)
        }
    }

    @discardableResult
    public func continueNormalStart() -> RecoveryDecision {
        lock.lock()
        defer { lock.unlock() }
        PackageSilentInstaller.clearUpdateInProgressMarker(directory: directory)
        var marker = currentMarker ?? loadMarkerLocked() ?? RecoveryMarker(phase: .healthy)
        marker.phase = .healthy
        marker.continuedFromSafeMode = true
        currentMarker = marker
        try? writeLocked(marker, to: markerURL)

        var decision = lastDecision
        decision.continuedThisSession = true
        decision.enterSafeMode = false
        lastDecision = decision
        return decision
    }

    public func loadMarker() -> RecoveryMarker? {
        lock.lock()
        defer { lock.unlock() }
        return loadMarkerLocked()
    }

    public func loadLedger() -> RecoveryLedger {
        lock.lock()
        defer { lock.unlock() }
        return loadLedgerLocked()
    }

    public func currentDecision() -> RecoveryDecision {
        lock.lock()
        defer { lock.unlock() }
        return lastDecision
    }

    public func currentRoute(firstLaunch: SessionRoute) -> SessionRoute {
        route(decision: currentDecision(), firstLaunch: firstLaunch)
    }

    public func route(decision: RecoveryDecision, firstLaunch: SessionRoute) -> SessionRoute {
        RecoveryRouter.route(decision: decision, firstLaunchRoute: firstLaunch)
    }

    public func exportNonSensitiveSettings(to url: URL, appVersion: String, now: Date = Date()) throws {
        let settings = settingsStore.load()
        try SettingsTransferService.writeExport(
            settings: settings,
            appVersion: appVersion,
            now: now,
            to: url
        )
    }

    public func latestSettingsSnapshot() -> BackupSnapshot? {
        backupManager.latestSnapshot(baseName: "settings")
    }

    public func restoreLatestSnapshot(includeUsage: Bool) async -> RestoreOutcome {
        let settingsSnapshot = backupManager.latestSnapshot(baseName: "settings")
        guard let settingsSnapshot else {
            return .failed(.validationFailed)
        }
        let settingsData: Data
        do {
            settingsData = try Data(contentsOf: settingsSnapshot.url)
            _ = try SettingsMigrationRunner().migrate(data: settingsData)
        } catch {
            return .failed(.validationFailed)
        }

        var usageData: Data?
        var usageSnapshot: BackupSnapshot?
        if includeUsage {
            usageSnapshot = backupManager.latestSnapshot(baseName: "usage-history")
            if let usageSnapshot {
                do {
                    let data = try Data(contentsOf: usageSnapshot.url)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    _ = try decoder.decode(UsageHistoryDocument.self, from: data)
                    usageData = data
                } catch {
                    return .failed(.validationFailed)
                }
            }
        }

        let stageDir = directory.appendingPathComponent(".recovery-staging", isDirectory: true)
        let originalSettings = try? Data(contentsOf: settingsStore.fileURL)
        let originalUsage = try? Data(contentsOf: usageStore.fileURL)
        do {
            try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
            let stagedSettingsURL = stageDir.appendingPathComponent("settings.json")
            let migrated = try SettingsMigrationRunner().migrate(data: settingsData)
            let stagedSettings = try SettingsDocument.encode(migrated.document)
            try stagedSettings.write(to: stagedSettingsURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: stagedSettingsURL.path
            )
            _ = try SettingsMigrationRunner().migrate(data: stagedSettings)

            if let usageData {
                let stagedUsageURL = stageDir.appendingPathComponent("usage-history.json")
                try usageData.write(to: stagedUsageURL, options: .atomic)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: stagedUsageURL.path
                )
            }

            try settingsStore.installValidatedEnvelope(stagedSettings)
            if let usageData {
                try await usageStore.replaceEncodedDocument(usageData)
            }
            try? FileManager.default.removeItem(at: stageDir)
            outcomes.record(.restore, result: .ok)
            let installed = settingsStore.reloadFromDisk()
            var installedUsage: UsageHistoryDocument?
            if usageData != nil {
                installedUsage = try await usageStore.reloadFromDisk().document
            }
            return RestoreOutcome(
                status: .succeeded,
                settingsSnapshotURL: settingsSnapshot.url,
                usageSnapshotURL: usageSnapshot?.url,
                includedUsage: usageData != nil,
                settings: installed,
                usageHistory: installedUsage
            )
        } catch {
            if let originalSettings {
                try? originalSettings.write(to: settingsStore.fileURL, options: .atomic)
                _ = settingsStore.reloadFromDisk()
            }
            if let originalUsage {
                try? await usageStore.replaceEncodedDocument(originalUsage)
            }
            try? FileManager.default.removeItem(at: stageDir)
            outcomes.record(.restore, result: .failed)
            AppLog.error("Recovery restore failed", category: .backup, event: "recovery_restore_failed")
            return .failed(
                .validationFailed,
                settingsSnapshotURL: settingsSnapshot.url,
                usageSnapshotURL: usageSnapshot?.url
            )
        }
    }

    public func resetSettings(includeUsageHistory: Bool) async throws -> RecoveryResetOutcome {
        var settingsSnapshot: BackupSnapshot?
        var usageSnapshot: BackupSnapshot?
        do {
            if FileManager.default.fileExists(atPath: settingsStore.fileURL.path) {
                settingsSnapshot = try backupManager.createSnapshot(
                    of: settingsStore.fileURL,
                    reason: RecoveryResetPolicy.snapshotReason
                )
            }
            if includeUsageHistory, FileManager.default.fileExists(atPath: usageStore.fileURL.path) {
                usageSnapshot = try backupManager.createSnapshot(
                    of: usageStore.fileURL,
                    reason: RecoveryResetPolicy.snapshotReason
                )
            }
        } catch {
            return RecoveryResetOutcome(
                succeeded: false,
                settingsSnapshotURL: settingsSnapshot?.url,
                usageSnapshotURL: usageSnapshot?.url,
                failureReason: .snapshotFailed
            )
        }

        do {
            try settingsStore.replaceWithDefaults()
            if includeUsageHistory {
                try await usageStore.replaceDocument(UsageHistoryDocument())
            }
            outcomes.record(.backup, result: .ok)
            return RecoveryResetOutcome(
                succeeded: true,
                settingsSnapshotURL: settingsSnapshot?.url,
                usageSnapshotURL: usageSnapshot?.url,
                keychainEntriesDeleted: 0,
                resetUsageHistory: includeUsageHistory
            )
        } catch {
            outcomes.record(.backup, result: .failed)
            return RecoveryResetOutcome(
                succeeded: false,
                settingsSnapshotURL: settingsSnapshot?.url,
                usageSnapshotURL: usageSnapshot?.url,
                failureReason: .settingsWriteFailed
            )
        }
    }

    private func settingsFileIsCorruptLocked() -> Bool {
        let url = directory.appendingPathComponent("settings.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let data = try? Data(contentsOf: url) else { return true }
        do {
            _ = try SettingsMigrationRunner().migrate(data: data)
            return false
        } catch {
            return true
        }
    }

    private func loadMarkerLocked() -> RecoveryMarker? {
        guard let data = try? Data(contentsOf: markerURL) else { return nil }
        return try? Self.makeDecoder().decode(RecoveryMarker.self, from: data)
    }

    private func loadLedgerLocked() -> RecoveryLedger {
        guard let data = try? Data(contentsOf: ledgerURL),
              let ledger = try? Self.makeDecoder().decode(RecoveryLedger.self, from: data)
        else {
            return .empty
        }
        return ledger
    }

    private func writeLocked<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try Self.makeEncoder().encode(value)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
