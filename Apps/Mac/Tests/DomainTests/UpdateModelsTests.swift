import XCTest
@testable import Domain

final class UpdateModelsTests: XCTestCase {
    func testPlainTextSummaryStripsScriptAndMarkdownLinks() {
        let raw = """
        ## Changes
        <script>alert(1)</script>
        <iframe src="https://evil.example"></iframe>
        See [docs](https://evil.example/docs) for details.
        """
        let summary = UpdateReleaseNotes.plainTextSummary(raw)
        XCTAssertFalse(summary.lowercased().contains("<script"))
        XCTAssertFalse(summary.lowercased().contains("<iframe"))
        XCTAssertFalse(summary.contains("https://evil.example/docs"))
        XCTAssertTrue(summary.contains("docs"))
        XCTAssertTrue(summary.contains("Changes"))
        XCTAssertFalse(UpdateReleaseNotes.containsUnsafeMarkup(summary))
    }

    func testVersionParseRejectsMalformedTarget() {
        XCTAssertNil(UpdateVersion.parse("abc"))
        XCTAssertNil(UpdateVersion.parse("1.2.x"))
        XCTAssertNil(UpdateVersion.parse("1.2-beta"))
        XCTAssertEqual(UpdateVersion.parse("0.3.2"), [0, 3, 2])
        XCTAssertEqual(UpdateVersion.compare("0.3.2", "0.3.1"), 1)
        XCTAssertEqual(UpdateVersion.compare("0.3.1", "0.3.1"), 0)
        XCTAssertEqual(UpdateVersion.compare("0.2.99", "0.3.1"), -1)
        XCTAssertNil(UpdateVersion.compare("1.2.x", "0.3.1"))
    }

    func testChecksumMissingDisplayIsNeverVerified() {
        XCTAssertEqual(UpdateChecksumDisplay.unverifiable.localizationKey, "update.checksum.unverifiable")
        XCTAssertNotEqual(
            UpdateChecksumDisplay.unverifiable.localizationKey,
            UpdateChecksumDisplay.verified.localizationKey
        )
        XCTAssertEqual(UpdateValidationIssue.checksumMissing.localizationKey, "update.error.checksumMissing")
        XCTAssertFalse(UpdateValidationIssue.checksumMissing.blocksInstall)
        XCTAssertTrue(UpdateValidationIssue.checksumMismatch.blocksInstall)
        XCTAssertTrue(UpdateValidationIssue.checksumUnavailable.blocksInstall)
        XCTAssertNotEqual(
            UpdateValidationIssue.checksumUnavailable.localizationKey,
            UpdateValidationIssue.checksumMissing.localizationKey
        )
    }

    func testInstallConfirmCopyDiffersForDMGAndPKG() {
        XCTAssertEqual(UpdateInstallConfirmCopy.messageKey(for: .pkg), "update.confirm.restart")
        XCTAssertEqual(UpdateInstallConfirmCopy.confirmActionKey(for: .pkg), "update.action.confirm")
        XCTAssertEqual(UpdateInstallConfirmCopy.messageKey(for: .dmg), "update.confirm.open_dmg")
        XCTAssertEqual(UpdateInstallConfirmCopy.confirmActionKey(for: .dmg), "update.action.confirm_open")
        XCTAssertNotEqual(
            UpdateInstallConfirmCopy.messageKey(for: .dmg),
            UpdateInstallConfirmCopy.messageKey(for: .pkg)
        )
    }

    func testAssetNameAllowlist() {
        XCTAssertTrue(UpdateAssetName.isAllowed("SmartBalance-0.3.2.pkg"))
        XCTAssertTrue(UpdateAssetName.isAllowed("智余-0.3.2.dmg"))
        XCTAssertFalse(UpdateAssetName.isAllowed("SmartBalance-0.3.2.zip"))
        XCTAssertFalse(UpdateAssetName.isAllowed("evil.pkg"))
        XCTAssertFalse(UpdateAssetName.isAllowed("../SmartBalance-0.3.2.pkg"))
    }

    func testMinimumOSParserAndByteFormatter() {
        XCTAssertEqual(
            UpdateMinimumOSParser.parse(fromReleaseNotes: "Requires macOS 15.1"),
            "15.1"
        )
        XCTAssertEqual(
            UpdateMinimumOSParser.parse(fromReleaseNotes: "no mention"),
            UpdateSafetyLimits.defaultMinimumMacOS
        )
        XCTAssertEqual(UpdateByteCountFormatter.displayString(12_345_678), "11.8 MB")
    }
}
