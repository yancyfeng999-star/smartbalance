import XCTest
@testable import Domain

final class BalanceSnapshotTests: XCTestCase {
    func testResolveStatusByAmount() {
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 100, remainingPercent: nil, amountThreshold: 10, percentThreshold: 20),
            .healthy
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 8, remainingPercent: nil, amountThreshold: 10, percentThreshold: 20),
            .warning
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 3, remainingPercent: nil, amountThreshold: 10, percentThreshold: 20),
            .critical
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: 0, remainingPercent: nil, amountThreshold: 10, percentThreshold: 20),
            .depleted
        )
    }

    func testResolveStatusByPercent() {
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 50, amountThreshold: 10, percentThreshold: 20),
            .healthy
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 15, amountThreshold: 10, percentThreshold: 20),
            .warning
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 5, amountThreshold: 10, percentThreshold: 20),
            .critical
        )
    }

    func testPrimaryTextCurrency() {
        let snap = BalanceSnapshot(
            accountId: UUID(),
            providerKind: .deepseek,
            displayName: "DS",
            source: .api,
            amount: 12.5,
            unit: "¥"
        )
        XCTAssertEqual(snap.primaryText, "¥12.50")
    }
}
