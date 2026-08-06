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

    /// ≤ 此金额 → 偏低（默认 100）
    public var warningAmount: Double
    /// ≤ 此金额 → 不足（默认 50）
    public var midAmount: Double
    /// ≤ 此金额 → 危急（默认 20）
    public var criticalAmount: Double
    public var warningPercent: Double
    public var midPercent: Double
    public var criticalPercent: Double
    public var cooldownSeconds: Int

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
        midAmount: Double = BalanceTierDefaults.midAmount,
        criticalAmount: Double = BalanceTierDefaults.criticalAmount,
        warningPercent: Double = BalanceTierDefaults.warningPercent,
        midPercent: Double = BalanceTierDefaults.midPercent,
        criticalPercent: Double = BalanceTierDefaults.criticalPercent,
        cooldownSeconds: Int = 3600
    ) {
        self.macNotificationEnabled = macNotificationEnabled
        self.outboundEmailEnabled = outboundEmailEnabled
        self.quotaThresholdAlertsEnabled = quotaThresholdAlertsEnabled
        let ordered = Self.clampAmountTiers(warning: warningAmount, mid: midAmount, critical: criticalAmount)
        self.warningAmount = ordered.w
        self.midAmount = ordered.m
        self.criticalAmount = ordered.c
        let p = Self.clampPercentTiers(warning: warningPercent, mid: midPercent, critical: criticalPercent)
        self.warningPercent = p.w
        self.midPercent = p.m
        self.criticalPercent = p.c
        self.cooldownSeconds = cooldownSeconds
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        macNotificationEnabled = try c.decodeIfPresent(Bool.self, forKey: .macNotificationEnabled) ?? true
        outboundEmailEnabled = try c.decodeIfPresent(Bool.self, forKey: .outboundEmailEnabled) ?? true
        quotaThresholdAlertsEnabled = try c.decodeIfPresent(Bool.self, forKey: .quotaThresholdAlertsEnabled) ?? true
        cooldownSeconds = try c.decodeIfPresent(Int.self, forKey: .cooldownSeconds) ?? 3600

        var w: Double
        if let v = try c.decodeIfPresent(Double.self, forKey: .warningAmount) {
            w = v
        } else if let old = try c.decodeIfPresent(Double.self, forKey: .defaultAmountThreshold) {
            // 旧 10/200 等迁移到新默认 100
            w = (old <= 10 || old == 200) ? BalanceTierDefaults.warningAmount : old
        } else {
            w = BalanceTierDefaults.warningAmount
        }

        let mid: Double
        if let v = try c.decodeIfPresent(Double.self, forKey: .midAmount) {
            mid = v
        } else {
            mid = BalanceTierDefaults.midAmount
        }

        let crit: Double
        if let v = try c.decodeIfPresent(Double.self, forKey: .criticalAmount) {
            crit = v
        } else {
            crit = BalanceTierDefaults.criticalAmount
        }

        let amt = Self.clampAmountTiers(warning: w, mid: mid, critical: crit)
        warningAmount = amt.w
        midAmount = amt.m
        criticalAmount = amt.c

        var wp: Double
        if let v = try c.decodeIfPresent(Double.self, forKey: .warningPercent) {
            wp = v
        } else if let old = try c.decodeIfPresent(Double.self, forKey: .defaultPercentThreshold) {
            wp = old
        } else {
            wp = BalanceTierDefaults.warningPercent
        }
        let mp = try c.decodeIfPresent(Double.self, forKey: .midPercent) ?? BalanceTierDefaults.midPercent
        let cp = try c.decodeIfPresent(Double.self, forKey: .criticalPercent) ?? BalanceTierDefaults.criticalPercent
        let pct = Self.clampPercentTiers(warning: wp, mid: mp, critical: cp)
        warningPercent = pct.w
        midPercent = pct.m
        criticalPercent = pct.c
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(macNotificationEnabled, forKey: .macNotificationEnabled)
        try c.encode(outboundEmailEnabled, forKey: .outboundEmailEnabled)
        try c.encode(quotaThresholdAlertsEnabled, forKey: .quotaThresholdAlertsEnabled)
        try c.encode(warningAmount, forKey: .warningAmount)
        try c.encode(midAmount, forKey: .midAmount)
        try c.encode(criticalAmount, forKey: .criticalAmount)
        try c.encode(warningPercent, forKey: .warningPercent)
        try c.encode(midPercent, forKey: .midPercent)
        try c.encode(criticalPercent, forKey: .criticalPercent)
        try c.encode(cooldownSeconds, forKey: .cooldownSeconds)
        try c.encode(warningAmount, forKey: .defaultAmountThreshold)
        try c.encode(warningPercent, forKey: .defaultPercentThreshold)
    }

    /// 保证 warning ≥ mid ≥ critical > 0
    public static func clampAmountTiers(warning: Double, mid: Double, critical: Double) -> (w: Double, m: Double, c: Double) {
        var vals = [max(1, warning), max(1, mid), max(1, critical)].sorted(by: >)
        if vals[0] == vals[1] { vals[1] = max(1, vals[0] * 0.5) }
        if vals[1] == vals[2] { vals[2] = max(1, vals[1] * 0.4) }
        if vals[2] >= vals[1] { vals[2] = max(1, vals[1] - 1) }
        return (vals[0], vals[1], vals[2])
    }

    public static func clampPercentTiers(warning: Double, mid: Double, critical: Double) -> (w: Double, m: Double, c: Double) {
        var vals = [min(99, max(1, warning)), min(99, max(1, mid)), min(99, max(1, critical))].sorted(by: >)
        if vals[1] >= vals[0] { vals[1] = max(1, vals[0] - 1) }
        if vals[2] >= vals[1] { vals[2] = max(1, vals[1] - 1) }
        return (vals[0], vals[1], vals[2])
    }

    private enum CodingKeys: String, CodingKey {
        case macNotificationEnabled, outboundEmailEnabled, quotaThresholdAlertsEnabled
        case warningAmount, midAmount, criticalAmount
        case warningPercent, midPercent, criticalPercent, cooldownSeconds
        case defaultAmountThreshold, defaultPercentThreshold
    }
}
