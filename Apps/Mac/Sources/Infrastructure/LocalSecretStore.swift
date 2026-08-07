import Foundation
import Domain

/// 本机密钥库（**不走系统钥匙串，无指纹门禁**）。
///
/// - 路径：`~/Library/Application Support/SmartBalance/secrets.vault`
/// - 权限：`0600`（仅当前用户可读）
/// - 读写直接落盘；进程内缓存，无需会话解锁
public final class LocalSecretStore: @unchecked Sendable {
    public static let shared = LocalSecretStore()

    private let queue = DispatchQueue(label: "com.smartbalance.secrets")
    private var memory: [String: String] = [:]
    private var memoryLoaded = false
    private let vaultURL: URL

    public init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SmartBalance", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        vaultURL = dir.appendingPathComponent("secrets.vault")
    }

    // MARK: - CRUD

    public func set(_ value: String, account: String) throws {
        try queue.sync {
            ensureMemoryLoaded()
            memory[account] = value
            try writeVault(memory)
        }
    }

    public func get(account: String) -> String? {
        queue.sync {
            ensureMemoryLoaded()
            return memory[account]
        }
    }

    public func contains(account: String) -> Bool {
        queue.sync {
            ensureMemoryLoaded()
            return memory[account] != nil
        }
    }

    public func delete(account: String) {
        queue.sync {
            ensureMemoryLoaded()
            memory.removeValue(forKey: account)
            try? writeVault(memory)
        }
    }

    /// 导出全部密钥（备份用；调用方负责安全落盘）。
    public func exportAll() -> [String: String] {
        queue.sync {
            ensureMemoryLoaded()
            return memory
        }
    }

    /// 整库替换（导入备份后用）。
    public func replaceAll(_ dict: [String: String]) throws {
        try queue.sync {
            memory = dict
            memoryLoaded = true
            try writeVault(memory)
        }
    }

    public var vaultFileURL: URL { vaultURL }

    // MARK: - File

    private func ensureMemoryLoaded() {
        guard !memoryLoaded else { return }
        memory = loadVault()
        memoryLoaded = true
    }

    private func loadVault() -> [String: String] {
        guard FileManager.default.fileExists(atPath: vaultURL.path),
              let data = try? Data(contentsOf: vaultURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [:] }
        return obj
    }

    private func writeVault(_ dict: [String: String]) throws {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: vaultURL, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: vaultURL.path
        )
    }

    public enum SecretStoreError: Error, LocalizedError {
        case ioFailed(String)

        public var errorDescription: String? {
            switch self {
            case .ioFailed(let m): "密钥文件错误：\(m)"
            }
        }
    }
}
