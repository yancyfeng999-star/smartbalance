import XCTest
import AppKit
@testable import Domain

final class LocalizationKeyTests: XCTestCase {
    func testRequiredKeysExistInSupportedLanguagesOrHaveExplicitFallback() {
        XCTAssertFalse(LocalizationCatalog.requiredKeys.isEmpty)
        for key in LocalizationCatalog.requiredKeys {
            XCTAssertTrue(
                LocalizationCatalog.contains(key),
                "missing localization key \(key)"
            )
            XCTAssertTrue(
                LocalizationCatalog.hasExplicitFallback(key),
                "key \(key) needs zh-Hans or en fallback"
            )
            for language in AppLanguage.allCases {
                let value = LocalizationCatalog.string(key, language: language)
                XCTAssertFalse(value.isEmpty, "empty string for \(key) in \(language.rawValue)")
                XCTAssertNotEqual(value, key, "unresolved key \(key) in \(language.rawValue)")
            }
        }
    }

    func testPageTitlesAndButtonsAreNonEmpty() {
        XCTAssertFalse(LocalizationCatalog.titleAndButtonKeys.isEmpty)
        for key in LocalizationCatalog.titleAndButtonKeys {
            XCTAssertTrue(
                LocalizationCatalog.requiredKeys.contains(key),
                "title/button key \(key) must be in requiredKeys"
            )
            for language in [AppLanguage.zhHans, .en] {
                let value = LocalizationCatalog.string(key, language: language)
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                XCTAssertFalse(value.contains("\n"), "chrome key \(key) should be a single line")
            }
        }
    }

    func testDynamicStringsInterpolateAndFitNarrowPanel() {
        let longProvider = "NewAPI-Self-Hosted-Very-Long-Provider-Name"
        let interpolated = LocalizationCatalog.format(
            "usage.chart.summary",
            language: .en,
            args: ["USD 1234.50", longProvider]
        )
        XCTAssertTrue(interpolated.contains("1234.50"))
        XCTAssertTrue(interpolated.contains(longProvider))
        XCTAssertFalse(interpolated.contains("%@"))
        XCTAssertFalse(interpolated.contains("%d"))

        for language in [AppLanguage.zhHans, .en] {
            for key in LocalizationCatalog.titleAndButtonKeys {
                let text = LocalizationCatalog.string(key, language: language)
                XCTAssertLessThanOrEqual(
                    measuredWidth(text, size: 13, weight: .semibold),
                    LocalizationLengthPolicy.maxChromeWidth,
                    "\(key) in \(language.rawValue) overflows \(Int(LocalizationLengthPolicy.maxChromeWidth))pt"
                )
            }
            let helpTitle = LocalizationCatalog.string("help.title", language: language)
            XCTAssertLessThanOrEqual(
                measuredWidth(helpTitle, size: 16, weight: .bold),
                LocalizationLengthPolicy.maxChromeWidth
            )
        }
    }

    func testHelpCopyDoesNotPromiseCloudAutoFixOrGuaranteedSuccess() {
        let forbidden = HelpCenterCatalog.forbiddenPhrases
        XCTAssertFalse(forbidden.isEmpty)
        for topic in HelpCenterCatalog.topics {
            let blobs = ([topic.titleKey] + topic.bodyKeys).flatMap { key in
                [AppLanguage.zhHans, .en].map { LocalizationCatalog.string(key, language: $0) }
            }
            for text in blobs {
                let lowered = text.lowercased()
                for phrase in forbidden {
                    XCTAssertFalse(
                        lowered.contains(phrase.lowercased()),
                        "help \(topic.id.rawValue) promises '\(phrase)': \(text)"
                    )
                }
            }
        }
    }

    private func measuredWidth(_ text: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}
