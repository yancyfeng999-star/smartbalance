import Foundation
import Domain

/// preview → confirm → staged write → validate → atomic replace of staged bytes → result.
/// Never reads or writes Keychain. Restore failures roll back to the pre-restore snapshot.
public final class RestoreCoordinator: @unchecked Sendable {
    private let directory: URL
    private let settingsStore: SettingsStore
    private let usageStore: UsageHistoryStore
    private let backupManager: BackupManager
    private let outcomes: DiagnosticOutcomeStore
    public var beforeInstall: (@Sendable () async -> Void)?
    public var afterSettingsInstall: (@Sendable (BackupSnapshot?) async -> Void)?

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
        var didInstallSettings = false
        var didInstallUsage = false
        let stageDir = directory.appendingPathComponent(".restore-staging", isDirectory: true)

        do {
            try Task.checkCancellation()
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
        } catch is CancellationError {
            return .cancelled()
        } catch {
            outcomes.record(.restore, result: .failed)
            AppLog.error("Restore snapshot failed", category: .backup, event: "restore_snapshot_failed")
            return .failed(.snapshotFailed)
        }

        do {
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

            var stagedUsage: Data?
            if applyUsage, let usage = preview.usageHistory {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let encodedUsage = try encoder.encode(usage)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                _ = try decoder.decode(UsageHistoryDocument.self, from: encodedUsage)
                let stagedUsageURL = stageDir.appendingPathComponent("usage-history.json")
                try encodedUsage.write(to: stagedUsageURL, options: .atomic)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: stagedUsageURL.path
                )
                stagedUsage = encodedUsage
            }

            try Task.checkCancellation()
            if let beforeInstall {
                await beforeInstall()
            }
            try Task.checkCancellation()

            try settingsStore.installValidatedEnvelope(stagedSettings)
            didInstallSettings = true
            if let afterSettingsInstall {
                await afterSettingsInstall(settingsSnapshot)
            }

            if let stagedUsage {
                try Task.checkCancellation()
                do {
                    try await usageStore.replaceEncodedDocument(stagedUsage)
                    didInstallUsage = true
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    let rolled = await rollbackToSnapshots(
                        settings: settingsSnapshot,
                        usage: didInstallUsage ? usageSnapshot : nil
                    )
                    try? FileManager.default.removeItem(at: stageDir)
                    outcomes.record(.restore, result: .failed)
                    AppLog.error("Restore usage write failed", category: .backup, event: "restore_usage_failed")
                    return .failed(
                        .usageWriteFailed,
                        rolledBack: rolled,
                        settingsSnapshotURL: settingsSnapshot?.url,
                        usageSnapshotURL: usageSnapshot?.url
                    )
                }
            }

            try Task.checkCancellation()
            let installed = settingsStore.reloadFromDisk()
            var installedUsage: UsageHistoryDocument?
            if applyUsage {
                installedUsage = try await usageStore.reloadFromDisk().document
            }
            try? FileManager.default.removeItem(at: stageDir)
            outcomes.record(.restore, result: .ok)
            AppLog.write(
                level: "INFO",
                message: "Restore completed",
                category: .backup,
                event: "restore_ok",
                file: #fileID,
                line: #line
            )
            return RestoreOutcome(
                status: .succeeded,
                settingsSnapshotURL: settingsSnapshot?.url,
                usageSnapshotURL: usageSnapshot?.url,
                credentialsNeedReentry: preview.credentialsNeedReentry,
                includedUsage: applyUsage,
                settings: installed,
                usageHistory: installedUsage
            )
        } catch is CancellationError {
            let rolled = await rollbackToSnapshots(
                settings: didInstallSettings ? settingsSnapshot : nil,
                usage: didInstallUsage ? usageSnapshot : nil
            )
            try? FileManager.default.removeItem(at: stageDir)
            return RestoreOutcome(
                status: .cancelled,
                failureReason: .cancelled,
                settingsSnapshotURL: settingsSnapshot?.url,
                usageSnapshotURL: usageSnapshot?.url,
                rolledBack: didInstallSettings && rolled
            )
        } catch {
            let rolled = await rollbackToSnapshots(
                settings: didInstallSettings ? settingsSnapshot : nil,
                usage: didInstallUsage ? usageSnapshot : nil
            )
            try? FileManager.default.removeItem(at: stageDir)
            outcomes.record(.restore, result: .failed)
            AppLog.error("Restore settings write failed", category: .backup, event: "restore_settings_failed")
            return .failed(
                .settingsWriteFailed,
                rolledBack: didInstallSettings && rolled,
                settingsSnapshotURL: settingsSnapshot?.url,
                usageSnapshotURL: usageSnapshot?.url
            )
        }
    }

    @discardableResult
    public func rollbackToSnapshots(
        settings: BackupSnapshot?,
        usage: BackupSnapshot?
    ) async -> Bool {
        var succeeded = true
        if let settings {
            do {
                let data = try Data(contentsOf: settings.url)
                try data.write(to: settingsStore.fileURL, options: .atomic)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: settingsStore.fileURL.path
                )
                _ = settingsStore.reloadFromDisk()
            } catch {
                succeeded = false
            }
        }
        if let usage {
            do {
                let data = try Data(contentsOf: usage.url)
                try data.write(to: usageStore.fileURL, options: .atomic)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: usageStore.fileURL.path
                )
                _ = try await usageStore.reloadFromDisk()
            } catch {
                succeeded = false
            }
        }
        return succeeded
    }
}
