import XCTest
@testable import Infrastructure
@testable import Domain

final class OpenRouterProviderTests: XCTestCase {
    /// Official docs example: total_credits 100.5 − total_usage 25.75 = 74.75 remaining.
    private let fixtureJSON = """
    {"data":{"total_credits":100.5,"total_usage":25.75}}
    """

    private let depletedJSON = """
    {"data":{"total_credits":10,"total_usage":10}}
    """

    private func account() -> BalanceAccount {
        BalanceAccount(kind: .openrouter, displayName: "OR")
    }

    // MARK: - Success fixture

    func testCreditsRemainingAmount() async throws {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = OpenRouterBalanceProvider(http: http)
        let snapshot = try await provider.fetchBalance(
            account: account(),
            credentials: ProviderCredentials(apiKey: "sk-or-test")
        )

        XCTAssertEqual(snapshot.amount!, 74.75, accuracy: 0.0001)
        XCTAssertEqual(snapshot.unit, "USD")
        XCTAssertEqual(snapshot.used!, 25.75, accuracy: 0.0001)
        XCTAssertEqual(snapshot.total!, 100.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.source, .api)
        XCTAssertEqual(snapshot.providerKind, .openrouter)
        XCTAssertEqual(snapshot.status, .healthy)
        XCTAssertNotNil(snapshot.remainingPercent)
        XCTAssertEqual(snapshot.remainingPercent!, (74.75 / 100.5) * 100, accuracy: 0.01)
        XCTAssertTrue(snapshot.detail.contains("100.50") || snapshot.detail.contains("充值"))
        XCTAssertTrue(snapshot.detail.contains("25.75") || snapshot.detail.contains("已用"))
        XCTAssertEqual(http.callCount, 1)
        XCTAssertEqual(http.authorizationHeaders.first, "Bearer sk-or-test")
    }

    func testDepletedWhenUsageEqualsCredits() async throws {
        let http = MockHTTPClient(statusCode: 200, json: depletedJSON)
        let provider = OpenRouterBalanceProvider(http: http)
        let snapshot = try await provider.fetchBalance(
            account: account(),
            credentials: ProviderCredentials(apiKey: "sk-or-test")
        )

        XCTAssertEqual(snapshot.amount!, 0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.status, .depleted)
        XCTAssertEqual(snapshot.remainingPercent!, 0, accuracy: 0.0001)
    }

    // MARK: - Errors

    func testHTTP401ThrowsHttpStatus() async {
        let http = MockHTTPClient(statusCode: 401, body: Data("unauthorized".utf8))
        let provider = OpenRouterBalanceProvider(http: http)

        do {
            _ = try await provider.fetchBalance(
                account: account(),
                credentials: ProviderCredentials(apiKey: "sk-bad")
            )
            XCTFail("expected BalanceProviderError.httpStatus")
        } catch let error as BalanceProviderError {
            guard case .httpStatus(let code, let body) = error else {
                return XCTFail("expected httpStatus, got \(error)")
            }
            XCTAssertEqual(code, 401)
            XCTAssertTrue(body.contains("unauthorized"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testEmptyAPIKeyThrowsMissingCredential() async {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = OpenRouterBalanceProvider(http: http)

        do {
            _ = try await provider.fetchBalance(
                account: account(),
                credentials: ProviderCredentials(apiKey: "")
            )
            XCTFail("expected missingCredential")
        } catch let error as BalanceProviderError {
            guard case .missingCredential = error else {
                return XCTFail("expected missingCredential, got \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testMalformedJSONThrowsDecodeFailed() async {
        let http = MockHTTPClient(statusCode: 200, json: #"{"data":{}}"#)
        let provider = OpenRouterBalanceProvider(http: http)

        do {
            _ = try await provider.fetchBalance(
                account: account(),
                credentials: ProviderCredentials(apiKey: "sk-or-test")
            )
            XCTFail("expected decodeFailed")
        } catch let error as BalanceProviderError {
            guard case .decodeFailed = error else {
                return XCTFail("expected decodeFailed, got \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Registry

    func testRegistryMapsOpenRouter() {
        XCTAssertEqual(ProviderRegistry.provider(for: .openrouter).kind, .openrouter)
    }
}
