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

    func testCardErrorsMapCredentialsNetworkAndOtherSeparately() {
        XCTAssertEqual(
            SupportViewMapping.cardKind(status: .setup, errorMessage: "未配置密钥"),
            .credentialsMissing
        )
        XCTAssertEqual(
            SupportViewMapping.cardKind(status: .error, errorMessage: "查询超时（10s）"),
            .networkFailed
        )
        XCTAssertEqual(
            SupportViewMapping.cardKind(status: .error, errorMessage: "The Internet connection appears to be offline."),
            .networkFailed
        )
        XCTAssertEqual(
            SupportViewMapping.cardKind(status: .error, errorMessage: "unauthorized"),
            .credentialsMissing
        )
        XCTAssertEqual(
            SupportViewMapping.cardKind(status: .error, errorMessage: "provider returned 500"),
            .refreshFailed
        )
        XCTAssertNotEqual(
            SupportViewMapping.cardKind(status: .error, errorMessage: "查询超时（10s）"),
            .credentialsMissing
        )
        XCTAssertFalse(
            ActionableErrorPolicy.presentation(for: .networkFailed).actions.contains(.reenterCredentials)
        )
        XCTAssertTrue(
            ActionableErrorPolicy.presentation(for: .networkFailed).actions.contains(.retry)
        )
    }

    func testBannerFailureKeysUseFullActionMatrix() {
        let cases: [(String, ActionableErrorKind)] = [
            ("diagnostics.export.failed", .diagnosticsExportFailed),
            ("settings.transfer.export_failed", .exportFailed),
            ("settings.backup.export_failed", .exportFailed),
            ("restore.result.failed", .restoreFailed),
            ("restore.error.settings", .restoreFailed),
            ("restore.error.read", .restoreFailed),
            ("recovery.result.export_failed", .exportFailed),
            ("recovery.result.restore_failed", .restoreFailed),
            ("recovery.result.reset_failed", .settingsCorrupt),
            ("update.check.failed", .updateCheckFailed),
        ]
        let allowed: Set<ErrorNextAction> = [.retry, .viewHelp, .openSettings]
        for (key, expected) in cases {
            XCTAssertEqual(
                SupportViewMapping.homeBannerKind(
                    noticeKey: nil,
                    bannerKey: key,
                    usageHealth: nil,
                    usageDataError: nil
                ),
                expected,
                key
            )
            let actions = ActionableErrorPolicy.presentation(for: expected).actions
            XCTAssertFalse(
                actions.filter(allowed.contains).isEmpty,
                "\(key) needs retry, help, or settings"
            )
        }
    }

    func testViewWiringMapsErrorActionsToDestinations() {
        XCTAssertEqual(
            SupportViewMapping.destination(for: .retry, kind: .refreshFailed),
            .refresh
        )
        XCTAssertEqual(
            SupportViewMapping.destination(for: .retry, kind: .networkFailed),
            .refresh
        )
        XCTAssertEqual(
            SupportViewMapping.destination(for: .reenterCredentials, kind: .credentialsMissing),
            .settingsAPIAccounts
        )
        XCTAssertEqual(
            SupportViewMapping.destination(for: .retry, kind: .diagnosticsExportFailed),
            .retryExportDiagnostics
        )
        XCTAssertEqual(
            SupportViewMapping.destination(
                for: .retry,
                kind: .exportFailed,
                bannerKey: "settings.transfer.export_failed"
            ),
            .retryExportTransfer
        )
        XCTAssertEqual(
            SupportViewMapping.destination(
                for: .retry,
                kind: .exportFailed,
                bannerKey: "settings.backup.export_failed"
            ),
            .retryExportBackup
        )
        XCTAssertEqual(
            SupportViewMapping.destination(for: .restoreBackup, kind: .restoreFailed),
            .backupRestore
        )
        XCTAssertEqual(
            SupportViewMapping.destination(for: .viewHelp, kind: .refreshFailed),
            .help
        )
        XCTAssertEqual(
            SupportViewMapping.destination(for: .openSettings, kind: .exportFailed),
            .settings
        )
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
