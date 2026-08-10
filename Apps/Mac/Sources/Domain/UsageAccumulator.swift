import Foundation

public enum UsageAccumulator {
    public static func ingest(
        snapshots: [BalanceSnapshot],
        knownAccountIDs: Set<UUID>,
        document: UsageHistoryDocument,
        now: Date,
        calendar: Calendar,
        retentionDays: Int = 400
    ) -> UsageHistoryDocument {
        var next = document
        next.schemaVersion = UsageHistoryDocument.currentSchemaVersion
        next.baselines.removeAll { !knownAccountIDs.contains($0.accountId) }
        pruneRecords(in: &next, now: now, calendar: calendar, retentionDays: retentionDays)

        for snapshot in snapshots.sorted(by: { $0.fetchedAt < $1.fetchedAt }) {
            guard knownAccountIDs.contains(snapshot.accountId),
                  ![BalanceStatus.error, .setup, .unknown].contains(snapshot.status),
                  let providerKind = snapshot.providerKind,
                  let measurement = measurement(for: snapshot)
            else {
                continue
            }

            let unit = UsageUnit.normalize(snapshot.unit)
            let baseline = UsageBaseline(
                accountId: snapshot.accountId,
                providerKind: providerKind,
                unit: unit,
                method: measurement.method,
                value: measurement.value,
                sampledAt: snapshot.fetchedAt
            )

            guard let baselineIndex = next.baselines.firstIndex(where: { $0.accountId == snapshot.accountId }) else {
                next.baselines.append(baseline)
                continue
            }

            let previous = next.baselines[baselineIndex]
            next.baselines[baselineIndex] = baseline

            guard previous.providerKind == providerKind,
                  previous.unit == unit,
                  previous.method == measurement.method
            else {
                continue
            }

            let delta: Double
            switch measurement.method {
            case .providerCumulative:
                delta = measurement.value - previous.value
            case .balanceDeltaEstimate:
                delta = previous.value - measurement.value
            }

            guard delta.isFinite, delta > 0 else { continue }
            merge(
                delta: delta,
                method: measurement.method,
                snapshot: snapshot,
                providerKind: providerKind,
                unit: unit,
                previousSampledAt: previous.sampledAt,
                document: &next,
                calendar: calendar
            )
        }

        next.baselines.sort {
            if $0.accountId != $1.accountId {
                return $0.accountId.uuidString < $1.accountId.uuidString
            }
            return $0.providerKind.rawValue < $1.providerKind.rawValue
        }
        next.dailyRecords.sort {
            if $0.dayKey != $1.dayKey { return $0.dayKey < $1.dayKey }
            if $0.providerKind != $1.providerKind {
                return $0.providerKind.rawValue < $1.providerKind.rawValue
            }
            if $0.accountId != $1.accountId {
                return $0.accountId.uuidString < $1.accountId.uuidString
            }
            return $0.unit < $1.unit
        }
        next.updatedAt = now
        return next
    }

    private static func measurement(
        for snapshot: BalanceSnapshot
    ) -> (method: UsageMeasurementMethod, value: Double)? {
        if let used = snapshot.used,
           let total = snapshot.total,
           used.isFinite,
           total.isFinite,
           used >= 0,
           total > 0 {
            return (.providerCumulative, used)
        }
        if let amount = snapshot.amount, amount.isFinite {
            return (.balanceDeltaEstimate, amount)
        }
        return nil
    }

    private static func merge(
        delta: Double,
        method: UsageMeasurementMethod,
        snapshot: BalanceSnapshot,
        providerKind: ProviderKind,
        unit: String,
        previousSampledAt: Date,
        document: inout UsageHistoryDocument,
        calendar: Calendar
    ) {
        let currentDayKey = dayKey(for: snapshot.fetchedAt, calendar: calendar)
        let crossesDayBoundary = dayKey(for: previousSampledAt, calendar: calendar) != currentDayKey
        let recordIndex = document.dailyRecords.firstIndex {
            $0.dayKey == currentDayKey
                && $0.accountId == snapshot.accountId
                && $0.providerKind == providerKind
                && $0.unit == unit
        }

        if let recordIndex {
            switch method {
            case .providerCumulative:
                document.dailyRecords[recordIndex].providerAmount += delta
            case .balanceDeltaEstimate:
                document.dailyRecords[recordIndex].estimatedAmount += delta
            }
            document.dailyRecords[recordIndex].sampleCount += 1
            document.dailyRecords[recordIndex].hasBoundaryGap =
                document.dailyRecords[recordIndex].hasBoundaryGap || crossesDayBoundary
            return
        }

        document.dailyRecords.append(UsageDailyRecord(
            dayKey: currentDayKey,
            timeZoneIdentifier: calendar.timeZone.identifier,
            accountId: snapshot.accountId,
            providerKind: providerKind,
            unit: unit,
            providerAmount: method == .providerCumulative ? delta : 0,
            estimatedAmount: method == .balanceDeltaEstimate ? delta : 0,
            sampleCount: 1,
            hasBoundaryGap: crossesDayBoundary
        ))
    }

    private static func pruneRecords(
        in document: inout UsageHistoryDocument,
        now: Date,
        calendar: Calendar,
        retentionDays: Int
    ) {
        let daysToKeep = max(1, retentionDays)
        let cutoff = calendar.date(
            byAdding: .day,
            value: -(daysToKeep - 1),
            to: calendar.startOfDay(for: now)
        ) ?? calendar.startOfDay(for: now)
        document.dailyRecords.removeAll { record in
            guard let date = date(for: record.dayKey, calendar: calendar) else { return true }
            return date < cutoff
        }
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
