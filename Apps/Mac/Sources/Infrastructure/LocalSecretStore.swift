import Foundation
import Domain
import Security

/// 本机密钥库（普通 Keychain 存储）。
///
/// - 不调用生物识别或设备用户认证 API
/// - 不使用 SecAccessControl，避免启动时 Touch ID / 登录钥匙串密码弹窗
/// - 使用新的 service 命名空间，避免读取旧版带访问控制的 Keychain 条目
public final class LocalSecretStore: @unchecked Sendable {
    public static let shared = LocalSecretStore()

    private let queue = DispatchQueue(label: "com.smartbalance.secrets")
    /// 旧版 service 的条目带有生物识别访问控制，不能在无弹窗模式下安全读取。
    private let service = "com.smartbalance.zhiyu.plain"
    private var memory: [String: String] = [:]
    private var inaccessibleAccounts: Set<String> = []
    private var lookupCounts: [String: Int] = [:]
    private var availabilityCache: DiagnosticKeychainStatus?

    public init() {
        KeychainInteractionPolicy.disableSystemPrompts()
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
            if inaccessibleAccounts.contains(account) {
                return nil
            }
            if let value = memory[account] {
                return value
            }
            lookupCounts[account, default: 0] += 1
            guard let value = loadFromKeychain(key: account) else { return nil }
            memory[account] = value
            return value
        }
    }

    public func contains(account: String) -> Bool {
        get(account: account) != nil
    }

    /// 只回答凭据是否缺失，不返回密钥值。
    public func credentialPresence(for account: String) -> CredentialPresence {
        contains(account: account) ? .present : .missing
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

    /// 非敏感可达性：只返回 available / unavailable / unknown。
    public func availabilityStatus() -> DiagnosticKeychainStatus {
        queue.sync {
            if let availabilityCache { return availabilityCache }
            let status = probeAvailability()
            availabilityCache = status
            return status
        }
    }

    func recordNonInteractiveDenialForTesting(account: String) {
        queue.sync { inaccessibleAccounts.insert(account) }
    }

    func keychainLookupCountForTesting(account: String) -> Int {
        queue.sync { lookupCounts[account] ?? 0 }
    }

    // MARK: - Keychain

    private func saveToKeychain(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw SecretStoreError.encodingFailed
        }

        let identity = identityQuery(key: key)
        let updateStatus = SecItemUpdate(
            identity as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            inaccessibleAccounts.remove(key)
            return
        }
        if KeychainInteractionPolicy.shouldTreatAsInaccessible(updateStatus) {
            inaccessibleAccounts.insert(key)
            throw SecretStoreError.keychainFailed(updateStatus)
        }
        guard updateStatus == errSecItemNotFound else {
            throw SecretStoreError.keychainFailed(updateStatus)
        }

        var query = identity
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            if KeychainInteractionPolicy.shouldTreatAsInaccessible(status) {
                inaccessibleAccounts.insert(key)
            }
            throw SecretStoreError.keychainFailed(status)
        }
        inaccessibleAccounts.remove(key)
    }

    private func loadFromKeychain(key: String) -> String? {
        var query = identityQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if KeychainInteractionPolicy.shouldTreatAsInaccessible(status) {
            inaccessibleAccounts.insert(key)
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(key: String) {
        _ = SecItemDelete(identityQuery(key: key) as CFDictionary)
        inaccessibleAccounts.remove(key)
    }

    private func probeAvailability() -> DiagnosticKeychainStatus {
        KeychainInteractionPolicy.disableSystemPrompts()
        let account = "smartbalance.availability-probe"
        let payload = Data("probe".utf8)
        var base = KeychainInteractionPolicy.baseQuery(service: service, account: account)
        KeychainInteractionPolicy.applyNoPrompt(&base)

        var add = base
        add[kSecValueData as String] = payload
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
            if addStatus == errSecNotAvailable
                || KeychainInteractionPolicy.shouldTreatAsInaccessible(addStatus) {
                return .unavailable
            }
            return .unknown
        }

        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let copyStatus = SecItemCopyMatching(query as CFDictionary, &result)
        if copyStatus == errSecSuccess, result as? Data == payload {
            return .available
        }
        if KeychainInteractionPolicy.shouldTreatAsInaccessible(copyStatus) {
            return .unavailable
        }
        return .unknown
    }

    private func identityQuery(key: String) -> [String: Any] {
        var query = KeychainInteractionPolicy.baseQuery(service: service, account: key)
        KeychainInteractionPolicy.applyNoPrompt(&query)
        return query
    }

    public enum SecretStoreError: Error, LocalizedError {
        case encodingFailed
        case keychainFailed(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .encodingFailed:
                "密钥编码失败"
            case .keychainFailed(let status):
                "Keychain 操作失败: \(status)"
            }
        }
    }
}
