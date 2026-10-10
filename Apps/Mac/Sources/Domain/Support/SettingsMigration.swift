import Foundation

public struct SettingsMigrationOutcome: Equatable, Sendable {
    public var document: SettingsDocument
    public var sourceSchemaVersion: Int
    public var didMigrate: Bool

    public init(document: SettingsDocument, sourceSchemaVersion: Int, didMigrate: Bool) {
        self.document = document
        self.sourceSchemaVersion = sourceSchemaVersion
        self.didMigrate = didMigrate
    }
}

public enum SettingsMigrationError: Error, Equatable, LocalizedError {
    case invalidJSON
    case unsupportedSchemaVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "settings.json 不是有效 JSON"
        case .unsupportedSchemaVersion(let version):
            return "不支持的设置 schema 版本 \(version)"
        }
    }
}

/// 纯迁移链：把磁盘上的设置 JSON 变成当前 SettingsDocument。
public enum SettingsMigration {
    public static func migrate(data: Data, now: Date = Date()) throws -> SettingsMigrationOutcome {
        let raw: Any
        do {
            raw = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw SettingsMigrationError.invalidJSON
        }
        guard let object = raw as? [String: Any] else {
            throw SettingsMigrationError.invalidJSON
        }

        let decoder = SettingsDocument.makeDecoder()
        if isEnvelope(object) {
            let document: SettingsDocument
            do {
                document = try decoder.decode(SettingsDocument.self, from: data)
            } catch {
                throw SettingsMigrationError.invalidJSON
            }
            if document.schemaVersion > SettingsDocument.currentSchemaVersion {
                throw SettingsMigrationError.unsupportedSchemaVersion(document.schemaVersion)
            }
            if document.schemaVersion == SettingsDocument.currentSchemaVersion {
                return SettingsMigrationOutcome(
                    document: document,
                    sourceSchemaVersion: document.schemaVersion,
                    didMigrate: false
                )
            }
            let upgraded = SettingsDocument(
                schemaVersion: SettingsDocument.currentSchemaVersion,
                updatedAt: now,
                settings: document.settings,
                extensions: document.extensions
            )
            return SettingsMigrationOutcome(
                document: upgraded,
                sourceSchemaVersion: document.schemaVersion,
                didMigrate: true
            )
        }

        let settings: AppSettings
        do {
            settings = try decoder.decode(AppSettings.self, from: data)
        } catch {
            throw SettingsMigrationError.invalidJSON
        }
        let document = SettingsDocument(
            schemaVersion: SettingsDocument.currentSchemaVersion,
            updatedAt: now,
            settings: settings,
            extensions: settings.extensions
        )
        return SettingsMigrationOutcome(
            document: document,
            sourceSchemaVersion: 0,
            didMigrate: true
        )
    }

    private static func isEnvelope(_ object: [String: Any]) -> Bool {
        guard object["settings"] is [String: Any] else { return false }
        if object["schemaVersion"] is Int { return true }
        if let number = object["schemaVersion"] as? NSNumber {
            return Double(truncating: number) == Double(number.intValue)
        }
        return false
    }
}
