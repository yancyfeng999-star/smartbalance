import Foundation

public enum UsagePeriod: String, CaseIterable, Codable, Sendable {
    case day
    case week
    case month
}

public enum UsageMeasurementMethod: String, Codable, Sendable, Hashable {
    case providerCumulative
    case balanceDeltaEstimate
}

public enum UsageQuality: String, Codable, Sendable {
    case provider
    case estimated
    case mixed
}

public struct UsageBaseline: Codable, Equatable, Sendable {
    public var accountId: UUID
    public var providerKind: ProviderKind
    public var unit: String
    public var method: UsageMeasurementMethod
    public var value: Double
    public var sampledAt: Date
    public var sampleCount: Int

    public init(
        accountId: UUID,
        providerKind: ProviderKind,
        unit: String,
        method: UsageMeasurementMethod,
        value: Double,
        sampledAt: Date,
        sampleCount: Int = 1
    ) {
        self.accountId = accountId
        self.providerKind = providerKind
        self.unit = unit
        self.method = method
        self.value = value
        self.sampledAt = sampledAt
        self.sampleCount = sampleCount
    }

    private enum CodingKeys: String, CodingKey {
        case accountId
        case providerKind
        case unit
        case method
        case value
        case sampledAt
        case sampleCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountId = try container.decode(UUID.self, forKey: .accountId)
        providerKind = try container.decode(ProviderKind.self, forKey: .providerKind)
        unit = try container.decode(String.self, forKey: .unit)
        method = try container.decode(UsageMeasurementMethod.self, forKey: .method)
        value = try container.decode(Double.self, forKey: .value)
        sampledAt = try container.decode(Date.self, forKey: .sampledAt)
        sampleCount = try container.decodeIfPresent(Int.self, forKey: .sampleCount) ?? 1
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(providerKind, forKey: .providerKind)
        try container.encode(unit, forKey: .unit)
        try container.encode(method, forKey: .method)
        try container.encode(value, forKey: .value)
        try container.encode(sampledAt, forKey: .sampledAt)
        try container.encode(sampleCount, forKey: .sampleCount)
    }
}

public struct UsageDailyRecord: Codable, Equatable, Sendable, Identifiable {
    public var dayKey: String
    public var timeZoneIdentifier: String
    public var accountId: UUID
    public var providerKind: ProviderKind
    public var unit: String
    public var providerAmount: Double
    public var estimatedAmount: Double
    public var sampleCount: Int
    public var hasBoundaryGap: Bool

    public var id: String {
        "\(dayKey)|\(accountId.uuidString)|\(providerKind.rawValue)|\(unit)"
    }

    public init(
        dayKey: String,
        timeZoneIdentifier: String,
        accountId: UUID,
        providerKind: ProviderKind,
        unit: String,
        providerAmount: Double,
        estimatedAmount: Double,
        sampleCount: Int,
        hasBoundaryGap: Bool
    ) {
        self.dayKey = dayKey
        self.timeZoneIdentifier = timeZoneIdentifier
        self.accountId = accountId
        self.providerKind = providerKind
        self.unit = unit
        self.providerAmount = providerAmount
        self.estimatedAmount = estimatedAmount
        self.sampleCount = sampleCount
        self.hasBoundaryGap = hasBoundaryGap
    }
}

public struct UsageHistoryDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var baselines: [UsageBaseline]
    public var dailyRecords: [UsageDailyRecord]
    public var updatedAt: Date?

    public init(
        schemaVersion: Int = UsageHistoryDocument.currentSchemaVersion,
        baselines: [UsageBaseline] = [],
        dailyRecords: [UsageDailyRecord] = [],
        updatedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.baselines = baselines
        self.dailyRecords = dailyRecords
        self.updatedAt = updatedAt
    }
}

public enum UsageUnit {
    public static func normalize(_ unit: String) -> String {
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.uppercased() {
        case "¥", "￥", "CNY":
            return "CNY"
        case "$", "USD":
            return "USD"
        default:
            return trimmed
        }
    }

    public static func symbol(for unit: String) -> String {
        switch normalize(unit) {
        case "CNY": return "¥"
        case "USD": return "$"
        default: return normalize(unit)
        }
    }
}

public struct UsageDailyPoint: Identifiable, Equatable, Sendable {
    public var dayKey: String
    public var date: Date
    public var amount: Double
    public var quality: UsageQuality?

    public var id: String { dayKey }
    public var includesEstimate: Bool { quality == .estimated || quality == .mixed }

    public init(dayKey: String, date: Date, amount: Double, quality: UsageQuality?) {
        self.dayKey = dayKey
        self.date = date
        self.amount = amount
        self.quality = quality
    }
}

public struct UsageProviderSummary: Identifiable, Equatable, Sendable {
    public var providerKind: ProviderKind
    public var unit: String
    public var totalAmount: Double
    public var providerAmount: Double
    public var estimatedAmount: Double
    public var accountCount: Int
    public var quality: UsageQuality

    public var id: String { "\(providerKind.rawValue)|\(unit)" }

    public init(
        providerKind: ProviderKind,
        unit: String,
        totalAmount: Double,
        providerAmount: Double,
        estimatedAmount: Double,
        accountCount: Int,
        quality: UsageQuality
    ) {
        self.providerKind = providerKind
        self.unit = unit
        self.totalAmount = totalAmount
        self.providerAmount = providerAmount
        self.estimatedAmount = estimatedAmount
        self.accountCount = accountCount
        self.quality = quality
    }
}

public struct UsageCurrencySummary: Identifiable, Equatable, Sendable {
    public var unit: String
    public var totalAmount: Double
    public var providers: [UsageProviderSummary]
    public var dailyPoints: [UsageDailyPoint]

    public var id: String { unit }

    public init(
        unit: String,
        totalAmount: Double,
        providers: [UsageProviderSummary],
        dailyPoints: [UsageDailyPoint]
    ) {
        self.unit = unit
        self.totalAmount = totalAmount
        self.providers = providers
        self.dailyPoints = dailyPoints
    }
}

public struct UsageDashboardSummary: Equatable, Sendable {
    public var period: UsagePeriod
    public var interval: DateInterval
    public var currencies: [UsageCurrencySummary]
    public var hasAnyBaseline: Bool
    public var hasAnyFollowUpSample: Bool
    public var hasBoundaryGap: Bool
    public var earliestDayKey: String?
    public var updatedAt: Date?

    public init(
        period: UsagePeriod,
        interval: DateInterval,
        currencies: [UsageCurrencySummary],
        hasAnyBaseline: Bool,
        hasAnyFollowUpSample: Bool,
        hasBoundaryGap: Bool,
        earliestDayKey: String?,
        updatedAt: Date?
    ) {
        self.period = period
        self.interval = interval
        self.currencies = currencies
        self.hasAnyBaseline = hasAnyBaseline
        self.hasAnyFollowUpSample = hasAnyFollowUpSample
        self.hasBoundaryGap = hasBoundaryGap
        self.earliestDayKey = earliestDayKey
        self.updatedAt = updatedAt
    }
}
