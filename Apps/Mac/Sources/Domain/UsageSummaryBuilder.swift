import Foundation

public enum UsageSummaryBuilder {
    public static func interval(
        for period: UsagePeriod,
        anchor: Date,
        calendar: Calendar
    ) -> DateInterval {
        let calendar = period == .week ? isoCalendar(using: calendar) : calendar
        let component: Calendar.Component = switch period {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
        if let interval = calendar.dateInterval(of: component, for: anchor) {
            return interval
        }

        let start = calendar.startOfDay(for: anchor)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? anchor
        return DateInterval(start: start, end: end)
    }

    public static func shiftedAnchor(
        _ anchor: Date,
        period: UsagePeriod,
        offset: Int,
        calendar: Calendar
    ) -> Date {
        let component: Calendar.Component = switch period {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
        let calendar = period == .week ? isoCalendar(using: calendar) : calendar
        return calendar.date(byAdding: component, value: offset, to: anchor) ?? anchor
    }

    public static func clampedAnchor(
        _ anchor: Date,
        period: UsagePeriod,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let target = interval(for: period, anchor: anchor, calendar: calendar)
        let current = interval(for: period, anchor: now, calendar: calendar)
        return target.start > current.start ? now : anchor
    }

    public static func build(
        document: UsageHistoryDocument,
        period: UsagePeriod,
        anchor: Date,
        calendar: Calendar
    ) -> UsageDashboardSummary {
        let selectedInterval = interval(for: period, anchor: anchor, calendar: calendar)
        let records = document.dailyRecords.filter { record in
            guard let date = date(for: record.dayKey, calendar: calendar) else { return false }
            return date >= selectedInterval.start && date < selectedInterval.end
        }
        let units = Set(records.map { UsageUnit.normalize($0.unit) })
        let currencies = units.map { unit in
            currencySummary(
                unit: unit,
                records: records.filter { UsageUnit.normalize($0.unit) == unit },
                interval: selectedInterval,
                calendar: calendar
            )
        }.sorted(by: currencySort)

        return UsageDashboardSummary(
            period: period,
            interval: selectedInterval,
            currencies: currencies,
            hasAnyBaseline: !document.baselines.isEmpty,
            hasBoundaryGap: records.contains(where: \.hasBoundaryGap),
            earliestDayKey: document.dailyRecords.map(\.dayKey).min(),
            updatedAt: document.updatedAt
        )
    }

    public static func canMoveBackward(
        summary: UsageDashboardSummary,
        period: UsagePeriod,
        anchor: Date,
        calendar: Calendar
    ) -> Bool {
        guard let earliestDayKey = summary.earliestDayKey,
              let earliestDate = date(for: earliestDayKey, calendar: calendar)
        else {
            return false
        }
        let selectedStart = interval(for: period, anchor: anchor, calendar: calendar).start
        let earliestStart = interval(for: period, anchor: earliestDate, calendar: calendar).start
        return selectedStart > earliestStart
    }

    public static func canMoveForward(
        period: UsagePeriod,
        anchor: Date,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let selectedStart = interval(for: period, anchor: anchor, calendar: calendar).start
        let currentStart = interval(for: period, anchor: now, calendar: calendar).start
        return selectedStart < currentStart
    }

    private static func currencySummary(
        unit: String,
        records: [UsageDailyRecord],
        interval: DateInterval,
        calendar: Calendar
    ) -> UsageCurrencySummary {
        let providerGroups = Dictionary(grouping: records, by: \.providerKind)
        let providers = providerGroups.map { providerKind, records in
            let providerAmount = records.reduce(0) { $0 + $1.providerAmount }
            let estimatedAmount = records.reduce(0) { $0 + $1.estimatedAmount }
            return UsageProviderSummary(
                providerKind: providerKind,
                unit: unit,
                totalAmount: providerAmount + estimatedAmount,
                providerAmount: providerAmount,
                estimatedAmount: estimatedAmount,
                accountCount: Set(records.map(\.accountId)).count,
                quality: quality(providerAmount: providerAmount, estimatedAmount: estimatedAmount)
            )
        }.sorted {
            if $0.totalAmount != $1.totalAmount { return $0.totalAmount > $1.totalAmount }
            return $0.providerKind.displayName < $1.providerKind.displayName
        }

        let byDay = Dictionary(grouping: records, by: \.dayKey)
        var dailyPoints: [UsageDailyPoint] = []
        var day = interval.start
        while day < interval.end {
            let key = dayKey(for: day, calendar: calendar)
            let dayRecords = byDay[key] ?? []
            dailyPoints.append(UsageDailyPoint(
                dayKey: key,
                date: day,
                amount: dayRecords.reduce(0) { $0 + $1.providerAmount + $1.estimatedAmount },
                includesEstimate: dayRecords.contains { $0.estimatedAmount > 0 }
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }

        return UsageCurrencySummary(
            unit: unit,
            totalAmount: providers.reduce(0) { $0 + $1.totalAmount },
            providers: providers,
            dailyPoints: dailyPoints
        )
    }

    private static func quality(providerAmount: Double, estimatedAmount: Double) -> UsageQuality {
        if providerAmount > 0, estimatedAmount > 0 { return .mixed }
        if estimatedAmount > 0 { return .estimated }
        return .provider
    }

    private static func currencySort(
        _ lhs: UsageCurrencySummary,
        _ rhs: UsageCurrencySummary
    ) -> Bool {
        func rank(_ unit: String) -> Int {
            switch unit {
            case "CNY": return 0
            case "USD": return 1
            default: return 2
            }
        }
        let lhsRank = rank(lhs.unit)
        let rhsRank = rank(rhs.unit)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return lhs.unit < rhs.unit
    }

    private static func isoCalendar(using calendar: Calendar) -> Calendar {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        iso.firstWeekday = 2
        iso.minimumDaysInFirstWeek = 4
        return iso
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func date(for dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: parts[0],
            month: parts[1],
            day: parts[2]
        ))
    }
}
