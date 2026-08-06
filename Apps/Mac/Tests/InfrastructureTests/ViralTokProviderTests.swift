import XCTest
@testable import Domain
@testable import Infrastructure

final class ViralTokProviderTests: XCTestCase {
    /// Docs: https://docs.viraltok.ai/zh/api-reference/common/user-balance
    private let fixtureJSON = """
    {"code":20000,"msg":"ok","data":{"balance":100.5,"used_coin":20.3,"available":80.2}}
    """

    private func account() -> BalanceAccount {
        BalanceAccount(kind: .viraltok, displayName: "吉米")
    }

    func testAvailableAmountFromDocsFixture() async throws {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = ViralTokBalanceProvider(http: http)
        let snapshot = try await provider.fetchBalance(
            account: account(),
            credentials: ProviderCredentials(apiKey: "sk-vt-test")
        )

        // 吉米币按 7.3 折人民币：80.2 * 7.3 = 585.46
        let rate = ViralTokBalanceProvider.cnyPerCoin
        XCTAssertEqual(snapshot.amount!, 80.2 * rate, accuracy: 0.01)
        XCTAssertEqual(snapshot.unit, "¥")
        XCTAssertEqual(snapshot.total!, 100.5 * rate, accuracy: 0.01)
        XCTAssertEqual(snapshot.used!, 20.3 * rate, accuracy: 0.01)
        XCTAssertEqual(snapshot.source, .api)
        XCTAssertEqual(snapshot.providerKind, .viraltok)
        XCTAssertEqual(snapshot.status, .healthy)
        XCTAssertNotNil(snapshot.remainingPercent)
        XCTAssertEqual(snapshot.remainingPercent!, (80.2 / 100.5) * 100, accuracy: 0.01)
        XCTAssertTrue(snapshot.detail.contains("吉米币") || snapshot.detail.contains("¥"))
        XCTAssertEqual(http.callCount, 1)
        XCTAssertEqual(http.authorizationHeaders.first, "Bearer sk-vt-test")
    }

    func testEmptyAPIKeyThrowsMissingCredential() async {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = ViralTokBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: account(),
                credentials: ProviderCredentials(apiKey: "")
            )
            XCTFail("expected missingCredential")
        } catch BalanceProviderError.missingCredential {
            XCTAssertEqual(http.callCount, 0)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testHTTP401ThrowsHttpStatus() async {
        let http = MockHTTPClient(statusCode: 401, body: Data("unauthorized".utf8))
        let provider = ViralTokBalanceProvider(http: http)
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

    func testBizCodeFailure() async {
        let json = """
        {"code":40001,"msg":"invalid key","data":null}
        """
        let http = MockHTTPClient(statusCode: 200, json: json)
        let provider = ViralTokBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: account(),
                credentials: ProviderCredentials(apiKey: "x")
            )
            XCTFail("expected providerMessage")
        } catch BalanceProviderError.providerMessage(let msg) {
            XCTAssertTrue(msg.contains("invalid") || msg.contains("key") || !msg.isEmpty)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testRegistry() {
        XCTAssertEqual(ProviderRegistry.provider(for: .viraltok).kind, .viraltok)
        XCTAssertEqual(ProviderKind.viraltok.displayName, "ViralTok（吉米）")
        XCTAssertEqual(ProviderKind.viraltok.defaultBaseURL, "https://api.viraltok.ai")
        XCTAssertFalse(ProviderKind.viraltok.needsBaseURL)
    }
}
