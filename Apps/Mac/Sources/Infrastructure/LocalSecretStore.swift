import Foundation
import Domain
import Security
import LocalAuthentication

/// 本机密钥库（Keychain + 生物识别/密码保护）。
///
/// - 路径：系统 Keychain
/// - 安全策略：使用 kSecAttrAccessibleWhenUnlockedThisDeviceOnly
/// - 生物识别：访问时需 Touch ID / Face ID / 用户密码
public final class LocalSecretStore: @unchecked Sendable {
    public static let shared = LocalSecretStore()

    private let queue = DispatchQueue(label: "com.smartbalance.secrets")
    private let service = "com.smartbalance.zhiyu"
    private var memory: [String: String] = [:]
    private var memoryLoaded = false
    private var isAuthenticated = false

    public init() {}

    // MARK: - Authentication

    /// 请求生物识别认证
    public func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedReason = "解锁智余以访问 API 密钥"
        context.localizedCancelTitle = "取消"
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // 如果生物识别不可用，回退到密码
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                AppLog.error("Authentication not available: \(error?.localizedDescription ?? "Unknown")")
                return false
            }
            return await withCheckedContinuation { continuation in
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "解锁智余以访问 API 密钥") { success, error in
                    if !success {
                        AppLog.error("Authentication failed: \(error?.localizedDescription ?? "Unknown")")
                    }
                    continuation.resume(returning: success)
                }
            }
        }
        
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "解锁智余以访问 API 密钥") { success, error in
                if !success {
                    AppLog.error("Biometric authentication failed: \(error?.localizedDescription ?? "Unknown")")
                }
                continuation.resume(returning: success)
            }
        }
    }

    // MARK: - CRUD

    public func set(_ value: String, account: String) throws {
        try queue.sync {
            try saveToKeychain(key: account, value: value)
            memory[account] = value
        }
    }

    public func get(account: String) -> String? {
        queue.sync {
            if let value = loadFromKeychain(key: account) {
                return value
            }
            return memory[account]
        }
    }

    public func contains(account: String) -> Bool {
        queue.sync {
            return get(account: account) != nil
        }
    }

    public func delete(account: String) {
        queue.sync {
            deleteFromKeychain(key: account)
            memory.removeValue(forKey: account)
        }
    }

    /// 导出全部密钥（备份用）。
    public func exportAll() -> [String: String] {
        queue.sync {
            return memory
        }
    }

    /// 整库替换（导入备份）。
    public func replaceAll(_ dict: [String: String]) throws {
        try queue.sync {
            for (key, value) in dict {
                try saveToKeychain(key: key, value: value)
            }
            memory = dict
            memoryLoaded = true
        }
    }

    /// 当前内存快照（导入回滚用）。
    public func snapshot() -> [String: String] {
        exportAll()
    }

    // MARK: - Keychain

    private func saveToKeychain(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw SecretStoreError.encodingFailed
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 先删除旧条目
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecretStoreError.keychainFailed(status)
        }
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    private func ensureMemoryLoaded() {
        guard !memoryLoaded else { return }
        // 从 Keychain 加载所有条目
        memory = loadAllFromKeychain()
        memoryLoaded = true
    }
    
    private func loadAllFromKeychain() -> [String: String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return [:]
        }
        
        var dict: [String: String] = [:]
        for item in items {
            guard let key = item[kSecAttrAccount as String] as? String,
                  let data = item[kSecValueData as String] as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                continue
            }
            dict[key] = value
        }
        
        return dict
    }

    public enum SecretStoreError: Error, LocalizedError {
        case ioFailed(String)
        case encodingFailed
        case keychainFailed(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .ioFailed(let m): "密钥文件错误：\(m)"
            case .encodingFailed: "密钥编码失败"
            case .keychainFailed(let status): "Keychain 操作失败: \(status)"
            }
        }
    }
}
