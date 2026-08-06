import XCTest
@testable import Infrastructure
@testable import Domain

final class NewAPIProviderTests: XCTestCase {
    /// Standard New-API envelope: quota 500000 → 1.0 USD.
    private let standardJSON = """
    {"data":{"quota":500000,"used_quota":100000,"username":"u1"}}
    """

    /// Unlimited quota flag.
    private let unlimitedJSON = """
    {"data":{"quota":0,"used_quota":0,"unlimited_quota":true,"username":"u1"}}
    """

    /// Top-level fields without `data` wrapper.
    private let topLevelJSON = """
    {"quota":500000,"used_quota":100000,"display_name":"u-top"}
    """

    private func account(baseURL: String = "https://relay.example.com") -> BalanceAccount {
        BalanceAccount(kind: .newapi, displayName: "Relay", baseURL: baseURL)
    }

    private func credentials(token: String = "tok-test") -> ProviderCredentials {
        ProviderCredentials(apiKey: token, baseURL: "https://relay.example.com")
    }

    // MARK: - Fixture matrix

    func testStandardDataQuotaMapsToOneUSD() async throws {
        let http = MockHTTPClient(statusCode: 200, json: standardJSON)
        let provider = NewAPIBalanceProvider(http: http)
        let snapshot = try await provider.fetchBalance(account: account(), credentials: credentials())

        XCTAssertEqual(snapshot.amount, 1.0)
        XCTAssertEqual(snapshot.unit, "USD")
        XCTAssertEqual(snapshot.used, 100_000)
        XCTAssertEqual(snapshot.total, 600_000)
        XCTAssertEqual(snapshot.source, .api)
        XCTAssertEqual(snapshot.providerKind, .newapi)
        XCTAssertEqual(snapshot.status, .healthy)
        XCTAssertTrue(snapshot.detail.contains("u1"))
        XCTAssertTrue(snapshot.detail.contains("500000") || snapshot.detail.contains("剩余点数"))
    }

    func testUnlimitedQuotaHealthyAndDetailContains无限() async throws {
        let http = MockHTTPClient(statusCode: 200, json: unlimitedJSON)
        let provider = NewAPIBalanceProvider(http: http)
        let snapshot = try await provider.fetchBalance(account: account(), credentials: credentials())

        XCTAssertEqual(snapshot.status, .healthy)
        XCTAssertTrue(
            snapshot.detail.contains("无限"),
            "detail should mention unlimited; got: \(snapshot.detail)"
        )
        XCTAssertEqual(snapshot.unit, "USD")
        XCTAssertEqual(snapshot.source, .api)
        // amount nil + remainingPercent 100 so refreshAPI re-resolve cannot mark depleted
        XCTAssertNil(snapshot.amount)
        XCTAssertEqual(snapshot.remainingPercent, 100)
    }

    /// I1 regression: BalanceService.refreshAPI always re-runs resolveStatus;
    /// unlimited fixture (quota 0) must stay healthy after that path.
    func testUnlimitedSurvivesRefreshAPIStyleReResolve() async throws {
        let http = MockHTTPClient(statusCode: 200, json: unlimitedJSON)
        let provider = NewAPIBalanceProvider(http: http)
        var snap = try await provider.fetchBalance(account: account(), credentials: credentials())

        // Same assignment as BalanceService.refreshAPI
        let amountTh = account().alertThreshold ?? 1
        let percentTh = account().alertPercentThreshold ?? 20
        snap.status = BalanceSnapshot.resolveStatus(
            amount: snap.amount,
            remainingPercent: snap.remainingPercent,
            amountThreshold: amountTh,
            percentThreshold: percentTh
        )

        XCTAssertEqual(snap.status, .healthy, "unlimited must not become depleted after re-resolve")
        XCTAssertEqual(snap.remainingPercent, 100)
        XCTAssertNil(snap.amount)
        XCTAssertTrue(snap.detail.contains("无限"))
    }

    func testTopLevelWithoutDataWrapper() async throws {
        let http = MockHTTPClient(statusCode: 200, json: topLevelJSON)
        let provider = NewAPIBalanceProvider(http: http)
        let snapshot = try await provider.fetchBalance(account: account(), credentials: credentials())

        XCTAssertEqual(snapshot.amount, 1.0)
        XCTAssertEqual(snapshot.unit, "USD")
        XCTAssertEqual(snapshot.used, 100_000)
        XCTAssertTrue(snapshot.detail.contains("u-top"))
        XCTAssertEqual(snapshot.providerKind, .newapi)
    }

    // MARK: - Auth retry

    func testBearerThenBareTokenOn401() async throws {
        let body = Data(standardJSON.utf8)
        let http = MockHTTPClient(responses: [
            (statusCode: 401, body: Data("unauthorized".utf8)),
            (statusCode: 200, body: body),
        ])
        let provider = NewAPIBalanceProvider(http: http)
        let snapshot = try await provider.fetchBalance(
            account: account(),
            credentials: credentials(token: "secret-token")
        )

        XCTAssertEqual(snapshot.amount, 1.0)
        XCTAssertEqual(http.callCount, 2)
        let auths = http.authorizationHeaders
        XCTAssertEqual(auths.count, 2)
        XCTAssertEqual(auths[0], "Bearer secret-token")
        XCTAssertEqual(auths[1], "secret-token")
    }

    func testBareTokenRetryOn403() async throws {
        let body = Data(standardJSON.utf8)
        let http = MockHTTPClient(responses: [
            (statusCode: 403, body: Data("forbidden".utf8)),
            (statusCode: 200, body: body),
        ])
        let provider = NewAPIBalanceProvider(http: http)
        let snapshot = try await provider.fetchBalance(account: account(), credentials: credentials())

        XCTAssertEqual(snapshot.amount, 1.0)
        XCTAssertEqual(http.callCount, 2)
    }

    func testBothAuthFailThrowsHttpStatus() async {
        let http = MockHTTPClient(responses: [
            (statusCode: 401, body: Data("no".utf8)),
            (statusCode: 401, body: Data("still no".utf8)),
        ])
        let provider = NewAPIBalanceProvider(http: http)

        do {
            _ = try await provider.fetchBalance(account: account(), credentials: credentials())
            XCTFail("expected BalanceProviderError.httpStatus")
        } catch let error as BalanceProviderError {
            guard case .httpStatus(let code, let body) = error else {
                return XCTFail("expected httpStatus, got \(error)")
            }
            XCTAssertEqual(code, 401)
            XCTAssertTrue(body.contains("still no"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testEmptyAPIKeyThrowsMissingCredential() async {
        let http = MockHTTPClient(statusCode: 200, json: standardJSON)
        let provider = NewAPIBalanceProvider(http: http)

        do {
            _ = try await provider.fetchBalance(
                account: account(),
                credentials: ProviderCredentials(apiKey: "", baseURL: "https://relay.example.com")
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

    func testMissingBaseURLThrowsInvalidURL() async {
        let http = MockHTTPClient(statusCode: 200, json: standardJSON)
        let provider = NewAPIBalanceProvider(http: http)
        let bare = BalanceAccount(kind: .newapi, displayName: "NoBase", baseURL: nil)

        do {
            _ = try await provider.fetchBalance(
                account: bare,
                credentials: ProviderCredentials(apiKey: "tok")
            )
            XCTFail("expected invalidURL")
        } catch let error as BalanceProviderError {
            guard case .invalidURL = error else {
                return XCTFail("expected invalidURL, got \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
