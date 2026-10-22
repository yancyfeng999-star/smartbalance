import Foundation
import XCTest
@testable import Domain
@testable import Infrastructure

final class BytebroadProviderTests: XCTestCase {
    private let fixture = #"{"success":true,"data":{"id":1234,"quota":6250000,"used_quota":1250000}}"#
    private var account: BalanceAccount { BalanceAccount(kind: .bytebroad, userId: "1234") }
    private var credentials: ProviderCredentials { ProviderCredentials(apiKey: "session=fixture-session", userId: "1234") }

    func testWalletAndCumulativeUsageAreCNY() async throws {
        let http = MockHTTPClient(json: fixture)
        let inputAccount = account
        let result = try await BytebroadBalanceProvider(http: http).fetchBalance(account: inputAccount, credentials: credentials)
        XCTAssertEqual(result.providerKind, .bytebroad)
        XCTAssertEqual(result.id, inputAccount.id)
        XCTAssertEqual(try XCTUnwrap(result.amount), 12.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.used), 2.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.total), 15, accuracy: 0.0001)
        XCTAssertEqual(result.unit, "¥")
        XCTAssertEqual(http.customHeaders["Cookie"], ["session=fixture-session"])
        XCTAssertEqual(http.customHeaders["New-API-User"], ["1234"])
        XCTAssertTrue(http.authorizationHeaders.isEmpty)
    }

    func testRequestIgnoresUntrustedBaseURLOverrides() async throws {
        let http = MockHTTPClient(json: fixture)
        var input = credentials
        input.baseURL = "https://untrusted.invalid"
        var customAccount = account
        customAccount.baseURL = "https://also-untrusted.invalid"
        _ = try await BytebroadBalanceProvider(http: http).fetchBalance(account: customAccount, credentials: input)
        XCTAssertEqual(http.requestedURLs, ["https://token.bytebroad.com.cn/api/user/self"])
    }

    func testZeroBalanceAndNoDailyUsageDoNotFail() async throws {
        let http = MockHTTPClient(json: #"{"success":true,"data":{"quota":0,"used_quota":0}}"#)
        let result = try await BytebroadBalanceProvider(http: http).fetchBalance(account: account, credentials: credentials)
        XCTAssertEqual(result.amount, 0)
        XCTAssertEqual(result.used, 0)
        XCTAssertEqual(result.status, .depleted)
        XCTAssertNil(result.errorMessage)
    }

    func testMissingUsageHistoryStillReturnsWallet() async throws {
        let http = MockHTTPClient(json: #"{"success":true,"data":{"quota":"2500000"}}"#)
        let result = try await BytebroadBalanceProvider(http: http).fetchBalance(account: account, credentials: credentials)
        XCTAssertEqual(result.amount, 5)
        XCTAssertNil(result.used)
    }

    func testNegativeBalanceIsDepletedRatherThanLoginFailure() async throws {
        let http = MockHTTPClient(json: #"{"success":true,"data":{"quota":-500000,"used_quota":0}}"#)
        let result = try await BytebroadBalanceProvider(http: http).fetchBalance(account: account, credentials: credentials)
        XCTAssertEqual(result.amount, -1)
        XCTAssertEqual(result.status, .depleted)
    }

    func testInvalidBalancesAreNotSilentlyZero() async {
        for value in ["null", "true", "false", #""NaN""#, "{}", "[]"] {
            let http = MockHTTPClient(json: "{\"success\":true,\"data\":{\"quota\":\(value)}}")
            do {
                _ = try await BytebroadBalanceProvider(http: http).fetchBalance(account: account, credentials: credentials)
                XCTFail("Expected invalid quota to fail")
            } catch BalanceProviderError.decodeFailed { }
            catch { XCTFail("Unexpected error type") }
        }
    }

    func testUnauthorizedRequiresLoginAndNeverRetriesWithAnotherAuthMode() async {
        for code in [401, 403] {
            let http = MockHTTPClient(statusCode: code, json: "private-upstream-marker")
            do {
                _ = try await BytebroadBalanceProvider(http: http).fetchBalance(account: account, credentials: credentials)
                XCTFail("Expected authentication error")
            } catch BalanceProviderError.authenticationExpired { XCTAssertEqual(http.callCount, 1) }
            catch { XCTFail("Unexpected error type") }
        }
    }

    func testBusinessLoginExpiryIsDistinctFromQueryFailure() async {
        let http = MockHTTPClient(json: #"{"success":false,"message":"未登录或登录已过期，请重新登录"}"#)
        do {
            _ = try await BytebroadBalanceProvider(http: http).fetchBalance(account: account, credentials: credentials)
            XCTFail("Expected login-expired error")
        } catch BalanceProviderError.authenticationExpired { }
        catch { XCTFail("Unexpected error type") }
    }

    func testUpstreamErrorsNeverExposeResponseBody() async {
        for code in [302, 429, 500] {
            let http = MockHTTPClient(statusCode: code, json: "fixture-private-marker")
            do {
                _ = try await BytebroadBalanceProvider(http: http).fetchBalance(account: account, credentials: credentials)
                XCTFail("Expected query failure")
            } catch let error as BalanceProviderError {
                guard case .httpStatus = error else { return XCTFail("Not an HTTP failure") }
                XCTAssertFalse(error.localizedDescription.contains("fixture-private-marker"))
            } catch { XCTFail("Unexpected error type") }
        }
    }

    func testBusinessQueryFailureDoesNotClaimLoggedOutOrExposeMessage() async {
        let http = MockHTTPClient(json: #"{"success":false,"message":"fixture-private-marker"}"#)
        do {
            _ = try await BytebroadBalanceProvider(http: http).fetchBalance(account: account, credentials: credentials)
            XCTFail("Expected query failure")
        } catch let error as BalanceProviderError {
            guard case .providerMessage = error else { return XCTFail("Not a business query failure") }
            XCTAssertFalse(error.localizedDescription.contains("fixture-private-marker"))
        } catch { XCTFail("Unexpected error type") }
    }

    func testDifferentAccountResponseIsRejected() async {
        let http = MockHTTPClient(json: #"{"success":true,"data":{"id":9999,"quota":500000}}"#)
        do {
            _ = try await BytebroadBalanceProvider(http: http).fetchBalance(account: account, credentials: credentials)
            XCTFail("Expected account mismatch")
        } catch BalanceProviderError.providerMessage(let message) { XCTAssertTrue(message.contains("不一致")) }
        catch { XCTFail("Unexpected error type") }
    }

    func testWrongCurrencyAndHTMLResponsesFailWithoutLeakingContent() async {
        for body in [#"{"success":true,"data":{"quota":500000,"currency":"USD"}}"#, "<html>fixture-private-marker</html>"] {
            let http = MockHTTPClient(json: body)
            do {
                _ = try await BytebroadBalanceProvider(http: http).fetchBalance(account: account, credentials: credentials)
                XCTFail("Expected malformed wallet response")
            } catch let error as BalanceProviderError {
                guard case .decodeFailed = error else { return XCTFail("Expected decoding failure") }
                XCTAssertFalse(error.localizedDescription.contains("fixture-private-marker"))
            } catch { XCTFail("Unexpected error type") }
        }
    }

    func testMissingCredentialsOrIDFailBeforeAnyRequest() async {
        for input in [ProviderCredentials(apiKey: ""), ProviderCredentials(apiKey: "fixture-session"), ProviderCredentials(apiKey: "session=fixture-session", userId: "bad\r\nheader")] {
            let http = MockHTTPClient(json: fixture)
            do {
                _ = try await BytebroadBalanceProvider(http: http).fetchBalance(account: BalanceAccount(kind: .bytebroad), credentials: input)
                XCTFail("Expected incomplete credentials")
            } catch { XCTAssertEqual(http.callCount, 0) }
        }
    }

    func testTimeoutAndCancellationPropagate() async {
        for code in [URLError.timedOut, .cancelled] {
            let http = FailingBytebroadHTTP(code: code)
            do {
                _ = try await BytebroadBalanceProvider(http: http).fetchBalance(account: account, credentials: credentials)
                XCTFail("Expected transport error")
            } catch let error as URLError { XCTAssertEqual(error.code, code) }
            catch { XCTFail("Unexpected error type") }
        }
    }

    func testProviderIsRegistered() {
        XCTAssertEqual(ProviderRegistry.provider(for: .bytebroad).kind, .bytebroad)
    }
}

private struct FailingBytebroadHTTP: HTTPClient {
    let code: URLError.Code
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) { throw URLError(code) }
}
