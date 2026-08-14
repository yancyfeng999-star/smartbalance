import Foundation
import Domain

/// 旧版 `smartbalance.backup` v1 仅用于识别与隔离，不再作为默认导出格式。
struct LegacyDataBackupPackage: Codable, Sendable {
    var format: String
    var formatVersion: Int
    var exportedAt: Date
    var appVersion: String
    var settings: AppSettings
    var secrets: [String: String]
}

public struct LegacySecretBackupWarning: Equatable, Sendable {
    public var formatVersion: Int
    public var appVersion: String
    public var exportedAt: Date
    public var preview: PortableSettings
    public var secretEntryCount: Int
    public var warningMessage: String

    public init(
        formatVersion: Int,
        appVersion: String,
        exportedAt: Date,
        preview: PortableSettings,
        secretEntryCount: Int,
        warningMessage: String
    ) {
        self.formatVersion = formatVersion
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.preview = preview
        self.secretEntryCount = secretEntryCount
        self.warningMessage = warningMessage
    }
}

/// In-memory result of importing a backup.
///
/// `secrets` is never serialized or logged. It is only handed to the restore
/// coordinator after the user explicitly confirms an old plaintext backup.
public struct DataBackupImportResult: Sendable {
    public var settings: AppSettings
    public var secrets: [String: String]
    public var credentialsNeedReentry: Bool

    public init(
        settings: AppSettings,
        secrets: [String: String] = [:],
        credentialsNeedReentry: Bool
    ) {
        self.settings = settings
        self.secrets = secrets
        self.credentialsNeedReentry = credentialsNeedReentry
    }
}

/// 默认导出非敏感 `smartbalance.portable-settings` v2；旧版 v1 仅在用户确认后导入 secrets。
public enum DataBackupService {
    public static let legacyFormatID = "smartbalance.backup"
    public static let portableFormatID = PortableSettings.formatID
    public static let formatID = PortableSettings.formatID
    public static let currentVersion = PortableSettings.currentFormatVersion
    public static let legacyVersion = 1

    public enum BackupInspection: Equatable, Sendable {
        case portable(PortableSettings)
        case localRestore(LocalRestorePackage)
        case legacySecret(LegacySecretBackupWarning)
    }

    public enum BackupError: Error, Equatable, LocalizedError {
        case invalidFormat
        case unsupportedVersion(Int)
        case encodeFailed(String)
        case decodeFailed(String)
        case writeFailed(String)
        case readFailed(String)
        case legacyImportNotConfirmed
        case corruptUsage

        public var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "不是智余备份文件（format 不匹配）"
            case .unsupportedVersion(let v):
                return "备份版本 \(v) 不受支持（当前支持 \(currentVersion)）"
            case .encodeFailed(let m):
                return "导出编码失败：\(m)"
            case .decodeFailed(let m):
                return "导入解析失败：\(m)"
            case .writeFailed(let m):
                return "写入失败：\(m)"
            case .readFailed(let m):
                return "读取失败：\(m)"
            case .legacyImportNotConfirmed:
                return "旧版明文备份默认不导入"
            case .corruptUsage:
                return "备份中的用量历史损坏"
            }
        }
    }

    public static func makePackage(
        settings: AppSettings,
        appVersion: String,
        now: Date = Date()
    ) -> PortableSettings {
        PortableSettings.make(from: settings, appVersion: appVersion, now: now)
    }

    public static func encode(_ package: PortableSettings) throws -> Data {
        let data: Data
        do {
            data = try PortableSettings.encode(package)
        } catch {
            throw BackupError.encodeFailed(error.localizedDescription)
        }
        if PrivacyRedactor.containsForbiddenExportFields(data) {
            throw BackupError.encodeFailed("portable settings contained forbidden fields")
        }
        return data
    }

    public static func inspect(_ data: Data) throws -> BackupInspection {
        let decoder = SettingsDocument.makeDecoder()
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let format = object["format"] as? String else {
            throw BackupError.invalidFormat
        }

        if format == legacyFormatID {
            let package: LegacyDataBackupPackage
            do {
                package = try decoder.decode(LegacyDataBackupPackage.self, from: data)
            } catch {
                throw BackupError.decodeFailed(error.localizedDescription)
            }
            guard package.formatVersion >= 1 else {
                throw BackupError.unsupportedVersion(package.formatVersion)
            }
            let preview = PortableSettings.make(
                from: package.settings,
                appVersion: package.appVersion,
                now: package.exportedAt
            )
            return .legacySecret(
                LegacySecretBackupWarning(
                    formatVersion: package.formatVersion,
                    appVersion: package.appVersion,
                    exportedAt: package.exportedAt,
                    preview: preview,
                    secretEntryCount: package.secrets.count,
                    warningMessage: TransferPreview.legacyPlaintextWarning
                )
            )
        }

        if format == LocalRestorePackage.formatID {
            guard let version = object["formatVersion"] as? Int else {
                throw BackupError.invalidFormat
            }
            guard version == LocalRestorePackage.currentFormatVersion else {
                throw BackupError.unsupportedVersion(version)
            }
            if let usageObject = object["usageHistory"], !(usageObject is NSNull) {
                guard JSONSerialization.isValidJSONObject(usageObject) else {
                    throw BackupError.corruptUsage
                }
                do {
                    let usageData = try JSONSerialization.data(withJSONObject: usageObject)
                    _ = try SettingsDocument.makeDecoder().decode(UsageHistoryDocument.self, from: usageData)
                } catch {
                    throw BackupError.corruptUsage
                }
            }
            let package: LocalRestorePackage
            do {
                package = try LocalRestorePackage.decode(data)
            } catch {
                throw BackupError.decodeFailed(error.localizedDescription)
            }
            return .localRestore(package)
        }

        if format == portableFormatID {
            guard let version = object["formatVersion"] as? Int else {
                throw BackupError.invalidFormat
            }
            guard version == PortableSettings.currentFormatVersion else {
                throw BackupError.unsupportedVersion(version)
            }
            let portable: PortableSettings
            do {
                portable = try PortableSettings.decode(data)
            } catch {
                throw BackupError.decodeFailed(error.localizedDescription)
            }
            return .portable(portable)
        }

        throw BackupError.invalidFormat
    }

    public static func importSettings(
        from data: Data,
        allowLegacyNonSensitive: Bool = false
    ) throws -> DataBackupImportResult {
        switch try inspect(data) {
        case .portable(let portable):
            return makeImportResult(portable.importAsSettings())
        case .localRestore(let package):
            return makeImportResult(package.asPortableSettings.importAsSettings())
        case .legacySecret(let warning):
            guard allowLegacyNonSensitive else {
                throw BackupError.legacyImportNotConfirmed
            }
            let imported = warning.preview.importAsSettings()
            let package = try decodeLegacyPackage(from: data)
            let secrets = remapLegacySecrets(
                sourceSettings: package.settings,
                importedSettings: imported.settings,
                sourceSecrets: package.secrets
            )
            return makeImportResult(imported, secrets: secrets)
        }
    }

    private static func makeImportResult(
        _ imported: PortableImportResult,
        secrets: [String: String] = [:]
    ) -> DataBackupImportResult {
        DataBackupImportResult(
            settings: imported.settings,
            secrets: secrets,
            credentialsNeedReentry: credentialsNeedReentry(
                for: imported.settings,
                importedSecrets: secrets
            )
        )
    }

    private static func decodeLegacyPackage(from data: Data) throws -> LegacyDataBackupPackage {
        do {
            return try SettingsDocument.makeDecoder().decode(LegacyDataBackupPackage.self, from: data)
        } catch {
            throw BackupError.decodeFailed(error.localizedDescription)
        }
    }

    /// v1 used the old account/password refs. Portable settings intentionally
    /// mint new refs, so map the old values by stable account ID before the
    /// restore coordinator writes them to the new ordinary Keychain service.
    private static func remapLegacySecrets(
        sourceSettings: AppSettings,
        importedSettings: AppSettings,
        sourceSecrets: [String: String]
    ) -> [String: String] {
        var importedSecretRefsByID: [UUID: String] = [:]
        for account in importedSettings.accounts {
            importedSecretRefsByID[account.id] = account.secretRef
        }

        var remapped: [String: String] = [:]
        for sourceAccount in sourceSettings.accounts {
            guard let sourceSecret = sourceSecrets[sourceAccount.secretRef],
                  !sourceSecret.isEmpty,
                  let importedRef = importedSecretRefsByID[sourceAccount.id]
            else { continue }
            remapped[importedRef] = sourceSecret
        }

        if let smtpSecret = sourceSecrets[sourceSettings.email.passwordRef],
           !smtpSecret.isEmpty {
            remapped[importedSettings.email.passwordRef] = smtpSecret
        }
        return remapped
    }

    private static func credentialsNeedReentry(
        for settings: AppSettings,
        importedSecrets: [String: String]
    ) -> Bool {
        if settings.accounts.contains(where: {
            $0.kind.needsSecret && importedSecrets[$0.secretRef] == nil
        }) {
            return true
        }

        let emailNeedsPassword = settings.email.enabled
            || settings.email.isConfigured
            || !settings.email.smtpHost.isEmpty
        return emailNeedsPassword && importedSecrets[settings.email.passwordRef] == nil
    }

    public static func write(_ package: PortableSettings, to url: URL) throws {
        let data = try encode(package)
        do {
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
        } catch {
            throw BackupError.writeFailed(error.localizedDescription)
        }
    }

    public static func read(from url: URL) throws -> BackupInspection {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BackupError.readFailed(error.localizedDescription)
        }
        return try inspect(data)
    }

    public static func defaultFileName(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return "智余备份-\(f.string(from: now)).json"
    }
}
