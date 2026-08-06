import XCTest
@testable import Infrastructure
@testable import Domain

final class IMAPFetchParserTests: XCTestCase {

    // MARK: - Sample FETCH blobs

    /// Single message with BODY[TEXT] {n} literal + Message-ID.
    private let singleFetchBlob = """
    * 3 FETCH (BODY[HEADER.FIELDS (FROM SUBJECT DATE MESSAGE-ID)] {98}\r
    From: Platform <noreply@vendor.com>\r
    Subject: Balance notice\r
    Date: Mon, 6 Aug 2026 10:00:00 +0800\r
    Message-ID: <abc@x>\r
    \r
     BODY[TEXT] {26}\r
    Your balance is 12.34 CNY.
    )\r
    A002 OK FETCH completed\n
    """

    /// UTF-8 Base64 Subject: 余额通知 → =?UTF-8?B?5L2Z6aKd6YCa55+l?=
    private let utf8SubjectBlob = """
    * 1 FETCH (BODY[HEADER.FIELDS (FROM SUBJECT DATE MESSAGE-ID)] {120}\r
    From: 智余 <mail@example.com>\r
    Subject: =?UTF-8?B?5L2Z6aKd6YCa55+l?=\r
    Date: Mon, 6 Aug 2026 12:00:00 +0800\r
    Message-ID: <utf8-sub@example.com>\r
    \r
     BODY[TEXT] {12}\r
    余额 99.00
    )\r
    A003 OK FETCH completed\n
    """

    /// Two consecutive FETCH responses in one blob.
    private let multiFetchBlob = """
    * 10 FETCH (BODY[HEADER.FIELDS (FROM SUBJECT DATE MESSAGE-ID)] {90}\r
    From: one@a.com\r
    Subject: First\r
    Date: Mon, 6 Aug 2026 09:00:00 +0800\r
    Message-ID: <first@a.com>\r
    \r
     BODY[TEXT] {5}\r
    hello
    )\r
    * 11 FETCH (BODY[HEADER.FIELDS (FROM SUBJECT DATE MESSAGE-ID)] {92}\r
    From: two@b.com\r
    Subject: Second\r
    Date: Mon, 6 Aug 2026 09:05:00 +0800\r
    Message-ID: <second@b.com>\r
    \r
     BODY[TEXT] {5}\r
    world
    )\r
    A004 OK FETCH completed\n
    """

    // MARK: - BODY[TEXT] {n} literal

    func testParseBodyTextLiteral() {
        let messages = IMAPFetchParser.parseFetchResponse(singleFetchBlob)
        XCTAssertEqual(messages.count, 1)
        let m = messages[0]
        XCTAssertEqual(m.body, "Your balance is 12.34 CNY.")
        XCTAssertEqual(m.from, "Platform <noreply@vendor.com>")
        XCTAssertEqual(m.subject, "Balance notice")
    }

    // MARK: - Message-ID

    func testParseMessageID() {
        let messages = IMAPFetchParser.parseFetchResponse(singleFetchBlob)
        XCTAssertEqual(messages.count, 1)
        // Angle brackets stripped
        XCTAssertEqual(messages[0].id, "abc@x")
    }

    // MARK: - Multi FETCH

    func testParseMultipleFetchBlocks() {
        let messages = IMAPFetchParser.parseFetchResponse(multiFetchBlob)
        XCTAssertEqual(messages.count, 2)

        XCTAssertEqual(messages[0].id, "first@a.com")
        XCTAssertEqual(messages[0].from, "one@a.com")
        XCTAssertEqual(messages[0].subject, "First")
        XCTAssertEqual(messages[0].body, "hello")

        XCTAssertEqual(messages[1].id, "second@b.com")
        XCTAssertEqual(messages[1].from, "two@b.com")
        XCTAssertEqual(messages[1].subject, "Second")
        XCTAssertEqual(messages[1].body, "world")
    }

    // MARK: - UTF-8 Base64 Subject

    func testDecodeUTF8Base64Subject() {
        // 余额通知 base64: 5L2Z6aKd6YCa55+l
        let messages = IMAPFetchParser.parseFetchResponse(utf8SubjectBlob)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].subject, "余额通知")
        XCTAssertEqual(messages[0].id, "utf8-sub@example.com")
        XCTAssertTrue(messages[0].body.contains("余额") || messages[0].body.contains("99"))
    }

    // MARK: - parseExists

    func testParseExistsFromSelect() {
        let select = """
        * 12 EXISTS
        * FLAGS (\\Seen \\Answered)
        * OK [UIDVALIDITY 1]
        A001 OK [READ-WRITE] SELECT completed
        """
        XCTAssertEqual(IMAPFetchParser.parseExists(from: select), 12)
    }

    func testParseExistsMissingReturnsNil() {
        XCTAssertNil(IMAPFetchParser.parseExists(from: "A001 OK SELECT completed"))
    }

    func testParseExistsZero() {
        XCTAssertEqual(IMAPFetchParser.parseExists(from: "* 0 EXISTS\nA001 OK"), 0)
    }

    // MARK: - Empty / noise

    func testEmptyBlobReturnsEmpty() {
        XCTAssertTrue(IMAPFetchParser.parseFetchResponse("").isEmpty)
        XCTAssertTrue(IMAPFetchParser.parseFetchResponse("A002 OK completed\n").isEmpty)
    }

    // MARK: - IMAPError user-facing strings

    func testAuthFailedMessage() {
        let err = IMAPError.authFailed("A001 NO [AUTHENTICATIONFAILED]")
        XCTAssertEqual(err.errorDescription, "IMAP 登录失败，请检查邮箱与授权码")
    }

    func testTimeoutMessage() {
        XCTAssertEqual(IMAPError.timeout.errorDescription, "IMAP 连接超时")
    }

    func testConnectionTimeoutMappedMessage() {
        let err = IMAPError.connection("The operation timed out")
        XCTAssertEqual(err.errorDescription, "IMAP 连接超时")
    }

    func testFolderNotFoundMessage() {
        let err = IMAPError.folderNotFound("INBOX")
        XCTAssertEqual(err.errorDescription, "文件夹不存在：INBOX")
    }
}
