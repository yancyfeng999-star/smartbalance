import Foundation
import Domain

public actor UsageHistoryStore {
    public static let shared = UsageHistoryStore()

    public nonisolated let fileURL: URL

    private let writer: @Sendable (Data, URL) throws -> Void
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cached = UsageHistoryDocument()
    private var hasLoaded = false

    public init(
        filename: String = "usage-history.json",
        directory: URL? = nil
    ) {
        let resolvedDirectory = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(
            at: resolvedDirectory,
            withIntermediateDirectories: true
        )
        fileURL = resolvedDirectory.appendingPathComponent(filename)
        writer = { data, url in
            try data.write(to: url, options: .atomic)
        }
        encoder = Self.makeEncoder()
        decoder = Self.makeDecoder()
    }

    init(
        filename: String,
        directory: URL,
        writer: @escaping @Sendable (Data, URL) throws -> Void
    ) {
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent(filename)
        self.writer = writer
        encoder = Self.makeEncoder()
        decoder = Self.makeDecoder()
    }

    public func load() -> UsageHistoryDocument {
        if hasLoaded { return cached }
        cached = loadFromDisk()
        hasLoaded = true
        return cached
    }

    public func record(
        snapshots: [BalanceSnapshot],
        knownAccountIDs: Set<UUID>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> UsageHistoryDocument {
        if !hasLoaded {
            cached = loadFromDisk()
            hasLoaded = true
        }

        let next = UsageAccumulator.ingest(
            snapshots: snapshots,
            knownAccountIDs: knownAccountIDs,
            document: cached,
            now: now,
            calendar: calendar
        )
        let data = try encoder.encode(next)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writer(data, fileURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
        cached = next
        return next
    }

    public func currentDocument() -> UsageHistoryDocument {
        cached
    }

    private func loadFromDisk() -> UsageHistoryDocument {
        guard let data = try? Data(contentsOf: fileURL) else {
            return UsageHistoryDocument()
        }
        do {
            return try decoder.decode(UsageHistoryDocument.self, from: data)
        } catch {
            let backupURL = fileURL
                .deletingPathExtension()
                .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            do {
                try data.write(to: backupURL, options: .atomic)
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: backupURL.path
                )
                AppLog.error(
                    "usage-history.json 解码失败，已备份到 \(backupURL.lastPathComponent)：\(error.localizedDescription)"
                )
            } catch {
                AppLog.error("usage-history.json 解码失败且备份失败：\(error.localizedDescription)")
            }
            return UsageHistoryDocument()
        }
    }

    private nonisolated static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SmartBalance", isDirectory: true)
    }

    private nonisolated static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private nonisolated static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
