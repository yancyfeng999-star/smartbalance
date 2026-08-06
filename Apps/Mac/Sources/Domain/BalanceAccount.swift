import Foundation

/// 用户配置的一个可查询账号。
public struct BalanceAccount: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: ProviderKind
    /// 用户自定义显示名（可空，空则用 kind.displayName）。
    public var displayName: String
    public var baseURL: String?
    /// Keychain 引用键；真实密钥不落盘。
    public var secretRef: String
    public var enabled: Bool
    /// 货币金额阈值（低于则报警）；nil 表示用全局默认。
    public var alertThreshold: Double?
    /// 百分比阈值（0–100），适用于 quota 型；nil 用全局。
    public var alertPercentThreshold: Double?

    public init(
        id: UUID = UUID(),
        kind: ProviderKind,
        displayName: String = "",
        baseURL: String? = nil,
        secretRef: String = UUID().uuidString,
        enabled: Bool = true,
        alertThreshold: Double? = nil,
        alertPercentThreshold: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName.isEmpty ? kind.displayName : displayName
        self.baseURL = baseURL ?? kind.defaultBaseURL
        self.secretRef = secretRef
        self.enabled = enabled
        self.alertThreshold = alertThreshold
        self.alertPercentThreshold = alertPercentThreshold
    }

    public var title: String {
        displayName.isEmpty ? kind.displayName : displayName
    }
}
