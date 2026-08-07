import Foundation

/// 余额健康状态。
public enum BalanceStatus: String, Codable, Sendable, CaseIterable {
    case healthy
    /// 偏低（默认 ≤ ¥100）
    case warning
    /// 不足（默认 ≤ ¥50，介于偏低与危急之间）
    case caution
    /// 危急（默认 ≤ ¥20）
    case critical
    case depleted
    case unknown
    case error
    case setup

    public var titleCN: String {
        switch self {
        case .healthy: "充足"
        case .warning: "偏低"
        case .caution: "不足"
        case .critical: "危急"
        case .depleted: "耗尽"
        case .unknown: "…"
        case .error: "失败"
        case .setup: "待配置"
        }
    }
}
