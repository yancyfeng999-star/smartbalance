import XCTest
@testable import Domain

final class MenuNavigationTests: XCTestCase {
    func testPrimaryNavigationIsHomeUsageSettingsOnly() {
        XCTAssertEqual(
            MenuNavigationPolicy.primaryDestinations,
            [.home, .usage, .settings]
        )
        XCTAssertEqual(Set(PrimaryNavDestination.allCases), [.home, .usage, .settings])
        XCTAssertFalse(MenuNavigationPolicy.isPrimary(.diagnostics))
        XCTAssertFalse(MenuNavigationPolicy.isPrimary(.help))
        XCTAssertTrue(MenuNavigationPolicy.isPrimary(.home))
        XCTAssertEqual(MenuNavigationPolicy.destination(for: .openSettings), .settings)
        XCTAssertEqual(MenuNavigationPolicy.destination(for: .openUsage), .usage)
        XCTAssertEqual(MenuNavigationPolicy.destination(for: .openHome), .home)
    }

    func testSupportPagesAreReachedFromSettingsOrErrorBanners() {
        let fromSettings = MenuNavigationPolicy.entryPoints(for: .help)
        let fromBanner = MenuNavigationPolicy.entryPoints(for: .diagnostics)
        XCTAssertTrue(fromSettings.contains(.settings))
        XCTAssertTrue(fromBanner.contains(.errorBanner) || fromBanner.contains(.settings))
        XCTAssertFalse(MenuNavigationPolicy.entryPoints(for: .help).contains(.primaryTab))
        XCTAssertFalse(MenuNavigationPolicy.entryPoints(for: .diagnostics).contains(.primaryTab))

        var state = MenuNavState(primary: .home)
        state = MenuNavigationPolicy.apply(.openSettings, to: state)
        XCTAssertEqual(state.primary, .settings)
        XCTAssertNil(state.support)
        state = MenuNavigationPolicy.apply(.openHelp, to: state)
        XCTAssertEqual(state.primary, .settings)
        XCTAssertEqual(state.support, .help)
        state = MenuNavigationPolicy.apply(.openDiagnostics, to: state)
        XCTAssertEqual(state.support, .diagnostics)
        XCTAssertEqual(state.primary, .settings)
    }

    func testDetailHeadersDoNotReuseSettingsCopyForUsageOrSupport() {
        XCTAssertEqual(MenuNavigationPolicy.headerTitleKey(for: .home), "home.title")
        XCTAssertEqual(MenuNavigationPolicy.headerTitleKey(for: .usage), "usage.title")
        XCTAssertEqual(MenuNavigationPolicy.headerTitleKey(for: .settings), "settings.title")
        XCTAssertEqual(MenuNavigationPolicy.headerTitleKey(for: .diagnostics), "diagnostics.title")
        XCTAssertEqual(MenuNavigationPolicy.headerTitleKey(for: .help), "help.title")
        XCTAssertEqual(MenuNavigationPolicy.headerTitleKey(for: .troubleshooting), "help.topic.title")
        XCTAssertEqual(MenuNavigationPolicy.headerTitleKey(for: .transfer), "settings.transfer.title")
        XCTAssertEqual(MenuNavigationPolicy.headerTitleKey(for: .backup), "settings.backup.title")
        XCTAssertEqual(MenuNavigationPolicy.headerTitleKey(for: .updates), "update.details.title")
        XCTAssertEqual(MenuNavigationPolicy.headerTitleKey(for: .restorePreview), "restore.preview.title")

        XCTAssertNotEqual(MenuNavigationPolicy.headerTitleKey(for: .usage), "settings.title")
        XCTAssertNotEqual(MenuNavigationPolicy.headerTitleKey(for: .help), "settings.title")
        XCTAssertNotEqual(MenuNavigationPolicy.headerTitleKey(for: .diagnostics), "settings.title")
        XCTAssertEqual(MenuNavigationPolicy.backLabelKey(for: .usage), "nav.back")
        XCTAssertEqual(MenuNavigationPolicy.backLabelKey(for: .help), "nav.back")
        XCTAssertNotEqual(MenuNavigationPolicy.backLabelKey(for: .usage), "settings.back")
        XCTAssertNotEqual(MenuNavigationPolicy.backLabelKey(for: .diagnostics), "settings.title")
    }

    func testSelectedStateAndKeyboardBackConfirm() {
        var state = MenuNavState(primary: .home)
        XCTAssertTrue(MenuNavigationPolicy.isSelected(.home, in: state))
        XCTAssertFalse(MenuNavigationPolicy.isSelected(.settings, in: state))
        XCTAssertFalse(MenuNavigationPolicy.isSelected(.usage, in: state))

        state = MenuNavigationPolicy.apply(.openUsage, to: state)
        XCTAssertTrue(MenuNavigationPolicy.isSelected(.usage, in: state))
        XCTAssertFalse(MenuNavigationPolicy.isSelected(.home, in: state))

        state = MenuNavigationPolicy.apply(.openSettings, to: state)
        state = MenuNavigationPolicy.apply(.openHelp, to: state)
        XCTAssertEqual(state.support, .help)
        XCTAssertTrue(MenuNavigationPolicy.isSelected(.settings, in: state))

        state = MenuNavigationPolicy.apply(.keyboard(.escape), to: state)
        XCTAssertNil(state.support)
        XCTAssertEqual(state.primary, .settings)

        state = MenuNavigationPolicy.apply(.openHelpTopic(.refreshFailed), to: state)
        XCTAssertEqual(state.helpTopic, .refreshFailed)
        state = MenuNavigationPolicy.apply(.keyboard(.escape), to: state)
        XCTAssertEqual(state.support, .help)
        XCTAssertNil(state.helpTopic)

        state = MenuNavigationPolicy.apply(.keyboard(.escape), to: state)
        state = MenuNavigationPolicy.apply(.keyboard(.escape), to: state)
        XCTAssertEqual(state.primary, .home)

        XCTAssertEqual(
            MenuNavigationPolicy.keyboardAction(.escape, state: MenuNavState(primary: .usage)),
            .goBack
        )
        XCTAssertEqual(
            MenuNavigationPolicy.keyboardAction(.return, state: MenuNavState(primary: .settings)),
            .confirm
        )
        XCTAssertEqual(MenuNavigationPolicy.keyboardAction(.tab, state: state), .moveFocus)
    }
}
