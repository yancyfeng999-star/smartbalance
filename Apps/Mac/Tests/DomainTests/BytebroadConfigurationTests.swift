import XCTest
@testable import Domain

final class BytebroadConfigurationTests: XCTestCase {
    func testProviderIsSelectableAndUsesBrowserSession() throws {
        let kind = try XCTUnwrap(ProviderKind(rawValue: "bytebroad"))
        XCTAssertTrue(ProviderKind.selectableCases.contains(kind))
        XCTAssertEqual(kind.displayName, "Bytebroad")
        XCTAssertTrue(kind.supportsBrowserSessionImport)
        XCTAssertFalse(kind.needsUserId)
        XCTAssertEqual(kind.defaultManualUnit, "¥")
    }

    func testProviderOnlyUsesOfficialHTTPSWallet() throws {
        let kind = try XCTUnwrap(ProviderKind(rawValue: "bytebroad"))
        XCTAssertEqual(kind.defaultBaseURL, "https://token.bytebroad.com.cn")
        XCTAssertEqual(kind.defaultConsoleURL, "https://token.bytebroad.com.cn/wallet")
        XCTAssertFalse(kind.allowsCustomAPIBaseURL)
        XCTAssertEqual(kind.resolveAPIBaseURL(accountBase: "https://untrusted.invalid"), kind.defaultBaseURL)
    }

    func testAccountRoundTripRetainsCredentialReference() throws {
        let kind = try XCTUnwrap(ProviderKind(rawValue: "bytebroad"))
        let original = BalanceAccount(kind: kind, secretRef: "fixture-reference")
        let restored = try JSONDecoder().decode(BalanceAccount.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(restored.kind, kind)
        XCTAssertEqual(restored.secretRef, original.secretRef)
    }
}
