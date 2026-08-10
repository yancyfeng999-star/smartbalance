import XCTest
@testable import Domain

final class UsageAccumulatorTests: XCTestCase {
    private let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let otherAccountID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    func testFirstCumulativeSampleCreatesBaselineOnly() {
        let sampledAt = date(2026, 8, 10, 9)
        let next = ingest([
            snapshot(used: 10, total: 20, amount: 10, fetchedAt: sampledAt),
        ], now: sampledAt)

        XCTAssertEqual(next.baselines.count, 1)
        XCTAssertEqual(next.baselines[0].value, 10)
        XCTAssertEqual(next.baselines[0].method, .providerCumulative)
        XCTAssertEqual(next.baselines[0].unit, "CNY")
        XCTAssertEqual(next.baselines[0].sampledAt, sampledAt)
        XCTAssertTrue(next.dailyRecords.isEmpty)
    }

    func testCumulativeIncreaseAddsProviderAmount() {
        let firstDate = date(2026, 8, 10, 9)
        let first = ingest([
            snapshot(used: 10, total: 20, amount: 10, fetchedAt: firstDate),
        ], now: firstDate)
        let secondDate = date(2026, 8, 10, 12)
        let next = ingest([
            snapshot(used: 13.25, total: 23.25, amount: 10, fetchedAt: secondDate),
        ], document: first, now: secondDate)

        XCTAssertEqual(next.dailyRecords.count, 1)
        XCTAssertEqual(next.dailyRecords[0].providerAmount, 3.25, accuracy: 0.0001)
        XCTAssertEqual(next.dailyRecords[0].estimatedAmount, 0, accuracy: 0.0001)
        XCTAssertEqual(next.dailyRecords[0].sampleCount, 1)
        XCTAssertEqual(next.dailyRecords[0].dayKey, "2026-08-10")
        XCTAssertFalse(next.dailyRecords[0].hasBoundaryGap)
    }

    func testCumulativeDecreaseResetsWithoutConsumption() {
        let first = ingest([
            snapshot(used: 10, total: 20, amount: 10, fetchedAt: date(2026, 8, 10, 9)),
        ], now: date(2026, 8, 10, 9))
        let next = ingest([
            snapshot(used: 2, total: 12, amount: 10, fetchedAt: date(2026, 8, 10, 10)),
        ], document: first, now: date(2026, 8, 10, 10))

        XCTAssertTrue(next.dailyRecords.isEmpty)
        XCTAssertEqual(next.baselines[0].value, 2)
    }

    func testFirstBalanceSampleCreatesEstimatedBaselineOnly() {
        let sampledAt = date(2026, 8, 10, 9)
        let next = ingest([
            snapshot(amount: 100, fetchedAt: sampledAt),
        ], now: sampledAt)

        XCTAssertEqual(next.baselines.count, 1)
        XCTAssertEqual(next.baselines[0].value, 100)
        XCTAssertEqual(next.baselines[0].method, .balanceDeltaEstimate)
        XCTAssertTrue(next.dailyRecords.isEmpty)
    }

    func testBalanceDecreaseAddsEstimatedAmount() {
        let first = ingest([
            snapshot(amount: 100, fetchedAt: date(2026, 8, 10, 9)),
        ], now: date(2026, 8, 10, 9))
        let next = ingest([
            snapshot(amount: 97.5, fetchedAt: date(2026, 8, 10, 10)),
        ], document: first, now: date(2026, 8, 10, 10))

        XCTAssertEqual(next.dailyRecords.count, 1)
        XCTAssertEqual(next.dailyRecords[0].providerAmount, 0, accuracy: 0.0001)
        XCTAssertEqual(next.dailyRecords[0].estimatedAmount, 2.5, accuracy: 0.0001)
        XCTAssertEqual(next.dailyRecords[0].sampleCount, 1)
    }

    func testBalanceIncreaseResetsWithoutNegativeConsumption() {
        let first = ingest([
            snapshot(amount: 100, fetchedAt: date(2026, 8, 10, 9)),
        ], now: date(2026, 8, 10, 9))
        let next = ingest([
            snapshot(amount: 125, fetchedAt: date(2026, 8, 10, 10)),
        ], document: first, now: date(2026, 8, 10, 10))

        XCTAssertTrue(next.dailyRecords.isEmpty)
        XCTAssertEqual(next.baselines[0].value, 125)
    }

    func testNegativeBalanceStillMeasuresDecrease() {
        let first = ingest([
            snapshot(amount: 5, fetchedAt: date(2026, 8, 10, 9)),
        ], now: date(2026, 8, 10, 9))
        let next = ingest([
            snapshot(amount: -2, fetchedAt: date(2026, 8, 10, 10)),
        ], document: first, now: date(2026, 8, 10, 10))

        XCTAssertEqual(next.dailyRecords.count, 1)
        XCTAssertEqual(next.dailyRecords[0].estimatedAmount, 7, accuracy: 0.0001)
        XCTAssertEqual(next.baselines[0].value, -2)
    }

    func testErrorSnapshotDoesNotReplaceBaseline() {
        let firstDate = date(2026, 8, 10, 9)
        let first = ingest([
            snapshot(amount: 100, fetchedAt: firstDate),
        ], now: firstDate)
        let next = ingest([
            snapshot(amount: 20, status: .error, fetchedAt: date(2026, 8, 10, 10)),
        ], document: first, now: date(2026, 8, 10, 10))

        XCTAssertEqual(next.baselines, first.baselines)
        XCTAssertTrue(next.dailyRecords.isEmpty)
    }

    func testUnitProviderAndMethodChangesOnlyResetBaseline() {
        let first = ingest([
            snapshot(amount: 100, fetchedAt: date(2026, 8, 10, 9)),
        ], now: date(2026, 8, 10, 9))
        let changedUnit = ingest([
            snapshot(amount: 90, unit: "USD", fetchedAt: date(2026, 8, 10, 10)),
        ], document: first, now: date(2026, 8, 10, 10))
        let changedProvider = ingest([
            snapshot(provider: .kimi, amount: 80, unit: "USD", fetchedAt: date(2026, 8, 10, 11)),
        ], document: changedUnit, now: date(2026, 8, 10, 11))
        let changedMethod = ingest([
            snapshot(provider: .kimi, used: 6, total: 86, amount: 80, unit: "USD", fetchedAt: date(2026, 8, 10, 12)),
        ], document: changedProvider, now: date(2026, 8, 10, 12))

        XCTAssertTrue(changedMethod.dailyRecords.isEmpty)
        XCTAssertEqual(changedMethod.baselines.count, 1)
        XCTAssertEqual(changedMethod.baselines[0].providerKind, .kimi)
        XCTAssertEqual(changedMethod.baselines[0].unit, "USD")
        XCTAssertEqual(changedMethod.baselines[0].method, .providerCumulative)
        XCTAssertEqual(changedMethod.baselines[0].value, 6)
    }

    func testCrossMidnightDeltaUsesLaterDayAndMarksBoundaryGap() {
        let first = ingest([
            snapshot(amount: 100, fetchedAt: date(2026, 8, 10, 23, 50)),
        ], now: date(2026, 8, 10, 23, 50))
        let next = ingest([
            snapshot(amount: 96, fetchedAt: date(2026, 8, 11, 0, 10)),
        ], document: first, now: date(2026, 8, 11, 0, 10))

        XCTAssertEqual(next.dailyRecords.count, 1)
        XCTAssertEqual(next.dailyRecords[0].dayKey, "2026-08-11")
        XCTAssertEqual(next.dailyRecords[0].estimatedAmount, 4, accuracy: 0.0001)
        XCTAssertTrue(next.dailyRecords[0].hasBoundaryGap)
    }

    func testUnknownAccountsAreIgnoredAndDeletedAccountsLoseBaselines() {
        let sampledAt = date(2026, 8, 10, 9)
        let document = UsageHistoryDocument(
            baselines: [
                UsageBaseline(
                    accountId: accountID,
                    providerKind: .deepseek,
                    unit: "CNY",
                    method: .balanceDeltaEstimate,
                    value: 100,
                    sampledAt: sampledAt
                ),
                UsageBaseline(
                    accountId: otherAccountID,
                    providerKind: .kimi,
                    unit: "CNY",
                    method: .balanceDeltaEstimate,
                    value: 50,
                    sampledAt: sampledAt
                ),
            ],
            dailyRecords: [record(accountID: otherAccountID, dayKey: "2026-08-09")]
        )
        let next = UsageAccumulator.ingest(
            snapshots: [snapshot(accountID: otherAccountID, amount: 40, fetchedAt: sampledAt)],
            knownAccountIDs: [accountID],
            document: document,
            now: sampledAt,
            calendar: calendar
        )

        XCTAssertEqual(next.baselines.map(\.accountId), [accountID])
        XCTAssertEqual(next.dailyRecords.count, 1, "deleting an account keeps historical daily totals")
    }

    func testPrunesRecordsOlderThanFourHundredDays() {
        let now = date(2026, 8, 10, 9)
        let oldestKeptDate = calendar.date(byAdding: .day, value: -399, to: calendar.startOfDay(for: now))!
        let expiredDate = calendar.date(byAdding: .day, value: -400, to: calendar.startOfDay(for: now))!
        let document = UsageHistoryDocument(dailyRecords: [
            record(dayKey: dayKey(for: oldestKeptDate)),
            record(dayKey: dayKey(for: expiredDate)),
        ])

        let next = UsageAccumulator.ingest(
            snapshots: [],
            knownAccountIDs: [accountID],
            document: document,
            now: now,
            calendar: calendar,
            retentionDays: 400
        )

        XCTAssertEqual(next.dailyRecords.map(\.dayKey), [dayKey(for: oldestKeptDate)])
    }

    private func ingest(
        _ snapshots: [BalanceSnapshot],
        document: UsageHistoryDocument = UsageHistoryDocument(),
        now: Date
    ) -> UsageHistoryDocument {
        UsageAccumulator.ingest(
            snapshots: snapshots,
            knownAccountIDs: [accountID],
            document: document,
            now: now,
            calendar: calendar
        )
    }

    private func snapshot(
        accountID: UUID? = nil,
        provider: ProviderKind = .deepseek,
        used: Double? = nil,
        total: Double? = nil,
        amount: Double? = nil,
        unit: String = "¥",
        status: BalanceStatus = .healthy,
        fetchedAt: Date
    ) -> BalanceSnapshot {
        BalanceSnapshot(
            accountId: accountID ?? self.accountID,
            providerKind: provider,
            displayName: provider.displayName,
            amount: amount,
            unit: unit,
            used: used,
            total: total,
            status: status,
            fetchedAt: fetchedAt
        )
    }

    private func record(
        accountID: UUID? = nil,
        dayKey: String,
        providerAmount: Double = 0,
        estimatedAmount: Double = 1
    ) -> UsageDailyRecord {
        UsageDailyRecord(
            dayKey: dayKey,
            timeZoneIdentifier: calendar.timeZone.identifier,
            accountId: accountID ?? self.accountID,
            providerKind: .deepseek,
            unit: "CNY",
            providerAmount: providerAmount,
            estimatedAmount: estimatedAmount,
            sampleCount: 1,
            hasBoundaryGap: false
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }
}
