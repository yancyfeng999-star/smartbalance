import Foundation
import Domain

/// 智余数据备份包：账号配置 + 本机密钥（含 API Key / SMTP 密码）。
///
/// 文件为 JSON，扩展名建议 `.json`；**含明文密钥**，勿上传公开网盘。
public struct DataBackupPackage: Codable, Sendable {
    public var format: String
    public var formatVersion: Int
    public var exportedAt: Date
    public var appVersion: String
    public var settings: AppSettings
    public var secrets: [String: String]

    public init(
        format: String = DataBackupService.formatID,
        formatVersion: Int = DataBackupService.currentVersion,
        exportedAt: Date = Date(),
        appVersion: String,
        settings: AppSettings,
        secrets: [String: String]
    ) {
        self.format = format
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.settings = settings
        self.secrets = secrets
    }
}

public enum DataBackupService {
    public static let formatID = "smartbalance.backup"
    public static let currentVersion = 1

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
        secrets: [String: String],
        appVersion: String
    ) -> DataBackupPackage {
        DataBackupPackage(
            exportedAt: Date(),
            appVersion: appVersion,
            settings: settings,
            secrets: secrets
        )
    }

    public static func encode(_ package: DataBackupPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try encoder.encode(package)
        } catch {
            throw BackupError.encodeFailed(error.localizedDescription)
        }
    }

    public static func decode(_ data: Data) throws -> DataBackupPackage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let package: DataBackupPackage
        do {
            package = try decoder.decode(DataBackupPackage.self, from: data)
        } catch {
            throw BackupError.decodeFailed(error.localizedDescription)
        }
        guard package.format == formatID else {
            throw BackupError.invalidFormat
        }
        guard package.formatVersion >= 1, package.formatVersion <= currentVersion else {
            throw BackupError.unsupportedVersion(package.formatVersion)
        }
        return package
    }

    public static func write(_ package: DataBackupPackage, to url: URL) throws {
        let data = try encode(package)
        do {
            try data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
        } catch {
            throw BackupError.writeFailed(error.localizedDescription)
        }
    }

    public static func read(from url: URL) throws -> DataBackupPackage {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BackupError.readFailed(error.localizedDescription)
        }
        return try decode(data)
    }

    public static func defaultFileName(now: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return "智余备份-\(f.string(from: now)).json"
    }
}
