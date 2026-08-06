import Foundation

/// Provider 查询所需凭据（由 Infrastructure 从 Keychain 组装）。
public struct ProviderCredentials: Sendable {
    public var apiKey: String
    public var baseURL: String?

    public init(apiKey: String, baseURL: String? = nil) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
}

/// 平台余额查询协议。
public protocol BalanceProvider: Sendable {
    var kind: ProviderKind { get }
    func fetchBalance(account: BalanceAccount, credentials: ProviderCredentials) async throws -> BalanceSnapshot
}

public enum BalanceProviderError: Error, LocalizedError, Sendable {
    case missingCredential
    case invalidURL
    case httpStatus(Int, String)
    case decodeFailed(String)
    case providerMessage(String)

    public var errorDescription: String? {
        switch self {
        case .missingCredential: "缺少 API 密钥"
        case .invalidURL: "Base URL 无效"
        case .httpStatus(let code, let body): "HTTP \(code): \(body.prefix(200))"
        case .decodeFailed(let msg): "解析失败: \(msg)"
        case .providerMessage(let msg): msg
        }
    }
}
