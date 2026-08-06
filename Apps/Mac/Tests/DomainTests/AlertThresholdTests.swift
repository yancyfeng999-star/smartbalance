import XCTest
@testable import Domain

final class AlertThresholdTests: XCTestCase {
    func testAmountMatrix() {
        let cases: [(Double, BalanceStatus)] = [
            (100, .healthy),
            (10, .warning),   // == threshold → warning
            (5, .critical),   // <= threshold*0.5
            (0, .depleted),
        ]
        for (amount, expected) in cases {
            let s = BalanceSnapshot.resolveStatus(
                amount: amount, remainingPercent: nil,
                amountThreshold: 10, percentThreshold: 20
            )
            XCTAssertEqual(s, expected, "amount \(amount)")
        }
    }

    func testPercentMatrix() {
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 50, amountThreshold: 10, percentThreshold: 20),
            .healthy
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 20, amountThreshold: 10, percentThreshold: 20),
            .warning
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 10, amountThreshold: 10, percentThreshold: 20),
            .critical
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 0, amountThreshold: 10, percentThreshold: 20),
            .depleted
        )
    }
}
