import XCTest
@testable import Infrastructure

final class PrivacyRedactorTests: XCTestCase {
    func testRedactsBearerToken() {
        let input = "Authorization: Bearer FAKESECRET_w3x4y5z6a7b8c9d0e1f2"
        let output = PrivacyRedactor.redact(input)
        XCTAssertFalse(output.contains("FAKESECRET_w3x4y5z6a7b8c9d0e1f2"), output)
        XCTAssertTrue(output.contains(PrivacyRedactor.redactedPlaceholder), output)
    }

    func testRedactsAPIKey() {
        let input = "api_key=sk-test-fake-api-key-1234567890ABCDEF"
        let output = PrivacyRedactor.redact(input)
        XCTAssertFalse(output.contains("sk-test-fake-api-key-1234567890ABCDEF"), output)
        XCTAssertTrue(output.contains(PrivacyRedactor.redactedPlaceholder), output)
    }

    func testRedactsCookieHeader() {
        let input = "Cookie: session=fake-cookie-value-zzzz; theme=dark"
        let output = PrivacyRedactor.redact(input)
        XCTAssertFalse(output.contains("fake-cookie-value-zzzz"), output)
        XCTAssertTrue(output.contains(PrivacyRedactor.redactedPlaceholder), output)
    }

    func testRedactsSMTPPassword() {
        let input = "smtpPassword: SuperFakeSMTP-Pass-0001"
        let output = PrivacyRedactor.redact(input)
        XCTAssertFalse(output.contains("SuperFakeSMTP-Pass-0001"), output)
        XCTAssertTrue(output.contains(PrivacyRedactor.redactedPlaceholder), output)
    }

    func testRedactsURLQueryToken() {
        let input = "GET https://api.example.test/v1/balance?token=fake-query-token-xyz&unit=USD"
        let output = PrivacyRedactor.redact(input)
        XCTAssertFalse(output.contains("fake-query-token-xyz"), output)
        XCTAssertTrue(output.contains("unit=USD"), output)
        XCTAssertTrue(output.contains(PrivacyRedactor.redactedPlaceholder), output)
    }

    func testRedactsEmailAddresses() {
        let input = "alert mailed to owner@example.test and ops+alerts@example.test"
        let output = PrivacyRedactor.redact(input)
        XCTAssertFalse(output.contains("owner@example.test"), output)
        XCTAssertFalse(output.contains("ops+alerts@example.test"), output)
        XCTAssertTrue(output.contains(PrivacyRedactor.redactedPlaceholder), output)
    }

    func testRedactsSuspectedJSONSecretFields() {
        let input = """
        {"api_key":"fake-json-secret-value","displayName":"DeepSeek","password":"smtp-secret-value"}
        """
        let output = PrivacyRedactor.redact(input)
        XCTAssertFalse(output.contains("fake-json-secret-value"), output)
        XCTAssertFalse(output.contains("smtp-secret-value"), output)
        XCTAssertTrue(output.contains("DeepSeek"), output)
        XCTAssertTrue(output.contains(PrivacyRedactor.redactedPlaceholder), output)
    }

    func testKeyNameGateStillFlagsPortableForbiddenFields() {
        let json = Data("""
        {"settings":{"accounts":[]},"secretRef":"ref-should-flag","passwordRef":"smtp-ref"}
        """.utf8)
        let hits = PrivacyRedactor.forbiddenExportFieldNames(inJSON: json)
        XCTAssertTrue(hits.contains("secretRef"), "\(hits)")
        XCTAssertTrue(hits.contains("passwordRef"), "\(hits)")
        XCTAssertTrue(PrivacyRedactor.containsForbiddenExportFields(json))
    }

    func testKeyNameGateDoesNotTreatEmailValuesAsForbiddenKeys() {
        let json = Data("""
        {"format":"smartbalance.portable-settings","email":{"fromAddress":"alerts@example.test"}}
        """.utf8)
        XCTAssertFalse(PrivacyRedactor.containsForbiddenExportFields(json))
        XCTAssertTrue(PrivacyRedactor.forbiddenExportFieldNames(inJSON: json).isEmpty)
    }

    func testRedactDataPreservesUTF8AndScrubsSecrets() {
        let data = Data("Bearer FAKESECRET_w3x4y5z6a7b8c9d0e1f2 mailed to owner@example.test".utf8)
        let redacted = PrivacyRedactor.redact(data)
        let text = String(data: redacted, encoding: .utf8) ?? ""
        XCTAssertFalse(text.contains("FAKESECRET_w3x4y5z6a7b8c9d0e1f2"))
        XCTAssertFalse(text.contains("owner@example.test"))
    }
}
