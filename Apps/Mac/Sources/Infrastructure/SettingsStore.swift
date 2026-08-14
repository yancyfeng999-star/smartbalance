import Foundation
import Domain

/// JSON 设置持久化（密钥除外）。
public final class SettingsStore: @unchecked Sendable {
    public static let shared = SettingsStore()

    private let url: URL
    private let lock = NSLock()
    private let backupManager: BackupManager
    private let outcomes: DiagnosticOutcomeStore
    private let writer: @Sendable (Data, URL) throws -> Void
    private let runner = SettingsMigrationRunner()
    private var cachedDocument: SettingsDocument?

    public init(filename: String = "settings.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SmartBalance", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent(filename)
        self.backupManager = BackupManager(directory: dir)
        self.outcomes = DiagnosticOutcomeStore(directory: dir)
        self.writer = Self.defaultWriter
    }

    public init(
        directory: URL,
        filename: String = "settings.json",
        backupManager: BackupManager? = nil,
        writer: (@Sendable (Data, URL) throws -> Void)? = nil
    ) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.url = directory.appendingPathComponent(filename)
        self.backupManager = backupManager ?? BackupManager(directory: directory)
        self.outcomes = DiagnosticOutcomeStore(directory: directory)
        self.writer = writer ?? Self.defaultWriter
    }

    public func load() -> AppSettings {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url) else {
            cachedDocument = nil
            return AppSettings()
        }
        do {
            let outcome = try runner.migrate(data: data)
            var document = outcome.document
            document.settings.extensions = document.extensions
            if outcome.didMigrate {
                do {
                    _ = try backupManager.createSnapshot(of: url, reason: "schema-migration")
                    try writer(try SettingsDocument.encode(document), url)
                    cachedDocument = document
                    outcomes.record(.migration, result: .ok)
                } catch {
                    outcomes.record(.migration, result: .failed)
                    AppLog.error("settings schema 迁移写入失败，保留原文件", category: .settings, event: "schema_migration_failed")
                    cachedDocument = document
                    return document.settings
                }
            } else {
                cachedDocument = document
            }
            return document.settings
        } catch {
            let bak = url.deletingPathExtension()
                .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? data.write(to: bak, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: bak.path
            )
            AppLog.error("settings.json 解码失败，已备份到 \(bak.lastPathComponent)：\(error.localizedDescription)")
            cachedDocument = nil
            return AppSettings()
        }
    }

    public func save(_ settings: AppSettings) throws {
        lock.lock()
        defer { lock.unlock() }
        var toWrite = settings
        if settings.accounts.isEmpty,
           let existing = existingAccounts(),
           !existing.isEmpty {
            AppLog.error("拒绝用空 accounts 覆盖已有 \(existing.count) 个账号的配置")
            toWrite.accounts = existing
        }
        let extensions = toWrite.extensions.isEmpty ? (cachedDocument?.extensions ?? [:]) : toWrite.extensions
        toWrite.extensions = extensions
        let document = SettingsDocument(
            schemaVersion: SettingsDocument.currentSchemaVersion,
            updatedAt: Date(),
            settings: toWrite,
            extensions: extensions
        )
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try backupManager.createSnapshot(of: url, reason: "settings-write")
            }
            try writer(try SettingsDocument.encode(document), url)
            cachedDocument = document
            outcomes.record(.backup, result: .ok)
        } catch {
            outcomes.record(.backup, result: .failed)
            throw error
        }
    }

    public var fileURL: URL { url }

    @discardableResult
    public func reloadFromDisk() -> AppSettings {
        lock.lock()
        cachedDocument = nil
        lock.unlock()
        return load()
    }

    private func existingAccounts() -> [BalanceAccount]? {
        guard let existing = try? Data(contentsOf: url),
              let outcome = try? runner.migrate(data: existing) else {
            return nil
        }
        return outcome.document.settings.accounts
    }

    private static func defaultWriter(_ data: Data, _ url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}
