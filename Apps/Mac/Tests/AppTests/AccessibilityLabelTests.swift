import XCTest
@testable import Domain

final class AccessibilityLabelTests: XCTestCase {
    func testNavigationActionsHaveStableIdentifiersLabelsAndSelectedState() {
        for action in SupportAccessibilityCatalog.navigationActions {
            let idle = SupportAccessibilityCatalog.label(for: action, selected: false)
            let selected = SupportAccessibilityCatalog.label(for: action, selected: true)

            XCTAssertFalse(idle.identifier.isEmpty, "\(action) missing identifier")
            XCTAssertEqual(idle.identifier, selected.identifier, "\(action) identifier must stay stable")
            XCTAssertEqual(idle.identifier, action.rawValue)
            XCTAssertFalse(idle.labelKey.isEmpty)
            XCTAssertEqual(idle.labelKey, selected.labelKey)
            XCTAssertNotEqual(idle.labelKey, "settings.title", "\(action) must not reuse settings title")
            XCTAssertFalse(LocalizationCatalog.string(idle.labelKey, language: .zhHans).isEmpty)
            XCTAssertFalse(LocalizationCatalog.string(idle.labelKey, language: .en).isEmpty)
            XCTAssertFalse(idle.isSelected)
            XCTAssertTrue(selected.isSelected)
            XCTAssertTrue(idle.traits.contains(.button))
            XCTAssertTrue(selected.traits.contains(.button))
            XCTAssertTrue(selected.traits.contains(.selected))
            XCTAssertFalse(idle.traits.contains(.selected))
        }

        XCTAssertEqual(
            SupportAccessibilityCatalog.label(for: .navSettings, selected: false).labelKey,
            "home.settings"
        )
        XCTAssertEqual(
            SupportAccessibilityCatalog.label(for: .navUsage, selected: false).labelKey,
            "home.usage"
        )
        XCTAssertEqual(
            SupportAccessibilityCatalog.label(for: .navBack, selected: false).labelKey,
            "nav.back"
        )
        XCTAssertNotEqual(
            SupportAccessibilityCatalog.label(for: .navBack, selected: false).labelKey,
            "settings.back"
        )
    }

    func testErrorStatesExposeRetryHelpOrSettingsAction() {
        let allowed: Set<ErrorNextAction> = [.retry, .viewHelp, .openSettings]
        for kind in ActionableErrorKind.allCases {
            let presentation = ActionableErrorPolicy.presentation(for: kind)
            XCTAssertFalse(presentation.actions.isEmpty, "\(kind) has no next action")
            XCTAssertFalse(
                presentation.actions.filter(allowed.contains).isEmpty,
                "\(kind) needs retry, help, or settings"
            )
            XCTAssertFalse(presentation.titleKey.isEmpty)
            XCTAssertFalse(presentation.messageKey.isEmpty)
            XCTAssertFalse(LocalizationCatalog.string(presentation.titleKey, language: .en).isEmpty)
            XCTAssertNotEqual(LocalizationCatalog.string(presentation.titleKey, language: .en), presentation.titleKey)
            for action in presentation.actions {
                let id = SupportAccessibilityCatalog.identifier(for: action)
                let labelKey = SupportAccessibilityCatalog.labelKey(for: action)
                XCTAssertFalse(id.isEmpty)
                XCTAssertTrue(id.hasPrefix("error."))
                XCTAssertFalse(LocalizationCatalog.string(labelKey, language: .zhHans).isEmpty)
                XCTAssertNotEqual(LocalizationCatalog.string(labelKey, language: .en), labelKey)
            }
        }
    }

    func testChartsExposeNonGraphicSummaryAndDoNotRelyOnColorAlone() {
        let summary = UsageChartTextSummary.line(
            periodLabel: LocalizationCatalog.string("usage.week", language: .en),
            total: "¥12.00",
            pointCount: 7,
            language: .en
        )
        XCTAssertTrue(summary.contains("12.00"))
        XCTAssertTrue(summary.contains("7") || summary.lowercased().contains("point"))
        XCTAssertEqual(
            UsageChartTextSummary.accessibilityIdentifier,
            SupportAccessibilityID.usageChartSummary.rawValue
        )
        XCTAssertFalse(UsageChartTextSummary.reliesOnColorAlone)

        let providerValue = UsageChartTextSummary.providerValue(
            amount: "¥4.00",
            unit: "CNY",
            qualityKey: "usage.estimated_quality",
            language: .en
        )
        XCTAssertTrue(providerValue.contains("4.00"))
        XCTAssertTrue(
            providerValue.contains(LocalizationCatalog.string("usage.estimated_quality", language: .en))
        )
    }
}
