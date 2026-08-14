import Foundation

public struct BackupSnapshot: Equatable, Sendable {
    public var url: URL
    public var reason: String
    public var createdAt: Date

    public init(url: URL, reason: String, createdAt: Date) {
        self.url = url
        self.reason = reason
        self.createdAt = createdAt
    }
}

public enum BackupManagerError: Error, LocalizedError {
    case sourceMissing(String)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sourceMissing(let path):
            return "无法备份，源文件不存在：\(path)"
        case .writeFailed(let detail):
            return "写入备份失败：\(detail)"
        }
    }
}

/// 在 schema 迁移、恢复和重置前生成本机快照。
public final class BackupManager: @unchecked Sendable {
    public static let settingsWriteRetentionLimit = 8

    public let directory: URL
    private let lock = NSLock()

    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func createSnapshot(of fileURL: URL, reason: String, now: Date = Date()) throws -> BackupSnapshot {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw BackupManagerError.sourceMissing(fileURL.path)
        }
        let stamp = Self.makeTimestamp(now)
        let safeReason = Self.sanitize(reason)
        let base = fileURL.deletingPathExtension().lastPathComponent
        let name = "\(base)-\(stamp)-\(safeReason).json"
        let destination = directory.appendingPathComponent(name)
        do {
            let data = try Data(contentsOf: fileURL)
            try data.write(to: destination, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: destination.path
            )
        } catch {
            throw BackupManagerError.writeFailed(error.localizedDescription)
        }
        if safeReason == "settings-write" || reason == "settings-write" {
            pruneSettingsWriteSnapshotsLocked()
        }
        return BackupSnapshot(url: destination, reason: reason, createdAt: now)
    }

    private func pruneSettingsWriteSnapshotsLocked() {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        let writes = items
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.contains("-settings-write") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for stale in writes.dropFirst(Self.settingsWriteRetentionLimit) {
            try? FileManager.default.removeItem(at: stale)
        }
    }

    private static func makeTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private static func sanitize(_ reason: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = reason.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let value = String(mapped)
        return value.isEmpty ? "snapshot" : value
    }
}
