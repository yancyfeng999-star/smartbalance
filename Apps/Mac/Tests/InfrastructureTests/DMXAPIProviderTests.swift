import XCTest
@testable import Domain
@testable import Infrastructure

final class DMXAPIProviderTests: XCTestCase {
    /// Docs: https://doc.dmxapi.cn/yuer.html
    private let fixtureJSON = """
    {
      "success": true,
      "data": {
        "username": "dmx_user",
        "quota": 1000000,
        "used_quota": 250000
      }
    }
    """

    private func account(userId: String? = "12345") -> BalanceAccount {
        BalanceAccount(kind: .dmxapi, displayName: "DMX", userId: userId)
    }

    private func credentials(token: String = "sys-token", userId: String? = "12345") -> ProviderCredentials {
        ProviderCredentials(apiKey: token, baseURL: "https://www.dmxapi.cn", userId: userId)
    }

    func testQuotaMapsToCNYAndHeaders() async throws {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = DMXAPIBalanceProvider(http: http)
        let snapshot = try await provider.fetchBalance(account: account(), credentials: credentials())

        // 1000000 / 500000 = 2.0 CNY
        XCTAssertEqual(snapshot.amount!, 2.0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.used!, 0.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.total!, 2.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.unit, "¥")
        XCTAssertEqual(snapshot.providerKind, .dmxapi)
        XCTAssertEqual(snapshot.source, .api)
        XCTAssertEqual(snapshot.status, .healthy)
        XCTAssertTrue(snapshot.detail.contains("dmx_user"))
        XCTAssertTrue(snapshot.detail.contains("12345"))
        XCTAssertEqual(http.authorizationHeaders.first, "Bearer sys-token")
        XCTAssertEqual(http.customHeaders["Dmx-Api-User"]?.first, "12345")
    }

    func testMissingUserIdThrows() async {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = DMXAPIBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: account(userId: nil),
                credentials: credentials(userId: nil)
            )
            XCTFail("expected missingUserId")
        } catch BalanceProviderError.missingUserId {
            XCTAssertEqual(http.callCount, 0)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testEmptyTokenThrowsMissingCredential() async {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = DMXAPIBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: account(),
                credentials: credentials(token: "")
            )
            XCTFail("expected missingCredential")
        } catch BalanceProviderError.missingCredential {
            XCTAssertEqual(http.callCount, 0)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testSuccessFalseThrowsProviderMessage() async {
        let json = #"{"success":false,"message":"获取用户信息失败"}"#
        let http = MockHTTPClient(statusCode: 200, json: json)
        let provider = DMXAPIBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(account: account(), credentials: credentials())
            XCTFail("expected providerMessage")
        } catch BalanceProviderError.providerMessage(let msg) {
            XCTAssertTrue(msg.contains("失败") || !msg.isEmpty)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testRegistry() {
        XCTAssertEqual(ProviderRegistry.provider(for: .dmxapi).kind, .dmxapi)
        XCTAssertEqual(ProviderKind.dmxapi.displayName, "DMXAPI")
        XCTAssertEqual(ProviderKind.dmxapi.defaultBaseURL, "https://www.dmxapi.cn")
        XCTAssertTrue(ProviderKind.dmxapi.needsUserId)
        XCTAssertFalse(ProviderKind.dmxapi.needsBaseURL)
    }
}
