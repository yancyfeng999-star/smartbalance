import Foundation
import Domain

/// preview → confirm → staged write → validate → atomic replace → result.
/// Never reads or writes Keychain. Restore failures roll back to the pre-restore snapshot.
public final class RestoreCoordinator: @unchecked Sendable {
    private let directory: URL
    private let settingsStore: SettingsStore
    private let usageStore: UsageHistoryStore
    private let backupManager: BackupManager
    private let outcomes: DiagnosticOutcomeStore

    public init(
        directory: URL,
        settingsStore: SettingsStore,
        usageStore: UsageHistoryStore,
        backupManager: BackupManager? = nil,
        outcomes: DiagnosticOutcomeStore? = nil
    ) {
        self.directory = directory
        self.settingsStore = settingsStore
        self.usageStore = usageStore
        self.backupManager = backupManager ?? BackupManager(directory: directory)
        self.outcomes = outcomes ?? DiagnosticOutcomeStore(directory: directory)
    }

    public func restore(
        from data: Data,
        confirmed: Bool,
        includeUsage: Bool,
        allowLegacyNonSensitive: Bool = false
    ) async -> RestoreOutcome {
        let preview: TransferPreview
        do {
            preview = try SettingsTransferService.preview(from: data)
        } catch SettingsTransferError.formatMismatch {
            return .failed(.formatMismatch)
        } catch SettingsTransferError.versionTooNew {
            return .failed(.versionTooNew)
        } catch SettingsTransferError.corruptUsage {
            return .failed(.corruptUsage)
        } catch {
            return .failed(.formatMismatch)
        }
        return await restore(
            preview: preview,
            confirmed: confirmed,
            includeUsage: includeUsage,
            allowLegacyNonSensitive: allowLegacyNonSensitive
        )
    }

    public func restore(
        preview: TransferPreview,
        confirmed: Bool,
        includeUsage: Bool,
        allowLegacyNonSensitive: Bool = false
    ) async -> RestoreOutcome {
        guard confirmed else {
            return .cancelled()
        }
        if preview.isLegacySecretBackup && !allowLegacyNonSensitive {
            return .cancelled()
        }

        var settingsSnapshot: BackupSnapshot?
        var usageSnapshot: BackupSnapshot?
        do {
            if FileManager.default.fileExists(atPath: settingsStore.fileURL.path) {
                settingsSnapshot = try backupManager.createSnapshot(
                    of: settingsStore.fileURL,
                    reason: "restore"
                )
            }
            if includeUsage && FileManager.default.fileExists(atPath: usageStore.fileURL.path) {
                usageSnapshot = try backupManager.createSnapshot(
                    of: usageStore.fileURL,
                    reason: "restore"
                )
            }
        } catch {
            outcomes.record(.restore, result: .failed)
            AppLog.error("Restore snapshot failed", category: .backup, event: "restore_snapshot_failed")
            return .failed(.snapshotFailed)
        }

        let applyUsage = includeUsage && preview.usageHistory != nil
        if applyUsage, let usage = preview.usageHistory,
           usage.schemaVersion < 1 || usage.schemaVersion > UsageHistoryDocument.currentSchemaVersion {
            outcomes.record(.restore, result: .failed)
            return .failed(
                .corruptUsage,
                settingsSnapshotURL: settingsSnapshot?.url,
                usageSnapshotURL: usageSnapshot?.url
            )
        }

        let stageDir = directory.appendingPathComponent(".restore-staging", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
            let stagedSettingsURL = stageDir.appendingPathComponent("settings.json")
            let envelope = SettingsDocument(settings: preview.settings)
            let stagedSettings = try SettingsDocument.encode(envelope)
            try stagedSettings.write(to: stagedSettingsURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: stagedSettingsURL.path
            )
            _ = try SettingsMigrationRunner().migrate(data: stagedSettings)

            if applyUsage, let usage = preview.usageHistory {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let stagedUsage = try encoder.encode(usage)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                _ = try decoder.decode(UsageHistoryDocument.self, from: stagedUsage)
                let stagedUsageURL = stageDir.appendingPathComponent("usage-history.json")
                try stagedUsage.write(to: stagedUsageURL, options: .atomic)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: stagedUsageURL.path
                )
            }

            try settingsStore.save(preview.settings)

            if applyUsage, let usage = preview.usageHistory {
                do {
                    try await usageStore.replaceDocument(usage)
                } catch {
                    await rollback(settings: settingsSnapshot, usage: usageSnapshot)
                    try? FileManager.default.removeItem(at: stageDir)
                    outcomes.record(.restore, result: .failed)
                    AppLog.error("Restore usage write failed", category: .backup, event: "restore_usage_failed")
                    return .failed(
                        .usageWriteFailed,
                        rolledBack: true,
                        settingsSnapshotURL: settingsSnapshot?.url,
                        usageSnapshotURL: usageSnapshot?.url
                    )
                }
            }

            _ = settingsStore.reloadFromDisk()
            if applyUsage {
                _ = try? await usageStore.reloadFromDisk()
            }
            try? FileManager.default.removeItem(at: stageDir)
            outcomes.record(.restore, result: .ok)
            AppLog.write(level: "INFO", message: "Restore completed", category: .backup, event: "restore_ok", file: #fileID, line: #line)
            return RestoreOutcome(
                status: .succeeded,
                settingsSnapshotURL: settingsSnapshot?.url,
                usageSnapshotURL: usageSnapshot?.url,
                credentialsNeedReentry: preview.credentialsNeedReentry,
                includedUsage: applyUsage,
                settings: preview.settings,
                usageHistory: applyUsage ? preview.usageHistory : nil
            )
        } catch {
            await rollback(settings: settingsSnapshot, usage: usageSnapshot)
            try? FileManager.default.removeItem(at: stageDir)
            outcomes.record(.restore, result: .failed)
            AppLog.error("Restore settings write failed", category: .backup, event: "restore_settings_failed")
            return .failed(
                .settingsWriteFailed,
                rolledBack: settingsSnapshot != nil,
                settingsSnapshotURL: settingsSnapshot?.url,
                usageSnapshotURL: usageSnapshot?.url
            )
        }
    }

    private func rollback(settings: BackupSnapshot?, usage: BackupSnapshot?) async {
        if let settings {
            if let data = try? Data(contentsOf: settings.url) {
                try? data.write(to: settingsStore.fileURL, options: .atomic)
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: settingsStore.fileURL.path
                )
            }
            _ = settingsStore.reloadFromDisk()
        }
        if let usage {
            if let data = try? Data(contentsOf: usage.url) {
                try? data.write(to: usageStore.fileURL, options: .atomic)
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: usageStore.fileURL.path
                )
            }
            _ = try? await usageStore.reloadFromDisk()
        }
    }
}
