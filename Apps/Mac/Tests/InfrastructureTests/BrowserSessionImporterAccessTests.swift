import Foundation
import XCTest
@testable import Infrastructure

final class BrowserSessionImporterAccessTests: XCTestCase {
    func testDirectoryPermissionDenialIsNotSwallowedAsMissingBrowser() {
        XCTAssertThrowsError(try BrowserSessionImporter.browserCookieCandidates(home: "/fixture") { path in
            if path.hasSuffix("Google/Chrome") {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))
            }
            throw CocoaError(.fileReadNoSuchFile)
        })
    }

    func testSelectedChromeDirectoryDoesNotProbeBlockedEdgeDirectory() throws {
        let root = "/fixture/Library/Application Support/Google/Chrome"
        let candidates = try BrowserSessionImporter.browserCookieCandidates(
            home: "/fixture", selectedDirectory: URL(fileURLWithPath: root)
        ) { path in
            XCTAssertEqual(path, root)
            return ["Default", "Profile 8"]
        }
        XCTAssertEqual(candidates.map(\.profileID), ["Default", "Profile 8"])
    }

    func testSelectedProfileIsNotMixedWithOtherProfiles() throws {
        let directory = "/fixture/Library/Application Support/Google/Chrome/Profile 8"
        let candidates = try BrowserSessionImporter.browserCookieCandidates(
            home: "/fixture", selectedDirectory: URL(fileURLWithPath: directory)
        ) { _ in
            XCTFail("Choosing one profile must not enumerate its parent or other browsers")
            return []
        }
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.path, directory + "/Cookies")
        XCTAssertEqual(candidates.first?.profileID, "Profile 8")
    }

    func testSelectedEdgeDirectoryUsesEdgeSafeStorage() throws {
        let directory = "/fixture/Library/Application Support/Microsoft Edge"
        let candidates = try BrowserSessionImporter.browserCookieCandidates(
            home: "/fixture", selectedDirectory: URL(fileURLWithPath: directory)
        ) { _ in ["Default"] }
        XCTAssertEqual(candidates.first?.service, "Microsoft Edge Safe Storage")
    }

    func testBroadOrUnrelatedDirectoryIsRejectedBeforeReading() {
        for path in ["/fixture", "/fixture/Library", "/fixture/Library/Application Support/Google/Chrome/Crashpad"] {
            XCTAssertThrowsError(try BrowserSessionImporter.browserCookieCandidates(
                home: "/fixture", selectedDirectory: URL(fileURLWithPath: path)
            ) { _ in
                XCTFail("Must not read unrelated directories")
                return []
            }) { error in
                guard case .invalidBrowserDirectory = error as? BrowserSessionImporter.ImportError else {
                    return XCTFail("Wrong error: \(error)")
                }
            }
        }
    }

    func testUnderlyingPOSIXPermissionDenialIsRecognized() {
        let error = NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileReadUnknown.rawValue,
                            userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))])
        XCTAssertTrue(BrowserSessionImporter.isAccessDenied(error))
        XCTAssertFalse(BrowserSessionImporter.isAccessDenied(CocoaError(.fileReadCorruptFile)))
    }

    func testNonPermissionReadFailureDoesNotPretendBrowserIsMissing() {
        XCTAssertThrowsError(try BrowserSessionImporter.browserCookieCandidates(home: "/fixture") { _ in
            throw CocoaError(.fileReadCorruptFile)
        }) { error in
            guard case .browserReadFailed = error as? BrowserSessionImporter.ImportError else {
                return XCTFail("Wrong error: \(error)")
            }
        }
    }

    func testCocoaDirectoryPermissionDenialIsNotSwallowed() {
        XCTAssertThrowsError(try BrowserSessionImporter.browserCookieCandidates(home: "/fixture") { _ in
            throw CocoaError(.fileReadNoPermission)
        })
    }

    func testMissingBrowserDirectoriesRemainEmpty() throws {
        let candidates = try BrowserSessionImporter.browserCookieCandidates(home: "/fixture") { _ in
            throw CocoaError(.fileReadNoSuchFile)
        }
        XCTAssertTrue(candidates.isEmpty)
    }

    func testAllProfilesAreEnumeratedWithoutUnrelatedDirectories() throws {
        let candidates = try BrowserSessionImporter.browserCookieCandidates(home: "/fixture") { path in
            path.hasSuffix("Google/Chrome") ? ["Profile 12", "Default", "Profile 2", "Crashpad"] : []
        }
        XCTAssertEqual(candidates.map(\.profileID), ["Default", "Profile 2", "Profile 12"])
        XCTAssertTrue(candidates.allSatisfy { $0.name == "Chrome" && $0.path.hasSuffix("/Cookies") })
    }
}
