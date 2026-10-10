import Foundation

/// 本地 settings.json 信封：版本、已知设置和未知字段。
public struct SettingsDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var updatedAt: Date
    public var settings: AppSettings
    public var extensions: [String: JSONValue]

    public init(
        schemaVersion: Int = SettingsDocument.currentSchemaVersion,
        updatedAt: Date = Date(),
        settings: AppSettings,
        extensions: [String: JSONValue] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        var next = settings
        next.extensions = extensions
        self.settings = next
        self.extensions = extensions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        var decodedSettings = try container.decode(AppSettings.self, forKey: .settings)
        var extras = try container.decodeIfPresent([String: JSONValue].self, forKey: .extensions) ?? [:]
        extras.merge(decodedSettings.extensions) { current, _ in current }
        extras = try UnknownFields.collect(from: decoder, known: CodingKeys.self, existing: extras)
        decodedSettings.extensions = extras
        settings = decodedSettings
        extensions = extras
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(settings, forKey: .settings)
        try container.encode(extensions, forKey: .extensions)
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public static func encode(_ document: SettingsDocument) throws -> Data {
        try makeEncoder().encode(document)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, updatedAt, settings, extensions
    }
}
