import XCTest
@testable import Domain

final class BalanceSnapshotTests: XCTestCase {
    func testAmountTiers100_50_20() {
        // 默认：偏低 100 / 不足 50 / 危急 20
        XCTAssertEqual(BalanceSnapshot.resolveStatus(amount: 150, remainingPercent: nil), .healthy)
        XCTAssertEqual(BalanceSnapshot.resolveStatus(amount: 100, remainingPercent: nil), .warning)
        XCTAssertEqual(BalanceSnapshot.resolveStatus(amount: 80, remainingPercent: nil), .warning)
        XCTAssertEqual(BalanceSnapshot.resolveStatus(amount: 50, remainingPercent: nil), .caution)
        XCTAssertEqual(BalanceSnapshot.resolveStatus(amount: 30, remainingPercent: nil), .caution)
        XCTAssertEqual(BalanceSnapshot.resolveStatus(amount: 20, remainingPercent: nil), .critical)
        XCTAssertEqual(BalanceSnapshot.resolveStatus(amount: 5, remainingPercent: nil), .critical)
        XCTAssertEqual(BalanceSnapshot.resolveStatus(amount: 0, remainingPercent: nil), .depleted)
    }

    func testPercentTiers() {
        XCTAssertEqual(BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 50), .healthy)
        XCTAssertEqual(BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 30), .warning)
        XCTAssertEqual(BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 15), .caution)
        XCTAssertEqual(BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 10), .critical)
        XCTAssertEqual(BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 0), .depleted)
    }

    func testWorseOfAmountAndPercent() {
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 1000, remainingPercent: 8),
            .critical
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 30, remainingPercent: 80),
            .caution
        )
    }
}
