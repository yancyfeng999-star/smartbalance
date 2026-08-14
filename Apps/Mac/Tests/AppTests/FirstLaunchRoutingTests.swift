import XCTest
@testable import Domain

final class FirstLaunchRoutingTests: XCTestCase {
    func testFirstRunRoutesToOnboarding() {
        XCTAssertEqual(
            FirstLaunchRouter.route(loadResult: .missing),
            .onboarding
        )
        XCTAssertEqual(FirstLaunchRouter.initialStep(for: .missing), .privacy)
    }

    func testCompletedLaunchDoesNotRepeatOnboarding() {
        let state = FirstLaunchState(
            completedAt: Date(timeIntervalSince1970: 1_787_000_000),
            acknowledgedPrivacy: true
        )
        XCTAssertEqual(
            FirstLaunchRouter.route(loadResult: .loaded(state)),
            .home
        )
        XCTAssertEqual(
            FirstLaunchRouter.route(loadResult: .loaded(state), completedThisSession: false),
            .home
        )
    }

    func testCorruptStateRoutesToCompatibilityAndDoesNotTreatAsEmptySettings() {
        XCTAssertEqual(
            FirstLaunchRouter.route(loadResult: .corrupt),
            .compatibility
        )
        XCTAssertNotEqual(
            FirstLaunchRouter.route(loadResult: .corrupt),
            .onboarding
        )
        XCTAssertNotEqual(
            FirstLaunchRouter.route(loadResult: .corrupt, hasExistingAccounts: true),
            .home
        )
    }

    func testSkippingOptionalNotificationsStillReachesHome() {
        XCTAssertEqual(FirstLaunchRouter.nextStep(after: .privacy), .compatibility)
        XCTAssertEqual(FirstLaunchRouter.nextStep(after: .compatibility), .addProvider)
        XCTAssertEqual(FirstLaunchRouter.nextStep(after: .addProvider), .notifications)
        XCTAssertNil(FirstLaunchRouter.nextStep(after: .notifications))

        XCTAssertEqual(
            FirstLaunchRouter.route(
                loadResult: .missing,
                completedThisSession: true,
                skippedNotifications: true
            ),
            .home
        )

        let finished = FirstLaunchState(
            completedAt: Date(timeIntervalSince1970: 1_787_000_100),
            acknowledgedPrivacy: true
        )
        XCTAssertEqual(
            FirstLaunchRouter.route(
                loadResult: .loaded(finished),
                skippedNotifications: true
            ),
            .home
        )
    }
}
