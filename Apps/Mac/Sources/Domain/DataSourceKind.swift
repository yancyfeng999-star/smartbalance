import Foundation

/// 余额从哪里来。
public enum DataSourceKind: String, Codable, Sendable, CaseIterable {
    /// 大多数平台：API 直接查询。
    case api
    /// 不支持实时查询的平台：解析其固定发来的余额/报警邮件。
    case platformEmail

    public var titleCN: String {
        switch self {
        case .api: "API 查询"
        case .platformEmail: "平台邮件"
        }
    }

    public var subtitleCN: String {
        switch self {
        case .api: "用 API Key 直接拉余额（多数平台）"
        case .platformEmail: "读平台固定发件邮箱发来的余额/报警信"
        }
    }
}
