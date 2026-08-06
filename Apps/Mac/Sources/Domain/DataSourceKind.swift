import Foundation

/// 余额从哪里来。
public enum DataSourceKind: String, Codable, Sendable, CaseIterable {
    /// API 直查 / 手录账号。
    case api
    /// 历史：平台邮件（已移除，仅兼容旧快照）。
    case platformEmail

    public var titleCN: String {
        switch self {
        case .api: "API 查询"
        case .platformEmail: "平台邮件（已停用）"
        }
    }

    public var subtitleCN: String {
        switch self {
        case .api: "用 API Key 拉余额，或手录金额"
        case .platformEmail: "已停用"
        }
    }
}
