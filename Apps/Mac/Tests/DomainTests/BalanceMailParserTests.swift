import XCTest
@testable import Domain

final class BalanceMailParserTests: XCTestCase {
    func testExtractCNY() {
        let text = "您好，您的账户余额为 ¥128.50，请留意。"
        XCTAssertEqual(BalanceMailParser.extractAmount(from: text, customRegex: nil), 128.50)
    }

    func testExtractUSD() {
        let text = "Current balance: $42.00 remaining."
        XCTAssertEqual(BalanceMailParser.extractAmount(from: text, customRegex: nil), 42.0)
    }

    func testCustomRegex() {
        let text = "quota_left=99.5 units"
        let amount = BalanceMailParser.extractAmount(from: text, customRegex: #"quota_left=([0-9.]+)"#)
        XCTAssertEqual(amount, 99.5)
    }

    func testLooksLikeAlert() {
        XCTAssertTrue(BalanceMailParser.looksLikeAlert(subject: "余额不足提醒", body: "请充值"))
        XCTAssertFalse(BalanceMailParser.looksLikeAlert(subject: "Weekly report", body: "all good"))
    }

    func testMatchSource() {
        let src = PlatformMailSource(displayName: "X", fromContains: "noreply@vendor.com", subjectContains: "余额")
        let ok = FetchedMailMessage(id: "1", from: "Team <noreply@vendor.com>", subject: "余额通知", body: "余额 10")
        let bad = FetchedMailMessage(id: "2", from: "other@x.com", subject: "余额通知", body: "x")
        XCTAssertTrue(BalanceMailParser.matches(message: ok, source: src))
        XCTAssertFalse(BalanceMailParser.matches(message: bad, source: src))
    }
}
