import Foundation
import LocalAuthentication
import Domain

/// 本机密钥库（**不走系统钥匙串**）。
///
/// - 路径：`~/Library/Application Support/SmartBalance/secrets.vault`
/// - 权限：`0600`（仅当前用户）
/// - 会话：首次读密钥时 Touch ID 一次（无指纹则本机密码），之后只走内存
public final class LocalSecretStore: @unchecked Sendable {
    public static let shared = LocalSecretStore()

    private let queue = DispatchQueue(label: "com.smartbalance.secrets")
    private var memory: [String: String] = [:]
    private var sessionUnlocked = false
    private var unlockTask: Task<Void, Error>?
    private let vaultURL: URL

    public init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SmartBalance", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        vaultURL = dir.appendingPathComponent("secrets.vault")
    }

    // MARK: - Session

    public var isSessionUnlocked: Bool {
        queue.sync { sessionUnlocked }
    }

    /// 首次读取密钥前调用；已解锁则立刻返回。
    public func unlockSessionIfNeeded(
        reason: String = "智余需要验证身份以读取本机密钥"
    ) async throws {
        if queue.sync(execute: { sessionUnlocked }) { return }

        if let existing = queue.sync(execute: { unlockTask }) {
            try await existing.value
            return
        }

        let task = Task { try await self.performUnlock(reason: reason) }
        queue.sync { unlockTask = task }
        defer { queue.sync { unlockTask = nil } }
        try await task.value
    }

    private func performUnlock(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        context.localizedFallbackTitle = "使用密码"

        var evalError: NSError?
        let policy: LAPolicy
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &evalError) {
            policy = .deviceOwnerAuthenticationWithBiometrics
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evalError) {
            policy = .deviceOwnerAuthentication
        } else {
            queue.sync {
                memory = loadVault()
                sessionUnlocked = true
            }
            return
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            context.evaluatePolicy(policy, localizedReason: reason) { ok, error in
                if ok {
                    cont.resume()
                } else {
                    cont.resume(throwing: error ?? SecretStoreError.authCanceled)
                }
            }
        }

        queue.sync {
            memory = loadVault()
            sessionUnlocked = true
        }
    }

    public func lockSession() {
        queue.sync {
            sessionUnlocked = false
            memory.removeAll()
        }
    }

    // MARK: - CRUD

    public func set(_ value: String, account: String) throws {
        try queue.sync {
            var disk = loadVault()
            disk[account] = value
            try writeVault(disk)
            memory[account] = value
            sessionUnlocked = true
        }
    }

    public func get(account: String) -> String? {
        queue.sync {
            if let hit = memory[account] { return hit }
            guard sessionUnlocked else { return nil }
            let disk = loadVault()
            if let hit = disk[account] {
                memory[account] = hit
                return hit
            }
            return nil
        }
    }

    public func contains(account: String) -> Bool {
        queue.sync {
            if memory[account] != nil { return true }
            return loadVault()[account] != nil
        }
    }

    public func delete(account: String) {
        queue.sync {
            var disk = loadVault()
            disk.removeValue(forKey: account)
            try? writeVault(disk)
            memory.removeValue(forKey: account)
        }
    }

    // MARK: - File

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
        case authCanceled
        case ioFailed(String)

        public var errorDescription: String? {
            switch self {
            case .authCanceled: "已取消身份验证"
            case .ioFailed(let m): "密钥文件错误：\(m)"
            }
        }
    }
}
