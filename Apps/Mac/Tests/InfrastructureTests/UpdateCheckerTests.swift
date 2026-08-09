import XCTest
@testable import Infrastructure

final class UpdateCheckerTests: XCTestCase {
    func testPreferredPackagePrefersSmartBalancePKG() {
        let json: [String: Any] = [
            "assets": [
                [
                    "name": "智余-0.2.50.dmg",
                    "browser_download_url": "https://example.com/a.dmg",
                ],
                [
                    "name": "智余-0.2.50.pkg",
                    "browser_download_url": "https://example.com/a.pkg",
                ],
                [
                    "name": "SmartBalance-0.2.50.pkg",
                    "browser_download_url": "https://example.com/SmartBalance-0.2.50.pkg",
                ],
                [
                    "name": "SmartBalance-0.2.50.dmg",
                    "browser_download_url": "https://example.com/SmartBalance-0.2.50.dmg",
                ],
            ],
        ]
        let url = UpdateChecker().preferredPackageURL(from: json)
        XCTAssertEqual(url?.absoluteString, "https://example.com/SmartBalance-0.2.50.pkg")
    }

    func testPreferredPackageFallsBackToDMG() {
        let json: [String: Any] = [
            "assets": [
                [
                    "name": "SmartBalance-0.2.50.dmg",
                    "browser_download_url": "https://example.com/SmartBalance-0.2.50.dmg",
                ],
            ],
        ]
        let url = UpdateChecker().preferredPackageURL(from: json)
        XCTAssertEqual(url?.pathExtension, "dmg")
    }
}
