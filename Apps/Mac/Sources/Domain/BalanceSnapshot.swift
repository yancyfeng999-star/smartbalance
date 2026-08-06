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
    /// 来自平台邮件时的 Message-ID / 主题摘要。
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

    public static func resolveStatus(
        amount: Double?,
        remainingPercent: Double?,
        amountThreshold: Double,
        percentThreshold: Double
    ) -> BalanceStatus {
        if let remainingPercent {
            if remainingPercent <= 0 { return .depleted }
            if remainingPercent <= percentThreshold * 0.5 { return .critical }
            if remainingPercent <= percentThreshold { return .warning }
            return .healthy
        }
        if let amount {
            if amount <= 0 { return .depleted }
            if amount <= amountThreshold * 0.5 { return .critical }
            if amount <= amountThreshold { return .warning }
            return .healthy
        }
        return .unknown
    }
}
