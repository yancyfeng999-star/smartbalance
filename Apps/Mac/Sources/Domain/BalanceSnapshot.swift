import Foundation

/// 一次查询得到的余额快照。
public struct BalanceSnapshot: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var accountId: UUID
    public var providerKind: ProviderKind?
    public var displayName: String
    public var source: DataSourceKind
    public var amount: Double?
    public var unit: String
    public var used: Double?
    public var total: Double?
    public var remainingPercent: Double?
    public var status: BalanceStatus
    public var detail: String
    public var fetchedAt: Date
    public var errorMessage: String?
    public var mailSubject: String?

    public init(
        id: UUID = UUID(),
        accountId: UUID,
        providerKind: ProviderKind? = nil,
        displayName: String,
        source: DataSourceKind = .api,
        amount: Double? = nil,
        unit: String = "",
        used: Double? = nil,
        total: Double? = nil,
        remainingPercent: Double? = nil,
        status: BalanceStatus = .unknown,
        detail: String = "",
        fetchedAt: Date = Date(),
        errorMessage: String? = nil,
        mailSubject: String? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.providerKind = providerKind
        self.displayName = displayName
        self.source = source
        self.amount = amount
        self.unit = unit
        self.used = used
        self.total = total
        self.remainingPercent = remainingPercent
        self.status = status
        self.detail = detail
        self.fetchedAt = fetchedAt
        self.errorMessage = errorMessage
        self.mailSubject = mailSubject
    }

    public var primaryText: String {
        if let amount {
            if unit == "¥" || unit == "￥" {
                return String(format: "¥%.2f", amount)
            }
            if unit == "USD" || unit == "$" {
                return String(format: "$%.2f", amount)
            }
            return String(format: "%.2f %@", amount, unit)
        }
        if let remainingPercent {
            return String(format: "%.0f%%", remainingPercent)
        }
        return "—"
    }

    public var sourceBadgeCN: String { source.titleCN }

    /// 金额四档 + 百分比（取更差）：
    /// - 充足 > warning
    /// - 偏低 ≤ warning（默认 100）
    /// - 不足 ≤ mid（默认 50）
    /// - 危急 ≤ critical（默认 20）
    /// - 耗尽 ≤ 0
    public static func resolveStatus(
        amount: Double?,
        remainingPercent: Double?,
        warningAmount: Double = BalanceTierDefaults.warningAmount,
        midAmount: Double = BalanceTierDefaults.midAmount,
        criticalAmount: Double = BalanceTierDefaults.criticalAmount,
        warningPercent: Double = BalanceTierDefaults.warningPercent,
        midPercent: Double = BalanceTierDefaults.midPercent,
        criticalPercent: Double = BalanceTierDefaults.criticalPercent
    ) -> BalanceStatus {
        let byAmount = statusByAmount(
            amount,
            warning: warningAmount,
            mid: midAmount,
            critical: criticalAmount
        )
        let byPercent = statusByPercent(
            remainingPercent,
            warning: warningPercent,
            mid: midPercent,
            critical: criticalPercent
        )
        return worse(byAmount, byPercent)
    }

    /// 兼容旧双阈值 API
    public static func resolveStatus(
        amount: Double?,
        remainingPercent: Double?,
        amountThreshold: Double,
        percentThreshold: Double
    ) -> BalanceStatus {
        let warning = max(1, amountThreshold)
        let mid = max(1, min(warning * 0.5, warning - 1))
        let critical = max(1, min(warning * 0.2, mid - 1))
        let warnPct = max(1, percentThreshold)
        let midPct = max(1, min(warnPct * 0.5, warnPct - 1))
        let critPct = max(1, min(warnPct * 0.33, midPct - 1))
        return resolveStatus(
            amount: amount,
            remainingPercent: remainingPercent,
            warningAmount: warning,
            midAmount: mid,
            criticalAmount: critical,
            warningPercent: warnPct,
            midPercent: midPct,
            criticalPercent: critPct
        )
    }

    private static func orderedThresholds(_ a: Double, _ b: Double, _ c: Double) -> (Double, Double, Double) {
        let sorted = [a, b, c].sorted(by: >)
        return (sorted[0], sorted[1], sorted[2])
    }

    private static func statusByAmount(
        _ amount: Double?,
        warning: Double,
        mid: Double,
        critical: Double
    ) -> BalanceStatus? {
        guard let amount else { return nil }
        let (w, m, c) = orderedThresholds(warning, mid, critical)
        if amount <= 0 { return .depleted }
        if amount <= c { return .critical }
        if amount <= m { return .caution }
        if amount <= w { return .warning }
        return .healthy
    }

    private static func statusByPercent(
        _ pct: Double?,
        warning: Double,
        mid: Double,
        critical: Double
    ) -> BalanceStatus? {
        guard let pct else { return nil }
        let (w, m, c) = orderedThresholds(warning, mid, critical)
        if pct <= 0 { return .depleted }
        if pct <= c { return .critical }
        if pct <= m { return .caution }
        if pct <= w { return .warning }
        return .healthy
    }

    private static func worse(_ a: BalanceStatus?, _ b: BalanceStatus?) -> BalanceStatus {
        let rank: (BalanceStatus) -> Int = {
            switch $0 {
            case .depleted: 6
            case .critical: 5
            case .caution: 4
            case .warning: 3
            case .error: 2
            case .setup: 1
            case .unknown: 0
            case .healthy: -1
            }
        }
        switch (a, b) {
        case (nil, nil): return .unknown
        case (let x?, nil): return x
        case (nil, let y?): return y
        case (let x?, let y?):
            return rank(x) >= rank(y) ? x : y
        }
    }
}

/// 默认分档（人民币）。
public enum BalanceTierDefaults: Sendable {
    /// 偏低线
    public static let warningAmount: Double = 100
    /// 不足线（中间档）
    public static let midAmount: Double = 50
    /// 危急线
    public static let criticalAmount: Double = 20
    public static let warningPercent: Double = 30
    public static let midPercent: Double = 15
    public static let criticalPercent: Double = 10
}
