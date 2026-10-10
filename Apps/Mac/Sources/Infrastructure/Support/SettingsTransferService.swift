import Foundation
import Domain

/// Export / preview for non-secret settings transfer and local restore packages.
public enum SettingsTransferService {
    public static func exportData(
        settings: AppSettings,
        appVersion: String,
        now: Date = Date()
    ) throws -> Data {
        try DataBackupService.encode(
            DataBackupService.makePackage(settings: settings, appVersion: appVersion, now: now)
        )
    }

    public static func writeExport(
        settings: AppSettings,
        appVersion: String,
        now: Date = Date(),
        to url: URL
    ) throws {
        try DataBackupService.write(
            DataBackupService.makePackage(settings: settings, appVersion: appVersion, now: now),
            to: url
        )
    }

    public static func exportLocalRestoreData(
        settings: AppSettings,
        usage: UsageHistoryDocument?,
        appVersion: String,
        now: Date = Date()
    ) throws -> Data {
        let package = LocalRestorePackage.make(
            from: settings,
            usage: usage,
            appVersion: appVersion,
            now: now
        )
        let data: Data
        do {
            data = try LocalRestorePackage.encode(package)
        } catch {
            throw SettingsTransferError.encodeFailed
        }
        if PrivacyRedactor.containsForbiddenExportFields(data) {
            throw SettingsTransferError.encodeFailed
        }
        return data
    }

    public static func writeLocalRestore(
        settings: AppSettings,
        usage: UsageHistoryDocument?,
        appVersion: String,
        now: Date = Date(),
        to url: URL
    ) throws {
        let data = try exportLocalRestoreData(
            settings: settings,
            usage: usage,
            appVersion: appVersion,
            now: now
        )
        do {
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
        } catch {
            throw SettingsTransferError.writeFailed
        }
    }

    public static func preview(from data: Data) throws -> TransferPreview {
        let inspection: DataBackupService.BackupInspection
        do {
            inspection = try DataBackupService.inspect(data)
        } catch DataBackupService.BackupError.invalidFormat {
            throw SettingsTransferError.formatMismatch
        } catch DataBackupService.BackupError.unsupportedVersion(let version) {
            throw SettingsTransferError.versionTooNew(version)
        } catch DataBackupService.BackupError.corruptUsage {
            throw SettingsTransferError.corruptUsage
        } catch {
            throw SettingsTransferError.decodeFailed
        }

        switch inspection {
        case .portable(let portable):
            return TransferPreview.make(portable: portable)
        case .localRestore(let package):
            return package.asPreview()
        case .legacySecret(let warning):
            var preview = TransferPreview.make(
                portable: warning.preview,
                isLegacy: true,
                legacyWarning: TransferPreview.legacyPlaintextWarning
            )
            preview.format = DataBackupService.legacyFormatID
            preview.formatVersion = warning.formatVersion
            preview.appVersion = warning.appVersion
            preview.exportedAt = warning.exportedAt
            return preview
        }
    }

    public static func datedFileName(prefix: String, now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "\(prefix)-\(formatter.string(from: now)).json"
    }
}
