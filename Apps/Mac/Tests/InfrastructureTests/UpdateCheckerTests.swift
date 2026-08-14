import XCTest
@testable import Domain
@testable import Infrastructure

final class UpdateCheckerTests: XCTestCase {
    func testPreferredPackagePrefersSmartBalancePKG() {
        let json: [String: Any] = [
            "assets": [
                [
                    "name": "智余-0.2.50.dmg",
                    "browser_download_url": "https://example.com/a.dmg",
                    "size": 10,
                ],
                [
                    "name": "智余-0.2.50.pkg",
                    "browser_download_url": "https://example.com/a.pkg",
                    "size": 10,
                ],
                [
                    "name": "SmartBalance-0.2.50.pkg",
                    "browser_download_url": "https://example.com/SmartBalance-0.2.50.pkg",
                    "size": 10,
                ],
                [
                    "name": "SmartBalance-0.2.50.dmg",
                    "browser_download_url": "https://example.com/SmartBalance-0.2.50.dmg",
                    "size": 10,
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
                    "size": 10,
                ],
            ],
        ]
        let url = UpdateChecker().preferredPackageURL(from: json)
        XCTAssertEqual(url?.pathExtension, "dmg")
    }

    func testPreferredPackageIgnoresZipOnlyRelease() {
        let json: [String: Any] = [
            "assets": [
                [
                    "name": "SmartBalance-0.3.2.zip",
                    "browser_download_url": "https://example.com/SmartBalance-0.3.2.zip",
                    "size": 10,
                ],
            ],
        ]
        XCTAssertNil(UpdateChecker().preferredPackageURL(from: json))
    }

    func testCheckAvailableUsesMockAndDoesNotClaimInstallInProgress() async throws {
        let release = try fixtureData("github-release-latest.json")
        let sums = try fixtureData("github-release-sha256sums.txt")
        let client = MockHTTPClient(responses: [(200, release), (200, sums)])
        let checker = UpdateChecker(client: client, currentVersion: "0.3.1")
        let result = await checker.check()

        XCTAssertEqual(result.status, .available)
        XCTAssertEqual(result.latestVersion, "0.3.2")
        XCTAssertEqual(result.messageKey, "update.check.available")
        XCTAssertFalse(result.message.contains("正在下载"))
        XCTAssertFalse(result.message.contains("安装"))
        XCTAssertEqual(result.details?.targetVersion, "0.3.2")
        XCTAssertEqual(result.details?.currentVersion, "0.3.1")
        XCTAssertEqual(result.details?.asset?.fileName, "SmartBalance-0.3.2.pkg")
        XCTAssertEqual(result.details?.asset?.byteSize, 12_345_678)
        XCTAssertEqual(result.details?.minimumMacOS, "15.0")
        XCTAssertNotNil(result.details?.publishedAt)
        XCTAssertFalse(UpdateReleaseNotes.containsUnsafeMarkup(result.details?.releaseNotesPlainText ?? ""))
        XCTAssertTrue((result.details?.releaseNotesPlainText ?? "").contains("docs"))
        XCTAssertEqual(result.details?.checksumManifestText?.contains("SmartBalance-0.3.2.pkg"), true)
        XCTAssertEqual(client.callCount, 2)
    }

    func testCheckUpToDateUsesMockWithoutNetwork() async throws {
        let release = try fixtureData("github-release-latest.json")
        let client = MockHTTPClient(statusCode: 200, body: release)
        let checker = UpdateChecker(client: client, currentVersion: "0.3.2")
        let result = await checker.check()
        XCTAssertEqual(result.status, .upToDate)
        XCTAssertEqual(result.messageKey, "update.check.up_to_date")
    }

    func testCheckNotFoundUsesMock() async {
        let client = MockHTTPClient(statusCode: 404, body: Data("{}".utf8))
        let result = await UpdateChecker(client: client, currentVersion: "0.3.1").check()
        XCTAssertEqual(result.status, .unknown)
        XCTAssertEqual(result.messageKey, "update.check.no_release")
    }

    func testCheckNetworkFailureUsesThrowingMock() async {
        let client = ThrowingHTTPClient(error: URLError(.timedOut))
        let result = await UpdateChecker(client: client, currentVersion: "0.3.1").check()
        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(result.messageKey, "update.check.failed")
        XCTAssertNotNil(result.openURL)
    }

    func testParseReleaseSanitizesNotesAndRejectsZipPreference() throws {
        let data = try fixtureData("github-release-latest.json")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let result = UpdateChecker(currentVersion: "0.3.1").makeResult(from: json, current: "0.3.1")
        XCTAssertEqual(result.status, .available)
        XCTAssertFalse((result.details?.releaseNotesPlainText ?? "").lowercased().contains("<script"))
        XCTAssertEqual(result.downloadURL?.pathExtension, "pkg")
    }
}

private func fixtureData(_ name: String) throws -> Data {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/CommonCapabilities/\(name)")
    return try Data(contentsOf: url)
}

private struct ThrowingHTTPClient: HTTPClient, Sendable {
    var error: Error

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw error
    }
}
