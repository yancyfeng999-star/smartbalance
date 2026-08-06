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

    /// 多档状态（人民币金额 + 可选剩余百分比）。
    ///
    /// 金额档（默认）：
    /// - 耗尽 ≤ 0
    /// - 危急 ≤ criticalAmount（默认 50）
    /// - 偏低 ≤ warningAmount（默认 200）
    /// - 充足 > warningAmount
    ///
    /// 百分比档（有 remainingPercent 时与金额取「更差」的一档）：
    /// - 耗尽 ≤ 0
    /// - 危急 ≤ criticalPercent（默认 10）
    /// - 偏低 ≤ warningPercent（默认 30）
    /// - 充足 > warningPercent
    public static func resolveStatus(
        amount: Double?,
        remainingPercent: Double?,
        warningAmount: Double = BalanceTierDefaults.warningAmount,
        criticalAmount: Double = BalanceTierDefaults.criticalAmount,
        warningPercent: Double = BalanceTierDefaults.warningPercent,
        criticalPercent: Double = BalanceTierDefaults.criticalPercent
    ) -> BalanceStatus {
        let byAmount = statusByAmount(
            amount,
            warning: warningAmount,
            critical: criticalAmount
        )
        let byPercent = statusByPercent(
            remainingPercent,
            warning: warningPercent,
            critical: criticalPercent
        )
        return worse(byAmount, byPercent)
    }

    /// 兼容旧调用：`amountThreshold`≈偏低线，危急=偏低×0.25（至少 1）
    public static func resolveStatus(
        amount: Double?,
        remainingPercent: Double?,
        amountThreshold: Double,
        percentThreshold: Double
    ) -> BalanceStatus {
        let warning = max(1, amountThreshold)
        let critical = max(1, min(warning * 0.25, warning - 1))
        let warnPct = max(1, percentThreshold)
        let critPct = max(1, min(warnPct * 0.5, warnPct - 1))
        return resolveStatus(
            amount: amount,
            remainingPercent: remainingPercent,
            warningAmount: warning,
            criticalAmount: critical,
            warningPercent: warnPct,
            criticalPercent: critPct
        )
    }

    private static func statusByAmount(_ amount: Double?, warning: Double, critical: Double) -> BalanceStatus? {
        guard let amount else { return nil }
        let w = max(critical, warning)
        let c = min(critical, warning)
        if amount <= 0 { return .depleted }
        if amount <= c { return .critical }
        if amount <= w { return .warning }
        return .healthy
    }

    private static func statusByPercent(_ pct: Double?, warning: Double, critical: Double) -> BalanceStatus? {
        guard let pct else { return nil }
        let w = max(critical, warning)
        let c = min(critical, warning)
        if pct <= 0 { return .depleted }
        if pct <= c { return .critical }
        if pct <= w { return .warning }
        return .healthy
    }

    /// 取更差档：耗尽 > 危急 > 偏低 > 充足 > 未知
    private static func worse(_ a: BalanceStatus?, _ b: BalanceStatus?) -> BalanceStatus {
        let rank: (BalanceStatus) -> Int = {
            switch $0 {
            case .depleted: 5
            case .critical: 4
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
    /// 低于此为「偏低」
    public static let warningAmount: Double = 200
    /// 低于此为「危急」
    public static let criticalAmount: Double = 50
    /// 剩余 % 低于此为「偏低」
    public static let warningPercent: Double = 30
    /// 剩余 % 低于此为「危急」
    public static let criticalPercent: Double = 10
}
