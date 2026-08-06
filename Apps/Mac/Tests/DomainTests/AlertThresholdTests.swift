import XCTest
@testable import Domain

final class AlertThresholdTests: XCTestCase {
    func testCustomTiers() {
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(
                amount: 80,
                remainingPercent: nil,
                warningAmount: 100,
                midAmount: 50,
                criticalAmount: 20
            ),
            .warning
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(
                amount: 40,
                remainingPercent: nil,
                warningAmount: 100,
                midAmount: 50,
                criticalAmount: 20
            ),
            .caution
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(
                amount: 15,
                remainingPercent: nil,
                warningAmount: 100,
                midAmount: 50,
                criticalAmount: 20
            ),
            .critical
        )
    }

    func testStatusTitles() {
        XCTAssertEqual(BalanceStatus.healthy.titleCN, "充足")
        XCTAssertEqual(BalanceStatus.warning.titleCN, "偏低")
        XCTAssertEqual(BalanceStatus.caution.titleCN, "不足")
        XCTAssertEqual(BalanceStatus.critical.titleCN, "危急")
    }
}
