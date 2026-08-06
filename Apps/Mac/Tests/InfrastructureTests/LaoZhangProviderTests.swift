import XCTest
@testable import Domain
@testable import Infrastructure

final class LaoZhangProviderTests: XCTestCase {
    /// Docs: https://docs.laozhang.ai/api-capabilities/balance-query
    private let fixtureJSON = """
    {
      "success": true,
      "message": null,
      "data": {
        "id": 19489,
        "username": "demo_user",
        "display_name": "demo_user",
        "quota": 24997909,
        "used_quota": 10027091,
        "request_count": 339,
        "group": "svip"
      }
    }
    """

    private func account() -> BalanceAccount {
        BalanceAccount(kind: .laozhang, displayName: "老张")
    }

    func testQuotaMapsToUSDAndRawAuthHeader() async throws {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = LaoZhangBalanceProvider(http: http)
        let snapshot = try await provider.fetchBalance(
            account: account(),
            credentials: ProviderCredentials(apiKey: "lz-access-token")
        )

        // 24997909 / 500000 ≈ 49.995818 USD × 7 ≈ 349.97 CNY
        let usd = 24997909.0 / 500_000.0
        let cny = usd * LaoZhangBalanceProvider.cnyPerUSD
        XCTAssertEqual(snapshot.amount!, cny, accuracy: 0.01)
        XCTAssertEqual(snapshot.unit, "¥")
        XCTAssertEqual(snapshot.providerKind, .laozhang)
        XCTAssertEqual(snapshot.source, .api)
        XCTAssertEqual(snapshot.status, .healthy)
        XCTAssertTrue(snapshot.detail.contains("demo_user"))
        XCTAssertTrue(snapshot.detail.contains("svip"))
        XCTAssertTrue(snapshot.detail.contains("339"))
        XCTAssertTrue(snapshot.detail.contains("¥") || snapshot.detail.contains("$"))
        // 裸令牌，不加 Bearer
        XCTAssertEqual(http.authorizationHeaders.first, "lz-access-token")
        XCTAssertFalse(http.authorizationHeaders.first?.hasPrefix("Bearer ") ?? true)
    }

    func testEmptyTokenThrowsMissingCredential() async {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = LaoZhangBalanceProvider(http: http)
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

    func testSuccessFalseThrowsProviderMessage() async {
        let json = """
        {"success":false,"message":"Unauthorized"}
        """
        let http = MockHTTPClient(statusCode: 200, json: json)
        let provider = LaoZhangBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: account(),
                credentials: ProviderCredentials(apiKey: "x")
            )
            XCTFail("expected providerMessage")
        } catch BalanceProviderError.providerMessage(let msg) {
            XCTAssertTrue(msg.contains("Unauthorized") || !msg.isEmpty)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testHTTP401() async {
        let http = MockHTTPClient(statusCode: 401, body: Data("Unauthorized".utf8))
        let provider = LaoZhangBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: account(),
                credentials: ProviderCredentials(apiKey: "bad")
            )
            XCTFail("expected httpStatus")
        } catch let error as BalanceProviderError {
            guard case .httpStatus(let code, _) = error else {
                return XCTFail("expected httpStatus, got \(error)")
            }
            XCTAssertEqual(code, 401)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testRegistry() {
        XCTAssertEqual(ProviderRegistry.provider(for: .laozhang).kind, .laozhang)
        XCTAssertEqual(ProviderKind.laozhang.displayName, "老张 API")
        XCTAssertEqual(ProviderKind.laozhang.defaultBaseURL, "https://api2.laozhang.ai")
        XCTAssertFalse(ProviderKind.laozhang.needsBaseURL)
        XCTAssertFalse(ProviderKind.laozhang.needsUserId)
    }
}
