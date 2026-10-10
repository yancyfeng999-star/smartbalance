import Foundation
import Darwin
import Domain

public enum UsageHistoryRecovery: Equatable, Sendable {
    case corruptFileBackedUp
}

public struct UsageHistoryLoadResult: Equatable, Sendable {
    public var document: UsageHistoryDocument
    public var recovery: UsageHistoryRecovery?
    public var health: UsageStorageHealth

    public init(
        document: UsageHistoryDocument,
        recovery: UsageHistoryRecovery? = nil,
        health: UsageStorageHealth? = nil
    ) {
        self.document = document
        self.recovery = recovery
        self.health = health ?? UsageStorageHealth.resolve(
            recoveredFromCorruptFile: recovery == .corruptFileBackedUp
        )
    }
}

public enum UsageHistoryStoreError: LocalizedError, Sendable {
    case readFailed(String)
    case corruptBackupFailed(String)

    public var errorDescription: String? {
        switch self {
        case .readFailed(let detail):
            "Unable to read usage history: \(detail)"
        case .corruptBackupFailed(let detail):
            "Unable to back up corrupt usage history: \(detail)"
        }
    }
}

public enum UsageHistoryPersistFailure: String, Sendable, Equatable {
    case load
    case save
    case cancelled
}

public enum UsageHistoryPersistResult: Sendable, Equatable {
    case saved(UsageHistoryDocument)
    case failed(UsageHistoryPersistFailure)
}

public actor UsageHistoryStore {
    public static let shared = UsageHistoryStore()

    public nonisolated let fileURL: URL

    private let writer: @Sendable (Data, URL) throws -> Void
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cached = UsageHistoryDocument()
    private var hasLoaded = false
    private var recovery: UsageHistoryRecovery?

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
        writer = Self.secureAtomicWrite
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

    public func load() throws -> UsageHistoryLoadResult {
        if hasLoaded {
            return UsageHistoryLoadResult(document: cached, recovery: recovery)
        }
        let result = try loadFromDisk()
        cached = result.document
        recovery = result.recovery
        hasLoaded = true
        return result
    }

    public func persistRecord(
        snapshots: [BalanceSnapshot],
        knownAccountIDs: Set<UUID>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UsageHistoryPersistResult {
        do {
            return .saved(
                try record(
                    snapshots: snapshots,
                    knownAccountIDs: knownAccountIDs,
                    now: now,
                    calendar: calendar
                )
            )
        } catch is CancellationError {
            return .failed(.cancelled)
        } catch is UsageHistoryStoreError {
            return .failed(.load)
        } catch {
            return .failed(.save)
        }
    }

    public func record(
        snapshots: [BalanceSnapshot],
        knownAccountIDs: Set<UUID>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> UsageHistoryDocument {
        try Task.checkCancellation()
        if !hasLoaded {
            let result = try loadFromDisk()
            cached = result.document
            recovery = result.recovery
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
        try Task.checkCancellation()
        try writer(data, fileURL)
        cached = next
        return next
    }

    public func resetBaselines(for accountIDs: Set<UUID>) throws -> UsageHistoryDocument {
        try Task.checkCancellation()
        if !hasLoaded {
            let result = try loadFromDisk()
            cached = result.document
            recovery = result.recovery
            hasLoaded = true
        }

        var next = cached
        next.baselines.removeAll { accountIDs.contains($0.accountId) }
        guard next != cached else { return cached }

        let data = try encoder.encode(next)
        try Task.checkCancellation()
        try writer(data, fileURL)
        cached = next
        return next
    }

    public func currentDocument() -> UsageHistoryDocument {
        cached
    }

    public func replaceDocument(_ document: UsageHistoryDocument) throws {
        let data = try encoder.encode(document)
        try replaceEncodedDocument(data)
    }

    public func replaceEncodedDocument(_ data: Data) throws {
        try Task.checkCancellation()
        let document = try decoder.decode(UsageHistoryDocument.self, from: data)
        try writer(data, fileURL)
        cached = document
        hasLoaded = true
        recovery = nil
    }

    @discardableResult
    public func reloadFromDisk() throws -> UsageHistoryLoadResult {
        hasLoaded = false
        recovery = nil
        cached = UsageHistoryDocument()
        return try load()
    }

    private func loadFromDisk() throws -> UsageHistoryLoadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return UsageHistoryLoadResult(document: UsageHistoryDocument())
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw UsageHistoryStoreError.readFailed(error.localizedDescription)
        }
        do {
            return UsageHistoryLoadResult(
                document: try decoder.decode(UsageHistoryDocument.self, from: data)
            )
        } catch {
            let backupURL = fileURL
                .deletingPathExtension()
                .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            do {
                try Self.secureAtomicWrite(data, backupURL)
                AppLog.error(
                    "usage-history.json 解码失败，已备份到 \(backupURL.lastPathComponent)：\(error.localizedDescription)"
                )
            } catch let backupError {
                AppLog.error("usage-history.json 解码失败且备份失败：\(backupError.localizedDescription)")
                throw UsageHistoryStoreError.corruptBackupFailed(backupError.localizedDescription)
            }
            return UsageHistoryLoadResult(
                document: UsageHistoryDocument(),
                recovery: .corruptFileBackedUp
            )
        }
    }

    private nonisolated static func secureAtomicWrite(_ data: Data, _ url: URL) throws {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var template = Array(
            directory
                .appendingPathComponent(".\(url.lastPathComponent).XXXXXX.tmp")
                .path
                .utf8CString
        )
        let descriptor = Darwin.mkstemps(&template, 4)
        guard descriptor >= 0 else { throw currentPOSIXError() }

        let temporaryPath = String(
            decoding: template.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
        let temporaryURL = URL(fileURLWithPath: temporaryPath)
        var descriptorIsOpen = true
        defer {
            if descriptorIsOpen { _ = Darwin.close(descriptor) }
            try? fileManager.removeItem(at: temporaryURL)
        }

        guard Darwin.fchmod(descriptor, S_IRUSR | S_IWUSR) == 0 else {
            throw currentPOSIXError()
        }
        try data.withUnsafeBytes { buffer in
            guard var pointer = buffer.baseAddress else { return }
            var remaining = buffer.count
            while remaining > 0 {
                let written = Darwin.write(descriptor, pointer, remaining)
                if written < 0 {
                    if errno == EINTR { continue }
                    throw currentPOSIXError()
                }
                guard written > 0 else { throw POSIXError(.EIO) }
                pointer = pointer.advanced(by: written)
                remaining -= written
            }
        }
        guard Darwin.fsync(descriptor) == 0 else { throw currentPOSIXError() }
        let closeResult = Darwin.close(descriptor)
        descriptorIsOpen = false
        guard closeResult == 0 else { throw currentPOSIXError() }

        let result = temporaryURL.path.withCString { sourcePath in
            url.path.withCString { destinationPath in
                Darwin.rename(sourcePath, destinationPath)
            }
        }
        guard result == 0 else {
            throw currentPOSIXError()
        }
    }

    private nonisolated static func currentPOSIXError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
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
