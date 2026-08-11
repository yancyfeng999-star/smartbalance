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
    private var isAuthenticated = false
    /// 上次认证成功时间，用于缓存避免反复弹窗
    private var lastAuthTime: Date?
    /// 认证成功的上下文，传给 Keychain，避免 Keychain 自己另弹登录钥匙串密码。
    private var authenticationContext: LAContext?
    /// 认证缓存有效期（5分钟）
    private let authCacheDuration: TimeInterval = 300

    public init() {}

    // MARK: - Authentication

    /// 指纹优先；指纹不可用或验证失败后才允许设备登录密码。
    static func authenticationPolicies(biometricsAvailable: Bool) -> [LAPolicy] {
        if biometricsAvailable {
            return [.deviceOwnerAuthenticationWithBiometrics, .deviceOwnerAuthentication]
        }
        return [.deviceOwnerAuthentication]
    }

    /// 请求 Touch ID；Touch ID 不可用或失败后回退到设备登录密码。
    public func authenticate() async -> Bool {
        if queue.sync(execute: { hasValidAuthenticationLocked() }) {
            return true
        }

        let biometricContext = LAContext()
        biometricContext.localizedReason = "使用 Touch ID 解锁智余"
        biometricContext.localizedCancelTitle = "取消"
        biometricContext.localizedFallbackTitle = "使用密码"
        var error: NSError?
        let biometricsAvailable = biometricContext.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )

        for (index, policy) in Self.authenticationPolicies(biometricsAvailable: biometricsAvailable).enumerated() {
            let context: LAContext
            if index == 0, policy == .deviceOwnerAuthenticationWithBiometrics {
                context = biometricContext
            } else {
                context = LAContext()
                context.localizedReason = "使用设备密码解锁智余"
                context.localizedCancelTitle = "取消"
                context.localizedFallbackTitle = "使用密码"
            }

            var policyError: NSError?
            guard context.canEvaluatePolicy(policy, error: &policyError) else {
                continue
            }

            let success = await withCheckedContinuation { continuation in
                context.evaluatePolicy(policy, localizedReason: context.localizedReason) { result, _ in
                    continuation.resume(returning: result)
                }
            }

            if success {
                queue.sync {
                    isAuthenticated = true
                    lastAuthTime = Date()
                    authenticationContext = context
                }
                return true
            }
        }

        AppLog.error("Authentication failed")
        return false
    }

    /// 重置认证状态（锁定后需重新认证）
    public func lock() {
        queue.sync {
            isAuthenticated = false
            lastAuthTime = nil
            authenticationContext = nil
            memory.removeAll()
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
            if let value = memory[account] {
                return value
            }
            guard hasValidAuthenticationLocked() else { return nil }
            guard let value = loadFromKeychain(key: account) else { return nil }
            memory[account] = value
            return value
        }
    }

    public func contains(account: String) -> Bool {
        get(account: account) != nil
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
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        guard let accessControl = makeAccessControl() else {
            throw SecretStoreError.keychainFailed(errSecParam)
        }
        query[kSecAttrAccessControl as String] = accessControl
        addAuthenticationContext(to: &query)

        // 更新旧条目；不存在时再创建，避免先删除造成密钥短暂丢失。
        let identity = identityQuery(key: key)
        var updates: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]
        let updateStatus = SecItemUpdate(identity as CFDictionary, updates as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw SecretStoreError.keychainFailed(updateStatus)
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecretStoreError.keychainFailed(status)
        }
    }

    private func loadFromKeychain(key: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        addAuthenticationContext(to: &query)

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(key: String) {
        let query = identityQuery(key: key)
        SecItemDelete(query as CFDictionary)
    }

    private func identityQuery(key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        addAuthenticationContext(to: &query)
        return query
    }

    private func makeAccessControl() -> SecAccessControl? {
        var error: Unmanaged<CFError>?
        return SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &error
        )
    }

    private func addAuthenticationContext(to query: inout [String: Any]) {
        guard hasValidAuthenticationLocked(), let authenticationContext else { return }
        query[kSecUseAuthenticationContext as String] = authenticationContext
    }

    private func hasValidAuthenticationLocked() -> Bool {
        guard isAuthenticated,
              let lastAuthTime,
              authenticationContext != nil else {
            return false
        }
        if Date().timeIntervalSince(lastAuthTime) >= authCacheDuration {
            isAuthenticated = false
            self.lastAuthTime = nil
            authenticationContext = nil
            return false
        }
        return true
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
