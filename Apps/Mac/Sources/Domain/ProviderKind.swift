import Foundation

/// 内置 Provider 种类。
public enum ProviderKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case deepseek
    case newapi
    case openrouter
    /// ViralTok / 吉米（Jimmy AI）OpenAPI 账户余额
    case viraltok
    /// 老张 API（系统 AccessToken，非模型 Key）
    case laozhang
    /// DMXAPI（系统访问令牌 + 用户 ID）
    case dmxapi
    /// Kimi / Moonshot 开放平台余额
    case kimi
    /// 火山引擎费用中心（AK/SK · QueryBalanceAcct）
    case volcengine
    /// 小米 MiMo：无公开余额 API → 手动录入 + 每日提醒
    case mimo
    /// MiniMax：钱包无公开 API → 手动录入 + 每日提醒
    case minimax

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .deepseek: "DeepSeek"
        case .newapi: "New-API 中转"
        case .openrouter: "OpenRouter"
        case .viraltok: "ViralTok（吉米）"
        case .laozhang: "老张 API"
        case .dmxapi: "DMXAPI"
        case .kimi: "Kimi（月之暗面）"
        case .volcengine: "火山引擎"
        case .mimo: "小米 MiMo（手录）"
        case .minimax: "MiniMax（手录）"
        }
    }

    public var defaultBaseURL: String? {
        switch self {
        case .deepseek: "https://api.deepseek.com"
        case .newapi: nil
        case .openrouter: "https://openrouter.ai/api/v1"
        case .viraltok: "https://api.viraltok.ai"
        case .laozhang: "https://api2.laozhang.ai"
        case .dmxapi: "https://www.dmxapi.cn"
        case .kimi: "https://api.moonshot.cn"
        case .volcengine: "https://console.volcengine.com/finance/account-overview/"
        case .mimo: "https://platform.xiaomimimo.com/console/balance"
        case .minimax: "https://platform.minimaxi.com/user-center/payment/balance"
        }
    }

    /// 无公开余额 API，靠用户手录 + 每日提醒。
    public var isManualEntry: Bool {
        switch self {
        case .mimo, .minimax: true
        default: false
        }
    }

    public var needsSecret: Bool { !isManualEntry }

    /// 火山引擎等：需要 Access Key ID + Secret Access Key 两段凭证。
    public var needsAccessKeyPair: Bool {
        switch self {
        case .volcengine: true
        default: false
        }
    }

    public var credentialHintCN: String {
        switch self {
        case .deepseek: "填写 DeepSeek API Key（sk-…）"
        case .newapi: "系统访问令牌（非模型 sk-）"
        case .openrouter: "填写 OpenRouter API Key（sk-or-…）"
        case .viraltok: "填写 ViralTok / 吉米 API Key"
        case .laozhang: "填写系统令牌 AccessToken（非模型 sk-）"
        case .dmxapi: "填写系统访问令牌（非模型 sk-）"
        case .kimi: "填写 Kimi / Moonshot API Key（sk-…）"
        case .volcengine: "Secret Access Key（访问控制 → 密钥管理）"
        case .mimo, .minimax: "无需 Key · 每天提醒后手录金额"
        }
    }

    public var accessKeyIdHintCN: String {
        switch self {
        case .volcengine: "Access Key ID（AK）"
        default: "Access Key ID"
        }
    }

    public var needsBaseURL: Bool {
        switch self {
        case .newapi: true
        default: false
        }
    }

    public var needsUserId: Bool {
        switch self {
        // New-API / DMXAPI：/api/user/self 需系统令牌 + 用户 ID 头
        case .newapi, .dmxapi: true
        default: false
        }
    }

    public var userIdHintCN: String {
        switch self {
        case .newapi: "用户 ID（个人中心，填 New-API-User）"
        case .dmxapi: "用户 ID（个人资料页）"
        default: "用户 ID"
        }
    }

    public var defaultManualUnit: String {
        switch self {
        // 吉米币 / 老张 USD 在 Provider 内已折算为人民币再展示
        case .mimo, .minimax, .deepseek, .kimi, .dmxapi, .volcengine, .viraltok, .laozhang: "¥"
        case .openrouter, .newapi: "USD"
        }
    }
}
