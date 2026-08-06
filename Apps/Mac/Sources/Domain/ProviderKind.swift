import Foundation

/// 内置 Provider 种类。
public enum ProviderKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case deepseek
    case newapi
    case openrouter
    /// ViralTok / 吉米（Jimmy AI）OpenAPI 账户余额
    case viraltok

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .deepseek: "DeepSeek"
        case .newapi: "New-API 中转"
        case .openrouter: "OpenRouter"
        case .viraltok: "ViralTok（吉米）"
        }
    }

    public var defaultBaseURL: String? {
        switch self {
        case .deepseek: "https://api.deepseek.com"
        case .newapi: nil
        case .openrouter: "https://openrouter.ai/api/v1"
        case .viraltok: "https://api.viraltok.ai"
        }
    }

    public var credentialHintCN: String {
        switch self {
        case .deepseek: "填写 DeepSeek API Key（sk-…）"
        case .newapi: "填写站点 Base URL 与 Access Token"
        case .openrouter: "填写 OpenRouter API Key（sk-or-…）"
        case .viraltok: "填写 ViralTok / 吉米 API Key"
        }
    }

    public var needsBaseURL: Bool {
        switch self {
        case .deepseek: false
        case .newapi: true
        case .openrouter: false
        case .viraltok: false
        }
    }
}
