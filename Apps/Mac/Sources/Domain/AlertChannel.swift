import Foundation

/// 智余自身如何通知用户（与「平台发来的邮件」不同）。
public enum AlertChannel: String, Codable, CaseIterable, Sendable, Identifiable {
    case macNotification
    case outboundEmail

    public var id: String { rawValue }

    public var titleCN: String {
        switch self {
        case .macNotification: "Mac 通知"
        case .outboundEmail: "邮件报警"
        }
    }

    public var subtitleCN: String {
        switch self {
        case .macNotification: "系统通知中心推送"
        case .outboundEmail: "经 SMTP 发到你的邮箱"
        }
    }
}

/// 报警通道开关与共用阈值。
public struct AlertChannelSettings: Codable, Equatable, Sendable {
    public var macNotificationEnabled: Bool
    public var outboundEmailEnabled: Bool
    /// 主开关：额度阈值报警（金额/百分比低于线时通知）
    public var quotaThresholdAlertsEnabled: Bool
    /// 金额阈值（货币/吉米币等），≤ 此值报警
    public var defaultAmountThreshold: Double
    /// 剩余百分比阈值，≤ 此值报警
    public var defaultPercentThreshold: Double
    public var cooldownSeconds: Int

    public init(
        macNotificationEnabled: Bool = true,
        outboundEmailEnabled: Bool = true,
        quotaThresholdAlertsEnabled: Bool = true,
        defaultAmountThreshold: Double = 10,
        defaultPercentThreshold: Double = 20,
        cooldownSeconds: Int = 3600
    ) {
        self.macNotificationEnabled = macNotificationEnabled
        self.outboundEmailEnabled = outboundEmailEnabled
        self.quotaThresholdAlertsEnabled = quotaThresholdAlertsEnabled
        self.defaultAmountThreshold = defaultAmountThreshold
        self.defaultPercentThreshold = defaultPercentThreshold
        self.cooldownSeconds = cooldownSeconds
    }
}
