import Foundation
import Domain

/// Independent first-launch record. Not part of AppSettings / settings.json.
public final class FirstLaunchStore: @unchecked Sendable {
    public static let shared = FirstLaunchStore()

    private let url: URL
    private let lock = NSLock()
    private let writer: @Sendable (Data, URL) throws -> Void

    public init(filename: String = "first-launch.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SmartBalance", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent(filename)
        self.writer = Self.defaultWriter
    }

    public init(
        directory: URL,
        filename: String = "first-launch.json",
        writer: (@Sendable (Data, URL) throws -> Void)? = nil
    ) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.url = directory.appendingPathComponent(filename)
        self.writer = writer ?? Self.defaultWriter
    }

    public var fileURL: URL { url }

    public func load() -> FirstLaunchLoadResult {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .missing
        }
        guard let data = try? Data(contentsOf: url) else {
            return .corrupt
        }
        do {
            let state = try Self.makeDecoder().decode(FirstLaunchState.self, from: data)
            if state.schemaVersion > FirstLaunchState.currentSchemaVersion {
                return .corrupt
            }
            return .loaded(state)
        } catch {
            return .corrupt
        }
    }

    public func save(_ state: FirstLaunchState) throws {
        lock.lock()
        defer { lock.unlock() }
        try writer(try Self.makeEncoder().encode(state), url)
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

    private static func defaultWriter(_ data: Data, _ url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}
