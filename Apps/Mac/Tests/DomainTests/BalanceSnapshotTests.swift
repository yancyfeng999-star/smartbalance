import XCTest
@testable import Domain

final class BalanceSnapshotTests: XCTestCase {
    func testAmountTiersDefaultCNY() {
        // 默认：偏低 200 / 危急 50
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 500, remainingPercent: nil),
            .healthy
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 200, remainingPercent: nil),
            .warning
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 100, remainingPercent: nil),
            .warning
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 50, remainingPercent: nil),
            .critical
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 10, remainingPercent: nil),
            .critical
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 0, remainingPercent: nil),
            .depleted
        )
    }

    func testPercentTiers() {
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 50),
            .healthy
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 30),
            .warning
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 10),
            .critical
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 0),
            .depleted
        )
    }

    func testWorseOfAmountAndPercent() {
        // 金额充足但百分比危急 → 危急
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 1000, remainingPercent: 8),
            .critical
        )
        // 金额危急但百分比充足 → 危急
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 30, remainingPercent: 80),
            .critical
        )
    }
}
