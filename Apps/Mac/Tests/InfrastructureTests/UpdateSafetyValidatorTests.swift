import XCTest
@testable import Domain
@testable import Infrastructure

final class UpdateSafetyValidatorTests: XCTestCase {
    private let validator = UpdateSafetyValidator()

    func testOlderVersionIsRejected() {
        let result = validator.validate(candidate(current: "0.3.1", target: "0.2.9"))
        XCTAssertFalse(result.canInstall)
        XCTAssertTrue(result.issues.contains(.versionNotNewer))
    }

    func testEqualVersionIsRejected() {
        let result = validator.validate(candidate(current: "0.3.1", target: "0.3.1"))
        XCTAssertFalse(result.canInstall)
        XCTAssertTrue(result.issues.contains(.versionNotNewer))
    }

    func testMalformedTargetVersionIsRejected() {
        let result = validator.validate(candidate(target: "1.2.x"))
        XCTAssertFalse(result.canInstall)
        XCTAssertTrue(result.issues.contains(.malformedTargetVersion))
    }

    func testIncompatibleMinimumMacOSIsRejected() {
        let result = validator.validate(candidate(minOS: "16.0", currentOS: "15.6.0"))
        XCTAssertFalse(result.canInstall)
        XCTAssertTrue(result.issues.contains(.incompatibleMinimumOS))
    }

    func testNonHTTPSURLIsRejected() {
        let result = validator.validate(
            candidate(url: "http://github.com/yancyfeng999-star/smartbalance/SmartBalance-0.3.2.pkg")
        )
        XCTAssertFalse(result.canInstall)
        XCTAssertTrue(result.issues.contains(.urlNotHTTPS))
    }

    func testDisallowedExtensionIsRejected() {
        let result = validator.validate(
            candidate(
                url: "https://github.com/yancyfeng999-star/smartbalance/releases/download/v0.3.2/SmartBalance-0.3.2.zip",
                fileName: "SmartBalance-0.3.2.zip"
            )
        )
        XCTAssertFalse(result.canInstall)
        XCTAssertTrue(result.issues.contains(.assetExtensionNotAllowed))
    }

    func testZeroSizeIsRejected() {
        let result = validator.validate(candidate(size: 0))
        XCTAssertFalse(result.canInstall)
        XCTAssertTrue(result.issues.contains(.sizeZero))
    }

    func testSizeOverLimitIsRejected() {
        let result = validator.validate(
            candidate(size: UpdateSafetyLimits.maxAssetBytes + 1, max: UpdateSafetyLimits.maxAssetBytes)
        )
        XCTAssertFalse(result.canInstall)
        XCTAssertTrue(result.issues.contains(.sizeExceedsLimit))
    }

    func testMatchingSHA256IsAccepted() {
        let hello = Data("hello".utf8)
        let digest = SHA256Verifier.hexDigest(of: hello)
        let manifest = "\(digest)  SmartBalance-0.3.2.pkg\n"
        let result = validator.validate(candidate(manifest: manifest, sha: digest))
        XCTAssertTrue(result.canInstall)
        XCTAssertEqual(result.checksumStatus, .verified)
        XCTAssertEqual(result.checksumDisplay, .verified)
        XCTAssertFalse(result.issues.contains(.checksumMismatch))
    }

    func testMismatchedSHA256IsRejected() {
        let digest = SHA256Verifier.hexDigest(of: Data("hello".utf8))
        let other = SHA256Verifier.hexDigest(of: Data("world".utf8))
        let manifest = "\(digest)  SmartBalance-0.3.2.pkg\n"
        let result = validator.validate(candidate(manifest: manifest, sha: other))
        XCTAssertFalse(result.canInstall)
        XCTAssertEqual(result.checksumStatus, .mismatch)
        XCTAssertEqual(result.checksumDisplay, .failed)
        XCTAssertTrue(result.issues.contains(.checksumMismatch))
    }

    func testMissingChecksumIsUnverifiableNeverVerified() {
        let result = validator.validate(candidate(manifest: nil, sha: nil))
        XCTAssertTrue(result.canInstall)
        XCTAssertEqual(result.checksumStatus, .unverifiable)
        XCTAssertEqual(result.checksumDisplay, .unverifiable)
        XCTAssertNotEqual(result.checksumDisplay, .verified)
        XCTAssertNotEqual(result.checksumDisplay.localizationKey, UpdateChecksumDisplay.verified.localizationKey)
        XCTAssertTrue(result.issues.contains(.checksumMissing))
        XCTAssertTrue(result.issues.allSatisfy { !$0.blocksInstall || $0 == .checksumMissing })
    }

    func testInvalidPackageSignatureBlocksInstall() {
        let result = validator.validate(
            candidate(),
            integrity: PackageIntegrityReport(structureValid: true, signatureValid: false)
        )
        XCTAssertFalse(result.canInstall)
        XCTAssertTrue(result.issues.contains(.packageSignatureInvalid))
    }

    func testInvalidPackageStructureBlocksInstall() {
        let result = validator.validate(
            candidate(),
            integrity: PackageIntegrityReport(structureValid: false, signatureValid: nil)
        )
        XCTAssertFalse(result.canInstall)
        XCTAssertTrue(result.issues.contains(.packageStructureInvalid))
    }

    func testSHA256VerifierParsesManifestAndHashesFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sb-sha-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("SmartBalance-0.3.2.pkg")
        let payload = Data("hello".utf8)
        try payload.write(to: file)
        let digest = try SHA256Verifier.hexDigest(ofFile: file)
        XCTAssertEqual(digest, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")

        let manifest = """
        # comment
        \(digest)  SmartBalance-0.3.2.pkg
        """
        XCTAssertTrue(SHA256Verifier.matches(fileName: "SmartBalance-0.3.2.pkg", digest: digest, manifest: manifest))
        XCTAssertFalse(SHA256Verifier.matches(fileName: "SmartBalance-0.3.2.pkg", digest: "00", manifest: manifest))
        XCTAssertNil(SHA256Verifier.expectedDigest(fileName: "missing.pkg", manifest: manifest))
    }

    private func candidate(
        current: String = "0.3.1",
        target: String = "0.3.2",
        minOS: String = "15.0",
        currentOS: String = "15.6.0",
        url: String = "https://github.com/yancyfeng999-star/smartbalance/releases/download/v0.3.2/SmartBalance-0.3.2.pkg",
        fileName: String = "SmartBalance-0.3.2.pkg",
        size: Int64 = 12_345_678,
        max: Int64 = UpdateSafetyLimits.maxAssetBytes,
        manifest: String? = nil,
        sha: String? = nil
    ) -> UpdateCandidate {
        UpdateCandidate(
            currentVersion: current,
            targetVersion: target,
            minimumMacOS: minOS,
            currentMacOS: currentOS,
            assetURL: URL(string: url)!,
            assetFileName: fileName,
            assetByteSize: size,
            maxByteSize: max,
            checksumManifestText: manifest,
            downloadedFileSHA256: sha
        )
    }
}
