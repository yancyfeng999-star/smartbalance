import XCTest
@testable import Domain
@testable import Infrastructure

final class KimiProviderTests: XCTestCase {
    /// Docs: https://platform.kimi.com/docs/api/balance
    private let fixtureJSON = """
    {
      "code": 0,
      "data": {
        "available_balance": 49.58894,
        "voucher_balance": 46.58893,
        "cash_balance": 3.00001
      },
      "scode": "0x0",
      "status": true
    }
    """

    private func account() -> BalanceAccount {
        BalanceAccount(kind: .kimi, displayName: "Kimi")
    }

    func testAvailableBalanceFromDocsFixture() async throws {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = KimiBalanceProvider(http: http)
        let snapshot = try await provider.fetchBalance(
            account: account(),
            credentials: ProviderCredentials(apiKey: "sk-kimi-test")
        )

        XCTAssertEqual(snapshot.amount!, 49.58894, accuracy: 0.00001)
        XCTAssertEqual(snapshot.unit, "¥")
        XCTAssertEqual(snapshot.providerKind, .kimi)
        XCTAssertEqual(snapshot.source, .api)
        XCTAssertEqual(snapshot.status, .healthy)
        XCTAssertTrue(snapshot.detail.contains("代金券"))
        XCTAssertTrue(snapshot.detail.contains("现金"))
        XCTAssertEqual(http.authorizationHeaders.first, "Bearer sk-kimi-test")
    }

    func testEmptyKeyThrows() async {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = KimiBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: account(),
                credentials: ProviderCredentials(apiKey: "")
            )
            XCTFail("expected missingCredential")
        } catch BalanceProviderError.missingCredential {
            XCTAssertEqual(http.callCount, 0)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testBizCodeNonZero() async {
        let json = #"{"code":1,"status":false,"message":"Unauthorized","data":null}"#
        let http = MockHTTPClient(statusCode: 200, json: json)
        let provider = KimiBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: account(),
                credentials: ProviderCredentials(apiKey: "x")
            )
            XCTFail("expected providerMessage")
        } catch BalanceProviderError.providerMessage(let msg) {
            XCTAssertFalse(msg.isEmpty)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testRegistry() {
        XCTAssertEqual(ProviderRegistry.provider(for: .kimi).kind, .kimi)
        XCTAssertEqual(ProviderKind.kimi.displayName, "Kimi（月之暗面）")
        XCTAssertEqual(ProviderKind.kimi.defaultBaseURL, "https://api.moonshot.cn")
        XCTAssertFalse(ProviderKind.kimi.needsBaseURL)
    }
}
