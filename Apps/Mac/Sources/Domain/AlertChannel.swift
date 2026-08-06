import Foundation

/// 智余自身如何通知用户。
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

/// 报警通道开关与分档阈值。
public struct AlertChannelSettings: Codable, Equatable, Sendable {
    public var macNotificationEnabled: Bool
    public var outboundEmailEnabled: Bool
    public var quotaThresholdAlertsEnabled: Bool

    /// 金额 ≤ 此值 → 偏低（人民币）
    public var warningAmount: Double
    /// 金额 ≤ 此值 → 危急（人民币，应 ≤ warning）
    public var criticalAmount: Double
    /// 剩余 % ≤ 此值 → 偏低
    public var warningPercent: Double
    /// 剩余 % ≤ 此值 → 危急
    public var criticalPercent: Double
    public var cooldownSeconds: Int

    /// 兼容旧字段名
    public var defaultAmountThreshold: Double {
        get { warningAmount }
        set { warningAmount = newValue }
    }

    public var defaultPercentThreshold: Double {
        get { warningPercent }
        set { warningPercent = newValue }
    }

    public init(
        macNotificationEnabled: Bool = true,
        outboundEmailEnabled: Bool = true,
        quotaThresholdAlertsEnabled: Bool = true,
        warningAmount: Double = BalanceTierDefaults.warningAmount,
        criticalAmount: Double = BalanceTierDefaults.criticalAmount,
        warningPercent: Double = BalanceTierDefaults.warningPercent,
        criticalPercent: Double = BalanceTierDefaults.criticalPercent,
        cooldownSeconds: Int = 3600
    ) {
        self.macNotificationEnabled = macNotificationEnabled
        self.outboundEmailEnabled = outboundEmailEnabled
        self.quotaThresholdAlertsEnabled = quotaThresholdAlertsEnabled
        self.warningAmount = warningAmount
        self.criticalAmount = min(criticalAmount, warningAmount)
        self.warningPercent = warningPercent
        self.criticalPercent = min(criticalPercent, warningPercent)
        self.cooldownSeconds = cooldownSeconds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        macNotificationEnabled = try c.decodeIfPresent(Bool.self, forKey: .macNotificationEnabled) ?? true
        outboundEmailEnabled = try c.decodeIfPresent(Bool.self, forKey: .outboundEmailEnabled) ?? true
        quotaThresholdAlertsEnabled = try c.decodeIfPresent(Bool.self, forKey: .quotaThresholdAlertsEnabled) ?? true
        cooldownSeconds = try c.decodeIfPresent(Int.self, forKey: .cooldownSeconds) ?? 3600

        // 新字段优先；否则从旧 defaultAmountThreshold 迁移
        if let w = try c.decodeIfPresent(Double.self, forKey: .warningAmount) {
            warningAmount = w
        } else if let old = try c.decodeIfPresent(Double.self, forKey: .defaultAmountThreshold) {
            // 旧默认 10 太严，若用户仍是 10 则升到新默认 200
            warningAmount = old <= 10 ? BalanceTierDefaults.warningAmount : old
        } else {
            warningAmount = BalanceTierDefaults.warningAmount
        }

        if let crit = try c.decodeIfPresent(Double.self, forKey: .criticalAmount) {
            criticalAmount = min(crit, warningAmount)
        } else {
            criticalAmount = min(BalanceTierDefaults.criticalAmount, warningAmount)
        }

        if let wp = try c.decodeIfPresent(Double.self, forKey: .warningPercent) {
            warningPercent = wp
        } else if let old = try c.decodeIfPresent(Double.self, forKey: .defaultPercentThreshold) {
            warningPercent = old
        } else {
            warningPercent = BalanceTierDefaults.warningPercent
        }

        if let cp = try c.decodeIfPresent(Double.self, forKey: .criticalPercent) {
            criticalPercent = min(cp, warningPercent)
        } else {
            criticalPercent = min(BalanceTierDefaults.criticalPercent, warningPercent)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(macNotificationEnabled, forKey: .macNotificationEnabled)
        try c.encode(outboundEmailEnabled, forKey: .outboundEmailEnabled)
        try c.encode(quotaThresholdAlertsEnabled, forKey: .quotaThresholdAlertsEnabled)
        try c.encode(warningAmount, forKey: .warningAmount)
        try c.encode(criticalAmount, forKey: .criticalAmount)
        try c.encode(warningPercent, forKey: .warningPercent)
        try c.encode(criticalPercent, forKey: .criticalPercent)
        try c.encode(cooldownSeconds, forKey: .cooldownSeconds)
        // 旧字段双写，便于回滚
        try c.encode(warningAmount, forKey: .defaultAmountThreshold)
        try c.encode(warningPercent, forKey: .defaultPercentThreshold)
    }

    private enum CodingKeys: String, CodingKey {
        case macNotificationEnabled, outboundEmailEnabled, quotaThresholdAlertsEnabled
        case warningAmount, criticalAmount, warningPercent, criticalPercent, cooldownSeconds
        case defaultAmountThreshold, defaultPercentThreshold
    }
}
