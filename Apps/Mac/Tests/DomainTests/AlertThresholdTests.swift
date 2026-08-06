import XCTest
@testable import Domain

final class AlertThresholdTests: XCTestCase {
    func testCustomTiers() {
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(
                amount: 80,
                remainingPercent: nil,
                warningAmount: 100,
                criticalAmount: 40
            ),
            .warning
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(
                amount: 30,
                remainingPercent: nil,
                warningAmount: 100,
                criticalAmount: 40
            ),
            .critical
        )
    }

    func testLegacyAmountThresholdAPI() {
        // 旧 API：threshold=10 → warning=10, critical≈2.5
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 15, remainingPercent: nil, amountThreshold: 10, percentThreshold: 20),
            .healthy
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 8, remainingPercent: nil, amountThreshold: 10, percentThreshold: 20),
            .warning
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 2, remainingPercent: nil, amountThreshold: 10, percentThreshold: 20),
            .critical
        )
    }

    func testAlertChannelMigrationFromOldDefault10() throws {
        // 旧设置 defaultAmountThreshold=10 → 解码后升到 200
        let json = """
        {"macNotificationEnabled":true,"outboundEmailEnabled":true,"quotaThresholdAlertsEnabled":true,"defaultAmountThreshold":10,"defaultPercentThreshold":20,"cooldownSeconds":3600}
        """.data(using: .utf8)!
        let ch = try JSONDecoder().decode(AlertChannelSettings.self, from: json)
        XCTAssertEqual(ch.warningAmount, BalanceTierDefaults.warningAmount)
        XCTAssertEqual(ch.criticalAmount, BalanceTierDefaults.criticalAmount)
    }
}
