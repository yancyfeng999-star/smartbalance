import XCTest
@testable import Domain

/// AppModel.checkForUpdates / applyCheckResult contract: inspect only, never install.
final class UpdateCheckFlowTests: XCTestCase {
    func testApplyCheckResultForAvailableUpdateDoesNotDownloadOrInstall() {
        let decision = UpdateCheckApplyPolicy.decision(for: .available)
        XCTAssertEqual(decision.phase, .available)
        XCTAssertTrue(decision.available)
        XCTAssertTrue(decision.shouldOpenDetails)
        XCTAssertFalse(decision.startsDownload)
        XCTAssertFalse(decision.startsInstall)
    }

    func testApplyCheckResultForUpToDateAndFailedDoesNotDownloadOrInstall() {
        for status in [UpdateCheckStatus.upToDate, .unknown, .failed] {
            let decision = UpdateCheckApplyPolicy.decision(for: status)
            XCTAssertFalse(decision.startsDownload, "\(status) must not download")
            XCTAssertFalse(decision.startsInstall, "\(status) must not install")
            XCTAssertFalse(decision.shouldOpenDetails)
        }
    }

    func testDMGConfirmCopyDoesNotClaimQuitOrReplace() {
        XCTAssertEqual(UpdateInstallConfirmCopy.messageKey(for: .dmg), "update.confirm.open_dmg")
        XCTAssertEqual(UpdateInstallConfirmCopy.confirmActionKey(for: .dmg), "update.action.confirm_open")
        XCTAssertNotEqual(UpdateInstallConfirmCopy.messageKey(for: .dmg), "update.confirm.restart")
        XCTAssertNotEqual(UpdateInstallConfirmCopy.confirmActionKey(for: .dmg), "update.action.confirm")
    }
}
