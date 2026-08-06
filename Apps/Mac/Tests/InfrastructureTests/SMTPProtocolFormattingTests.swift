import XCTest
@testable import Infrastructure
@testable import Domain

final class SMTPProtocolFormattingTests: XCTestCase {

    // MARK: - RFC 2047 subject encode

    func testEncodeSubject_ascii_wrapsAsUTF8Base64() {
        let encoded = SMTPProtocolFormatting.encodeSubject("Hello")
        // "Hello" utf8 base64 = SGVsbG8=
        XCTAssertEqual(encoded, "=?UTF-8?B?SGVsbG8=?=")
    }

    func testEncodeSubject_chinese_isRFC2047() {
        let encoded = SMTPProtocolFormatting.encodeSubject("【智余】余额关注")
        XCTAssertTrue(encoded.hasPrefix("=?UTF-8?B?"))
        XCTAssertTrue(encoded.hasSuffix("?="))
        // Round-trip base64 payload
        let inner = encoded
            .dropFirst("=?UTF-8?B?".count)
            .dropLast(2)
        let data = Data(base64Encoded: String(inner))
        XCTAssertNotNil(data)
        XCTAssertEqual(String(data: data!, encoding: .utf8), "【智余】余额关注")
    }

    // MARK: - DATA terminator

    func testBuildDATAPayload_endsWithCRLFDotCRLF() {
        let payload = SMTPProtocolFormatting.buildDATAPayload(
            fromDisplay: "智余",
            fromAddress: "a@example.com",
            toAddresses: ["b@example.com"],
            subject: "测试",
            body: "你好\n第二行",
            date: Date(timeIntervalSince1970: 0)
        )
        XCTAssertTrue(payload.hasSuffix("\r\n.\r\n"), "DATA must end with CRLF . CRLF, got tail: \(payload.suffix(20))")
        XCTAssertTrue(payload.contains("Subject: \(SMTPProtocolFormatting.encodeSubject("测试"))"))
        XCTAssertTrue(payload.contains("From: 智余 <a@example.com>"))
        XCTAssertTrue(payload.contains("To: b@example.com"))
        XCTAssertTrue(payload.contains("你好\r\n第二行\r\n.\r\n"))
    }

    func testBuildDATAPayload_dotStuffsLeadingDot() {
        let payload = SMTPProtocolFormatting.buildDATAPayload(
            fromDisplay: "智余",
            fromAddress: "a@example.com",
            toAddresses: ["b@example.com"],
            subject: "s",
            body: ".hidden",
            date: Date(timeIntervalSince1970: 0)
        )
        // Body line ".hidden" → "..hidden" then terminator ".\r\n"
        XCTAssertTrue(payload.contains("\r\n..hidden\r\n.\r\n"))
    }

    // MARK: - Cooldown policy

    func testCooldown_notifiedOnly_enters() {
        XCTAssertTrue(AlertCooldownPolicy.shouldEnterCooldown(notified: true, emailed: false))
    }

    func testCooldown_emailedOnly_enters() {
        XCTAssertTrue(AlertCooldownPolicy.shouldEnterCooldown(notified: false, emailed: true))
    }

    func testCooldown_bothSuccess_enters() {
        XCTAssertTrue(AlertCooldownPolicy.shouldEnterCooldown(notified: true, emailed: true))
    }

    func testCooldown_bothFail_doesNotEnter() {
        XCTAssertFalse(AlertCooldownPolicy.shouldEnterCooldown(notified: false, emailed: false))
    }
}
