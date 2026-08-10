import XCTest
@testable import Infrastructure
@testable import Domain

final class DeepSeekProviderTests: XCTestCase {
    private let fixtureJSON = """
    {"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"18.5","granted_balance":"0","topped_up_balance":"18.5"}]}
    """

    private let unavailableJSON = """
    {"is_available":false,"balance_infos":[]}
    """

    func testDecodeSuccessAmountCNY() async throws {
        let http = MockHTTPClient(statusCode: 200, json: fixtureJSON)
        let provider = DeepSeekBalanceProvider(http: http)
        let account = BalanceAccount(kind: .deepseek, displayName: "DS")
        let snapshot = try await provider.fetchBalance(
            account: account,
            credentials: ProviderCredentials(apiKey: "sk-test")
        )

        XCTAssertEqual(snapshot.amount, 18.5)
        XCTAssertNil(snapshot.used)
        XCTAssertNil(snapshot.total)
        XCTAssertEqual(snapshot.unit, "¥")
        XCTAssertEqual(snapshot.source, .api)
        XCTAssertEqual(snapshot.providerKind, .deepseek)
        XCTAssertEqual(snapshot.status, .healthy)
    }

    func testHTTP401ThrowsHttpStatus() async {
        let http = MockHTTPClient(statusCode: 401, body: Data("unauthorized".utf8))
        let provider = DeepSeekBalanceProvider(http: http)
        let account = BalanceAccount(kind: .deepseek)

        do {
            _ = try await provider.fetchBalance(
                account: account,
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
        let provider = DeepSeekBalanceProvider(http: http)
        let account = BalanceAccount(kind: .deepseek)

        do {
            _ = try await provider.fetchBalance(
                account: account,
                credentials: ProviderCredentials(apiKey: "")
            )
            XCTFail("expected BalanceProviderError.missingCredential")
        } catch let error as BalanceProviderError {
            guard case .missingCredential = error else {
                return XCTFail("expected missingCredential, got \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testIsAvailableFalseReturnsErrorStatus() async throws {
        let http = MockHTTPClient(statusCode: 200, json: unavailableJSON)
        let provider = DeepSeekBalanceProvider(http: http)
        let account = BalanceAccount(kind: .deepseek)
        let snapshot = try await provider.fetchBalance(
            account: account,
            credentials: ProviderCredentials(apiKey: "sk-test")
        )

        XCTAssertEqual(snapshot.status, .error)
        XCTAssertEqual(snapshot.errorMessage, "is_available=false")
        XCTAssertNil(snapshot.amount)
        XCTAssertEqual(snapshot.source, .api)
    }
}
