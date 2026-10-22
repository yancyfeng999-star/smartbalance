import Foundation
import XCTest
@testable import Infrastructure

final class BrowserSessionCredentialTests: XCTestCase {
    func testSmallAndLargeNewAPIAccountIDsAreReadFromTheTypedIDEntry() {
        for id in [1, 42, 100, 1234, 123456] {
            let value = fixtureSession(id: id)
            XCTAssertEqual(SessionCookieParser.extractNewAPISessionUserId(fromSession: value), String(id))
            XCTAssertEqual(SessionCookieParser.extractNewAPIUserId(fromSession: value), String(id))
        }
        XCTAssertNil(SessionCookieParser.extractNewAPISessionUserId(fromSession: "unrelated-text"))
    }

    func testBytebroadExtractsOnlyItsOwnDomainAndSession() throws {
        let good = row(host: "token.bytebroad.com.cn", name: "session", value: fixtureSession(id: 1234))
        let wrong = row(host: "token.bytebroad.com.cn.untrusted.invalid", name: "session", value: fixtureSession(id: 9999))
        let result = try BrowserSessionImporter.bytebroadCredential(from: [wrong, good])
        XCTAssertEqual(result.secret, good.value)
        XCTAssertEqual(result.userId, "1234")
        XCTAssertThrowsError(try BrowserSessionImporter.bytebroadCredential(from: [wrong]))
    }

    func testBytebroadRejectsUndecodableSessionWithoutGuessingAnID() {
        XCTAssertThrowsError(try BrowserSessionImporter.bytebroadCredential(from: [row(host: "token.bytebroad.com.cn", name: "session", value: "unrelated-text")]))
    }

    func testMiMoTokenAndUserIDMustBeFromTheSameBrowserProfile() {
        let token = row(host: "platform.xiaomimimo.com", name: "api-platform_serviceToken", value: "fixture-token", profile: "Default")
        let wrongUID = row(host: "platform.xiaomimimo.com", name: "userId", value: "1234", profile: "Profile 2")
        XCTAssertThrowsError(try BrowserSessionImporter.miMoCredential(from: [token, wrongUID]))
    }

    func testMiMoPairUsesMatchingProfileInsteadOfNewestUnrelatedUID() throws {
        let token = row(host: "platform.xiaomimimo.com", name: "api-platform_serviceToken", value: "fixture-token", profile: "Default")
        let wrongUID = row(host: "platform.xiaomimimo.com", name: "userId", value: "9999", profile: "Profile 2")
        let correctUID = row(host: "platform.xiaomimimo.com", name: "userId", value: "1234", profile: "Default")
        XCTAssertEqual(try BrowserSessionImporter.miMoCredential(from: [wrongUID, token, correctUID]).userId, "1234")
    }

    private func row(host: String, name: String, value: String, profile: String = "Default") -> BrowserSessionImporter.CookieRow {
        .init(host: host, name: name, value: value, browserName: "Chrome", profileID: profile, lastAccess: 1)
    }

    private func fixtureSession(id: Int) -> String {
        var integer = UInt64(id * 2)
        var encoded: [UInt8] = []
        if integer < 128 { encoded = [UInt8(integer)] }
        else {
            while integer > 0 { encoded.insert(UInt8(integer & 255), at: 0); integer >>= 8 }
            encoded.insert(UInt8(256 - encoded.count), at: 0)
        }
        let payload = [UInt8(0)] + encoded
        let gob = Data([0x02] + Array("id".utf8) + [0x03] + Array("int".utf8) + [0x04, UInt8(payload.count)] + payload)
        return Data("1|\(gob.base64EncodedString())|fixture-mac".utf8).base64EncodedString()
    }
}
