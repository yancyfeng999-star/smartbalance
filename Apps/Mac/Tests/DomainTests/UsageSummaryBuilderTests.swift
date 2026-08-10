import XCTest
@testable import Domain

final class UsageSummaryBuilderTests: XCTestCase {
    private let accountA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let accountB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    func testDayIntervalUsesLocalMidnight() {
        let interval = UsageSummaryBuilder.interval(
            for: .day,
            anchor: date(2026, 8, 10, 15, 30),
            calendar: calendar
        )

        XCTAssertEqual(interval.start, date(2026, 8, 10))
        XCTAssertEqual(interval.end, date(2026, 8, 11))
    }

    func testWeekIntervalStartsMonday() {
        let interval = UsageSummaryBuilder.interval(
            for: .week,
            anchor: date(2026, 8, 12, 15),
            calendar: calendar
        )

        XCTAssertEqual(interval.start, date(2026, 8, 10))
        XCTAssertEqual(interval.end, date(2026, 8, 17))
    }

    func testMonthIntervalHandlesLeapFebruary() {
        let interval = UsageSummaryBuilder.interval(
            for: .month,
            anchor: date(2024, 2, 12),
            calendar: calendar
        )

        XCTAssertEqual(interval.start, date(2024, 2, 1))
        XCTAssertEqual(interval.end, date(2024, 3, 1))
        XCTAssertEqual(calendar.dateComponents([.day], from: interval.start, to: interval.end).day, 29)
    }

    func testShiftedAnchorMovesOneNaturalPeriod() {
        XCTAssertEqual(
            UsageSummaryBuilder.shiftedAnchor(date(2026, 8, 10), period: .day, offset: -1, calendar: calendar),
            date(2026, 8, 9)
        )
        XCTAssertEqual(
            UsageSummaryBuilder.shiftedAnchor(date(2026, 8, 10), period: .week, offset: 1, calendar: calendar),
            date(2026, 8, 17)
        )
        XCTAssertEqual(
            UsageSummaryBuilder.shiftedAnchor(date(2026, 8, 10), period: .month, offset: 1, calendar: calendar),
            date(2026, 9, 10)
        )
    }

    func testFutureAnchorIsClampedToCurrentPeriod() {
        let now = date(2026, 8, 10, 15)
        let clamped = UsageSummaryBuilder.clampedAnchor(
            date(2026, 8, 14),
            period: .day,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(
            UsageSummaryBuilder.interval(for: .day, anchor: clamped, calendar: calendar).start,
            date(2026, 8, 10)
        )
        XCTAssertFalse(
            UsageSummaryBuilder.canMoveForward(
                period: .day,
                anchor: date(2026, 8, 14),
                now: now,
                calendar: calendar
            )
        )
    }

    func testGroupsProviderAccountsWithinCurrency() {
        let summary = build(records: [
            record(dayKey: "2026-08-10", accountID: accountA, provider: .deepseek, providerAmount: 10),
            record(dayKey: "2026-08-10", accountID: accountB, provider: .deepseek, estimatedAmount: 4),
        ])

        XCTAssertEqual(summary.currencies.count, 1)
        XCTAssertEqual(summary.currencies[0].totalAmount, 14, accuracy: 0.0001)
        XCTAssertEqual(summary.currencies[0].providers.count, 1)
        XCTAssertEqual(summary.currencies[0].providers[0].accountCount, 2)
        XCTAssertEqual(summary.currencies[0].providers[0].quality, .mixed)
    }

    func testSeparatesCNYUSDAndUnknownUnits() {
        let summary = build(records: [
            record(dayKey: "2026-08-10", accountID: accountA, provider: .deepseek, unit: "CNY", providerAmount: 10),
            record(dayKey: "2026-08-10", accountID: accountB, provider: .kimi, unit: "CNY", estimatedAmount: 4),
            record(dayKey: "2026-08-10", accountID: accountA, provider: .openrouter, unit: "USD", providerAmount: 3),
            record(dayKey: "2026-08-10", accountID: accountB, provider: .newapi, unit: "credits", providerAmount: 2),
        ])

        XCTAssertEqual(summary.currencies.map(\.unit), ["CNY", "USD", "credits"])
        XCTAssertEqual(summary.currencies[0].totalAmount, 14, accuracy: 0.0001)
        XCTAssertEqual(summary.currencies[1].totalAmount, 3, accuracy: 0.0001)
        XCTAssertEqual(summary.currencies[2].totalAmount, 2, accuracy: 0.0001)
    }

    func testQualityIsProviderEstimatedOrMixed() {
        let summary = build(records: [
            record(dayKey: "2026-08-10", accountID: accountA, provider: .deepseek, providerAmount: 10),
            record(dayKey: "2026-08-10", accountID: accountA, provider: .kimi, estimatedAmount: 4),
            record(dayKey: "2026-08-10", accountID: accountA, provider: .openrouter, providerAmount: 2, estimatedAmount: 1),
        ])
        let qualityByProvider = Dictionary(
            uniqueKeysWithValues: summary.currencies[0].providers.map { ($0.providerKind, $0.quality) }
        )

        XCTAssertEqual(qualityByProvider[.deepseek], .provider)
        XCTAssertEqual(qualityByProvider[.kimi], .estimated)
        XCTAssertEqual(qualityByProvider[.openrouter], .mixed)
    }

    func testWeekAndMonthTotalsEqualDailyPointSum() {
        let document = history(records: [
            record(dayKey: "2026-08-10", providerAmount: 2),
            record(dayKey: "2026-08-11", estimatedAmount: 4),
        ])

        for period in [UsagePeriod.week, .month] {
            let summary = UsageSummaryBuilder.build(
                document: document,
                period: period,
                anchor: date(2026, 8, 12),
                calendar: calendar
            )
            let currency = try! XCTUnwrap(summary.currencies.first)
            XCTAssertEqual(currency.totalAmount, 6, accuracy: 0.0001)
            XCTAssertEqual(currency.dailyPoints.reduce(0) { $0 + $1.amount }, 6, accuracy: 0.0001)
        }
    }

    func testMissingDaysAreZeroFilledForCharts() {
        let summary = UsageSummaryBuilder.build(
            document: history(records: [record(dayKey: "2026-08-12", providerAmount: 5)]),
            period: .week,
            anchor: date(2026, 8, 12),
            calendar: calendar
        )
        let points = summary.currencies[0].dailyPoints

        XCTAssertEqual(points.count, 7)
        XCTAssertEqual(points.map(\.dayKey), [
            "2026-08-10", "2026-08-11", "2026-08-12", "2026-08-13",
            "2026-08-14", "2026-08-15", "2026-08-16",
        ])
        XCTAssertEqual(points.filter { $0.amount == 0 }.count, 6)
        XCTAssertEqual(points.first { $0.dayKey == "2026-08-12" }?.amount, 5)
    }

    func testHistoricalNavigationStopsAtEarliestDay() {
        let document = history(records: [record(dayKey: "2026-08-10", providerAmount: 5)])
        let earliestSummary = UsageSummaryBuilder.build(
            document: document,
            period: .day,
            anchor: date(2026, 8, 10),
            calendar: calendar
        )
        let laterSummary = UsageSummaryBuilder.build(
            document: document,
            period: .day,
            anchor: date(2026, 8, 11),
            calendar: calendar
        )

        XCTAssertFalse(
            UsageSummaryBuilder.canMoveBackward(
                summary: earliestSummary,
                period: .day,
                anchor: date(2026, 8, 10),
                calendar: calendar
            )
        )
        XCTAssertTrue(
            UsageSummaryBuilder.canMoveBackward(
                summary: laterSummary,
                period: .day,
                anchor: date(2026, 8, 11),
                calendar: calendar
            )
        )
    }

    private func build(records: [UsageDailyRecord]) -> UsageDashboardSummary {
        UsageSummaryBuilder.build(
            document: history(records: records),
            period: .day,
            anchor: date(2026, 8, 10, 15),
            calendar: calendar
        )
    }

    private func history(records: [UsageDailyRecord]) -> UsageHistoryDocument {
        UsageHistoryDocument(
            baselines: [UsageBaseline(
                accountId: accountA,
                providerKind: .deepseek,
                unit: "CNY",
                method: .providerCumulative,
                value: 20,
                sampledAt: date(2026, 8, 10, 8)
            )],
            dailyRecords: records,
            updatedAt: date(2026, 8, 10, 15)
        )
    }

    private func record(
        dayKey: String,
        accountID: UUID? = nil,
        provider: ProviderKind = .deepseek,
        unit: String = "CNY",
        providerAmount: Double = 0,
        estimatedAmount: Double = 0
    ) -> UsageDailyRecord {
        UsageDailyRecord(
            dayKey: dayKey,
            timeZoneIdentifier: calendar.timeZone.identifier,
            accountId: accountID ?? accountA,
            providerKind: provider,
            unit: unit,
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
}
