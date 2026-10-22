import XCTest
@testable import Domain

final class BrowserLoginReminderTests: XCTestCase {
    func testLoginReminderIsDeduplicatedUntilRecovery() {
        let id = UUID()
        var policy = BrowserLoginReminderPolicy()
        let expired = BalanceSnapshot(accountId: id, providerKind: .mimo, displayName: "Fixture", status: .error,
            errorMessage: "login expired", connectionIssue: .loginRequired)
        XCTAssertTrue(policy.shouldRemind(for: expired))
        XCTAssertFalse(policy.shouldRemind(for: expired))
        var networkFailure = expired
        networkFailure.connectionIssue = nil
        networkFailure.errorMessage = "network unavailable"
        XCTAssertFalse(policy.shouldRemind(for: networkFailure))
        XCTAssertFalse(policy.shouldRemind(for: expired))
        let recovered = BalanceSnapshot(accountId: id, providerKind: .mimo, displayName: "Fixture", amount: 10, status: .healthy)
        XCTAssertFalse(policy.shouldRemind(for: recovered))
        XCTAssertTrue(policy.shouldRemind(for: expired))
    }

    func testNetworkErrorsAndNonBrowserProvidersNeverRequestLogin() {
        var policy = BrowserLoginReminderPolicy()
        let network = BalanceSnapshot(accountId: UUID(), providerKind: .bytebroad, displayName: "Fixture", status: .error, errorMessage: "timeout")
        XCTAssertFalse(policy.shouldRemind(for: network))
        let wrongKind = BalanceSnapshot(accountId: UUID(), providerKind: .deepseek, displayName: "Fixture", status: .error,
            errorMessage: "login expired", connectionIssue: .loginRequired)
        XCTAssertFalse(policy.shouldRemind(for: wrongKind))
    }

    func testOldSnapshotDecodesWithoutConnectionIssue() throws {
        let old = BalanceSnapshot(accountId: UUID(), providerKind: .mimo, displayName: "Fixture", amount: 15, status: .healthy)
        let data = try JSONEncoder().encode(old)
        let restored = try JSONDecoder().decode(BalanceSnapshot.self, from: data)
        XCTAssertNil(restored.connectionIssue)
        XCTAssertEqual(restored.amount, 15)
    }

    func testBytebroadCumulativeUsageFeedsExistingDailyStatistics() {
        let id = UUID()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let first = BalanceSnapshot(accountId: id, providerKind: .bytebroad, displayName: "Fixture", amount: 50,
            unit: "¥", used: 10, total: 60, status: .healthy, fetchedAt: start)
        let second = BalanceSnapshot(accountId: id, providerKind: .bytebroad, displayName: "Fixture", amount: 49,
            unit: "¥", used: 11, total: 60, status: .healthy, fetchedAt: start.addingTimeInterval(60))
        let baseline = UsageAccumulator.ingest(snapshots: [first], knownAccountIDs: [id], document: UsageHistoryDocument(), now: start, calendar: calendar)
        let result = UsageAccumulator.ingest(snapshots: [second], knownAccountIDs: [id], document: baseline, now: second.fetchedAt, calendar: calendar)
        XCTAssertEqual(result.dailyRecords.reduce(0) { $0 + $1.providerAmount }, 1, accuracy: 0.0001)
        XCTAssertEqual(result.baselines.first?.method, .providerCumulative)
    }
}
