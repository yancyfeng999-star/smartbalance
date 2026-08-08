import Foundation
import Domain

/// JSON 设置持久化（密钥除外）。
public final class SettingsStore: @unchecked Sendable {
    public static let shared = SettingsStore()

    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    public init(filename: String = "settings.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SmartBalance", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent(filename)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load() -> AppSettings {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url) else {
            return AppSettings()
        }
        do {
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            // 解码失败绝不静默清空：备份坏文件，再返回空默认
            let bak = url.deletingPathExtension().appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? data.write(to: bak, options: .atomic)
            AppLog.error("settings.json 解码失败，已备份到 \(bak.lastPathComponent)：\(error.localizedDescription)")
            return AppSettings()
        }
    }

    public func save(_ settings: AppSettings) throws {
        lock.lock()
        defer { lock.unlock() }
        // 防止误把空账号列表覆盖已有配置：若磁盘上已有账号而内存为空，拒绝保存
        var toWrite = settings
        if settings.accounts.isEmpty,
           let existing = try? Data(contentsOf: url),
           let old = try? decoder.decode(AppSettings.self, from: existing),
           !old.accounts.isEmpty {
            AppLog.error("拒绝用空 accounts 覆盖已有 \(old.accounts.count) 个账号的配置")
            toWrite.accounts = old.accounts
        }
        let data = try encoder.encode(toWrite)
        try data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    public var fileURL: URL { url }
}
