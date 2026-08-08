import Foundation
import Domain

/// 本机密钥库（明文 JSON + 0600；不做加密，按产品要求）。
///
/// - 路径：`~/Library/Application Support/SmartBalance/secrets.vault`
/// - 损坏时备份，**拒绝用空库覆盖**非空文件
public final class LocalSecretStore: @unchecked Sendable {
    public static let shared = LocalSecretStore()

    private let queue = DispatchQueue(label: "com.smartbalance.secrets")
    private var memory: [String: String] = [:]
    private var memoryLoaded = false
    /// 磁盘上存在 vault 但解析失败；禁止空写覆盖
    private var diskCorrupt = false
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

    /// 导出全部密钥（备份用）。
    public func exportAll() -> [String: String] {
        queue.sync {
            ensureMemoryLoaded()
            return memory
        }
    }

    /// 整库替换（导入备份）。成功后清除 corrupt 标记。
    public func replaceAll(_ dict: [String: String]) throws {
        try queue.sync {
            // 导入路径：显式允许写空（用户确认过）
            memory = dict
            memoryLoaded = true
            diskCorrupt = false
            try writeVault(memory, force: true)
        }
    }

    /// 当前内存快照（导入回滚用）。
    public func snapshot() -> [String: String] {
        exportAll()
    }

    public var vaultFileURL: URL { vaultURL }

    // MARK: - File

    private func ensureMemoryLoaded() {
        guard !memoryLoaded else { return }
        memory = loadVault()
        memoryLoaded = true
    }

    private func loadVault() -> [String: String] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: vaultURL.path) else {
            diskCorrupt = false
            return [:]
        }
        guard let data = try? Data(contentsOf: vaultURL) else {
            AppLog.error("secrets.vault 无法读取")
            diskCorrupt = true
            return [:]
        }
        // 空文件视为空库
        if data.isEmpty || data == Data("{}".utf8) {
            diskCorrupt = false
            return [:]
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: data)
            guard let dict = obj as? [String: String] else {
                backupCorrupt(data, reason: "JSON 根类型不是对象")
                diskCorrupt = true
                return [:]
            }
            diskCorrupt = false
            return dict
        } catch {
            backupCorrupt(data, reason: error.localizedDescription)
            diskCorrupt = true
            return [:]
        }
    }

    private func backupCorrupt(_ data: Data, reason: String) {
        let bak = vaultURL
            .deletingPathExtension()
            .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).vault")
        try? data.write(to: bak, options: .atomic)
        AppLog.error("secrets.vault 损坏（\(reason)），已备份 \(bak.lastPathComponent)，拒绝静默清空")
    }

    private func writeVault(_ dict: [String: String], force: Bool = false) throws {
        let fm = FileManager.default
        // 损坏且内存为空：禁止把空库写回盖掉磁盘上的坏文件（坏文件已有 .corrupt 备份）
        if !force, diskCorrupt, dict.isEmpty {
            throw SecretStoreError.corruptRefuseEmptyWrite
        }
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: vaultURL, options: [.atomic])
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: vaultURL.path)
        diskCorrupt = false
    }

    public enum SecretStoreError: Error, LocalizedError {
        case ioFailed(String)
        case corruptRefuseEmptyWrite

        public var errorDescription: String? {
            switch self {
            case .ioFailed(let m): "密钥文件错误：\(m)"
            case .corruptRefuseEmptyWrite:
                "密钥库文件损坏，已备份。请从备份导入恢复，拒绝用空库覆盖。"
            }
        }
    }
}
