import XCTest
@testable import Domain

final class NotificationPermissionStateTests: XCTestCase {
    func testFourSystemStatesMapToNonSensitiveStatuses() {
        let cases: [(NotificationPermissionInput, NotificationAuthorizationState, String)] = [
            (.notDetermined, .notDetermined, "compat.notifications.notDetermined"),
            (.authorized, .authorized, "compat.notifications.authorized"),
            (.denied, .denied, "compat.notifications.denied"),
            (.restricted, .restricted, "compat.notifications.restricted"),
        ]
        for (input, expectedState, expectedKey) in cases {
            let state = NotificationPermissionMapping.state(from: input)
            let status = NotificationPermissionMapping.status(from: state)
            XCTAssertEqual(state, expectedState, "input \(input)")
            XCTAssertEqual(status.state, expectedState)
            XCTAssertEqual(status.messageKey, expectedKey)
            XCTAssertFalse(status.containsSensitivePayload, "status must not carry tokens or device ids")
            XCTAssertFalse(status.messageKey.lowercased().contains("token"))
            XCTAssertFalse(status.messageKey.lowercased().contains("secret"))
            XCTAssertFalse(status.messageKey.contains("@"))
        }
    }

    func testUnauthorizedStatesDoNotBlockBalanceRefresh() {
        let unauthorized: [NotificationAuthorizationState] = [
            .notDetermined,
            .denied,
            .restricted,
            .unknown,
        ]
        for state in unauthorized {
            XCTAssertTrue(
                NotificationPermissionMapping.allowsBalanceRefresh(state),
                "\(state) must not block refresh"
            )
            XCTAssertFalse(NotificationPermissionMapping.status(from: state).blocksBalanceRefresh)
            XCTAssertEqual(
                RefreshAdmissionPolicy.decide(
                    request: RefreshRequest(trigger: .manual),
                    current: .idle,
                    accountCount: 1
                ),
                .started,
                "refresh admission must not consult notification state \(state)"
            )
        }
        XCTAssertTrue(NotificationPermissionMapping.allowsBalanceRefresh(.authorized))
    }

    func testProvisionalAndEphemeralMapWithoutSensitivePayload() {
        XCTAssertEqual(NotificationPermissionMapping.state(from: .provisional), .provisional)
        XCTAssertEqual(NotificationPermissionMapping.state(from: .ephemeral), .authorized)
        let provisional = NotificationPermissionMapping.status(from: .provisional)
        XCTAssertFalse(provisional.containsSensitivePayload)
        XCTAssertFalse(provisional.blocksBalanceRefresh)
        XCTAssertEqual(provisional.messageKey, "compat.notifications.authorized")
    }
}
