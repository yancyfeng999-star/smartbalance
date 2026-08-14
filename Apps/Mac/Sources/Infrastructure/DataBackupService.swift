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

/// 默认导出非敏感 `smartbalance.portable-settings` v2；v1 只识别、警告、不导入 secrets。
public enum DataBackupService {
    public static let legacyFormatID = "smartbalance.backup"
    public static let portableFormatID = PortableSettings.formatID
    public static let formatID = PortableSettings.formatID
    public static let currentVersion = PortableSettings.currentFormatVersion
    public static let legacyVersion = 1

    public enum BackupInspection: Equatable, Sendable {
        case portable(PortableSettings)
        case legacySecret(LegacySecretBackupWarning)
    }

    public enum BackupError: Error, LocalizedError {
        case invalidFormat
        case unsupportedVersion(Int)
        case encodeFailed(String)
        case decodeFailed(String)
        case writeFailed(String)
        case readFailed(String)

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
                    warningMessage: "可能含明文密钥，智余不会导入其中的密钥"
                )
            )
        }

        if format == portableFormatID {
            let portable: PortableSettings
            do {
                portable = try PortableSettings.decode(data)
            } catch {
                throw BackupError.decodeFailed(error.localizedDescription)
            }
            guard portable.formatVersion == PortableSettings.currentFormatVersion else {
                throw BackupError.unsupportedVersion(portable.formatVersion)
            }
            return .portable(portable)
        }

        throw BackupError.invalidFormat
    }

    public static func importSettings(from data: Data) throws -> PortableImportResult {
        switch try inspect(data) {
        case .portable(let portable):
            return portable.importAsSettings()
        case .legacySecret(let warning):
            return warning.preview.importAsSettings()
        }
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
