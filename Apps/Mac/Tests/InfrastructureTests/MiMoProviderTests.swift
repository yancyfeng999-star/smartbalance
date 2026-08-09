import XCTest
@testable import Infrastructure
@testable import Domain

final class MiMoProviderTests: XCTestCase {
    private let fixtureJSON = """
    {"code":0,"message":"","data":{"balance":"101.78","frozenBalance":"0.00","currency":"CNY","overdraftLimit":"0.00","remainingOverdraftLimit":"0.00","giftBalance":"0.00","cashBalance":"101.78"}}
    """

    private func account(userId: String? = "373399195") -> BalanceAccount {
        BalanceAccount(kind: .mimo, displayName: "MiMo", userId: userId)
    }

    func testDecodeBalanceCNY() async throws {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = MiMoBalanceProvider(http: http)
        let snapshot = try await provider.fetchBalance(
            account: account(),
            credentials: ProviderCredentials(apiKey: "tok-abc", userId: "373399195")
        )

        XCTAssertEqual(snapshot.amount!, 101.78, accuracy: 0.001)
        XCTAssertEqual(snapshot.unit, "¥")
        XCTAssertEqual(snapshot.providerKind, .mimo)
        XCTAssertEqual(snapshot.status, .healthy)
        XCTAssertTrue(snapshot.detail.contains("UID 373399195"))
        let cookie = http.customHeaders["Cookie"]?.first ?? ""
        XCTAssertTrue(cookie.contains("api-platform_serviceToken=tok-abc"))
        XCTAssertTrue(cookie.contains("userId=373399195"))
    }

    func testCookiePasteExtractsTokenAndUserId() async throws {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = MiMoBalanceProvider(http: http)
        let cookie = "api-platform_serviceToken=tok-from-cookie; userId=999; other=1"
        let snapshot = try await provider.fetchBalance(
            account: account(userId: nil),
            credentials: ProviderCredentials(apiKey: cookie, userId: nil)
        )
        XCTAssertEqual(snapshot.amount!, 101.78, accuracy: 0.001)
        let sent = http.customHeaders["Cookie"]?.first ?? ""
        XCTAssertTrue(sent.contains("api-platform_serviceToken=tok-from-cookie"))
        XCTAssertTrue(sent.contains("userId=999"))
    }

    func testMissingUserIdThrows() async {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = MiMoBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: account(userId: nil),
                credentials: ProviderCredentials(apiKey: "tok", userId: nil)
            )
            XCTFail("expected missingUserId")
        } catch BalanceProviderError.missingUserId {
            XCTAssertEqual(http.callCount, 0)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testRegistryAndKind() {
        XCTAssertEqual(ProviderRegistry.provider(for: .mimo).kind, .mimo)
        XCTAssertFalse(ProviderKind.mimo.isManualEntry)
        XCTAssertTrue(ProviderKind.mimo.needsUserId)
        XCTAssertEqual(ProviderKind.mimo.displayName, "小米 MiMo")
    }
}

final class SessionCookieParserTests: XCTestCase {
    func testParseNamedCookie() {
        let raw = "Cookie: api-platform_serviceToken=abc123; userId=42"
        XCTAssertEqual(SessionCookieParser.value(named: "api-platform_serviceToken", in: raw), "abc123")
        XCTAssertEqual(SessionCookieParser.value(named: "userId", in: raw), "42")
    }

    func testMiniMaxTokenFromCookie() {
        let raw = "_token=eyJhbGciOiJIUzI1NiJ9.xx.yy; minimax_group_id_v2=1"
        XCTAssertEqual(SessionCookieParser.resolveMiniMaxToken(secret: raw), "eyJhbGciOiJIUzI1NiJ9.xx.yy")
        XCTAssertEqual(SessionCookieParser.resolveMiniMaxToken(secret: "plain-jwt"), "plain-jwt")
    }
}
