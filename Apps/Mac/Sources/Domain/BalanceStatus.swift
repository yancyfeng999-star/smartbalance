import Foundation

/// 余额健康状态（对齐智额状态色语义）。
public enum BalanceStatus: String, Codable, Sendable, CaseIterable {
    case healthy
    case warning
    case critical
    case depleted
    case unknown
    case error
    case setup

    public var titleCN: String {
        switch self {
        case .healthy: "正常"
        case .warning: "偏低"
        case .critical: "危急"
        case .depleted: "耗尽"
        case .unknown: "未知"
        case .error: "失败"
        case .setup: "待配置"
        }
    }
}
