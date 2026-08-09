import XCTest
@testable import Infrastructure
@testable import Domain

final class MiniMaxProviderTests: XCTestCase {
    private let fixtureJSON = """
    {"available_amount":"251.20","cash_balance":"251.20","voucher_balance":"0.00","credit_balance":"0.00","owed_amount":"0.00","balance_alert_switch":true,"balance_alert_threshold":"50","base_resp":{"status_code":0,"status_msg":"success"}}
    """

    func testDecodeAvailableAmount() async throws {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = MiniMaxBalanceProvider(http: http)
        let account = BalanceAccount(kind: .minimax, displayName: "MM")
        let snapshot = try await provider.fetchBalance(
            account: account,
            credentials: ProviderCredentials(apiKey: "eyJhbGciOiJIUzI1NiJ9.test")
        )

        XCTAssertEqual(snapshot.amount!, 251.20, accuracy: 0.001)
        XCTAssertEqual(snapshot.unit, "¥")
        XCTAssertEqual(snapshot.providerKind, .minimax)
        XCTAssertEqual(snapshot.status, .healthy)
        XCTAssertTrue(snapshot.detail.contains("API 余额"))
        let cookie = http.customHeaders["Cookie"]?.first ?? ""
        XCTAssertTrue(cookie.contains("_token=eyJhbGciOiJIUzI1NiJ9.test"))
    }

    func testSendsXGroupIdFromUserId() async throws {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = MiniMaxBalanceProvider(http: http)
        let account = BalanceAccount(kind: .minimax, userId: "2028653292564783846")
        _ = try await provider.fetchBalance(
            account: account,
            credentials: ProviderCredentials(apiKey: "jwt", userId: "2028653292564783846")
        )
        XCTAssertEqual(http.customHeaders["X-Group-Id"]?.first, "2028653292564783846")
    }

    func testCookiePaste() async throws {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = MiniMaxBalanceProvider(http: http)
        let account = BalanceAccount(kind: .minimax)
        _ = try await provider.fetchBalance(
            account: account,
            credentials: ProviderCredentials(apiKey: "_token=jwt-from-cookie; other=1")
        )
        let cookie = http.customHeaders["Cookie"]?.first ?? ""
        XCTAssertEqual(cookie, "_token=jwt-from-cookie")
    }

    func testLoginExpiredStatusCode() async {
        let json = #"{"base_resp":{"status_code":1004,"status_msg":"cookie is missing, log in again"}}"#
        let http = MockHTTPClient(statusCode: 200, json: json)
        let provider = MiniMaxBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: BalanceAccount(kind: .minimax),
                credentials: ProviderCredentials(apiKey: "x")
            )
            XCTFail("expected providerMessage")
        } catch BalanceProviderError.providerMessage(let msg) {
            XCTAssertTrue(msg.contains("登录已失效") || msg.contains("cookie"))
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testEmptyTokenThrows() async {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = MiniMaxBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: BalanceAccount(kind: .minimax),
                credentials: ProviderCredentials(apiKey: "")
            )
            XCTFail("expected missingCredential")
        } catch BalanceProviderError.missingCredential {
            XCTAssertEqual(http.callCount, 0)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testRegistryAndKind() {
        XCTAssertEqual(ProviderRegistry.provider(for: .minimax).kind, .minimax)
        XCTAssertFalse(ProviderKind.minimax.isManualEntry)
        XCTAssertTrue(ProviderKind.minimax.needsUserId)
        XCTAssertEqual(ProviderKind.minimax.displayName, "MiniMax")
        XCTAssertTrue(ProviderKind.apinebula.isManualEntry)
    }
}
