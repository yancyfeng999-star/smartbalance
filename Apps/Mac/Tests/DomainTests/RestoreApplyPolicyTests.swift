import XCTest
@testable import Domain

final class RestoreApplyPolicyTests: XCTestCase {
    func testUsageInclusiveRestoreDoesNotResetBaselines() {
        XCTAssertFalse(RestoreApplyPolicy.shouldResetUsageBaselines(includedUsage: true))
        XCTAssertTrue(RestoreApplyPolicy.shouldResetUsageBaselines(includedUsage: false))
    }

    func testCancelInvalidatesInFlightRestoreToken() {
        var session = RestoreSession()
        let token = session.begin()
        XCTAssertTrue(session.isCurrent(token))
        session.cancel()
        XCTAssertFalse(session.isCurrent(token))
        let next = session.begin()
        XCTAssertTrue(session.isCurrent(next))
        XCTAssertFalse(session.isCurrent(token))
    }
}