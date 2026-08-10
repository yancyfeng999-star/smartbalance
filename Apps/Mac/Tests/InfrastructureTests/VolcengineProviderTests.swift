import XCTest
@testable import Infrastructure
@testable import Domain

final class VolcengineProviderTests: XCTestCase {
    private let sampleJSON = """
    {
      "ResponseMetadata": {
        "RequestId": "req-1",
        "Action": "QueryBalanceAcct",
        "Version": "2022-01-01",
        "Service": "billing",
        "Region": "cn-beijing"
      },
      "Result": {
        "AccountID": 2100000001,
        "AvailableBalance": "77.01",
        "CashBalance": "83.01",
        "CreditLimit": "0.00",
        "FreezeAmount": "5.01",
        "ArrearsBalance": "0.00"
      }
    }
    """

    private func account() -> BalanceAccount {
        BalanceAccount(kind: .volcengine, displayName: "火山测试")
    }

    private func credentials(
        ak: String = "AKLTTEST",
        sk: String = "SecretTestKey123"
    ) -> ProviderCredentials {
        ProviderCredentials(
            apiKey: VolcengineSigner.packCredentials(accessKeyId: ak, secretAccessKey: sk)
        )
    }

    func testPackUnpackCredentials() {
        let packed = VolcengineSigner.packCredentials(accessKeyId: "AK1", secretAccessKey: "SK1")
        XCTAssertEqual(packed, "AK1\nSK1")
        let pair = VolcengineSigner.unpackCredentials(packed)
        XCTAssertEqual(pair?.accessKeyId, "AK1")
        XCTAssertEqual(pair?.secretAccessKey, "SK1")

        let pipe = VolcengineSigner.unpackCredentials("AKx|SKy")
        XCTAssertEqual(pipe?.accessKeyId, "AKx")
        XCTAssertEqual(pipe?.secretAccessKey, "SKy")
    }

    func testSignProducesAuthorizationAndHeaders() throws {
        let body = Data("{}".utf8)
        let fixed = Date(timeIntervalSince1970: 1_700_000_000) // fixed for determinism of format only
        let signed = try VolcengineSigner.sign(
            method: "POST",
            host: "billing.volcengineapi.com",
            path: "/",
            query: ["Action": "QueryBalanceAcct", "Version": "2022-01-01"],
            body: body,
            accessKeyId: "AKLTTEST",
            secretAccessKey: "SecretTestKey123",
            service: "billing",
            region: "cn-beijing",
            contentType: "application/json",
            now: fixed
        )

        XCTAssertEqual(signed.method, "POST")
        XCTAssertTrue(signed.url.absoluteString.contains("Action=QueryBalanceAcct"))
        XCTAssertTrue(signed.url.absoluteString.contains("Version=2022-01-01"))
        XCTAssertEqual(signed.headers["Content-Type"], "application/json")
        XCTAssertEqual(signed.headers["Host"], "billing.volcengineapi.com")
        XCTAssertNotNil(signed.headers["X-Date"])
        XCTAssertNotNil(signed.headers["X-Content-Sha256"])
        let auth = signed.headers["Authorization"] ?? ""
        XCTAssertTrue(auth.hasPrefix("HMAC-SHA256 Credential=AKLTTEST/"))
        XCTAssertTrue(auth.contains("SignedHeaders=content-type;host;x-content-sha256;x-date"))
        XCTAssertTrue(auth.contains("Signature="))
        // same input → same signature
        let signed2 = try VolcengineSigner.sign(
            method: "POST",
            host: "billing.volcengineapi.com",
            path: "/",
            query: ["Action": "QueryBalanceAcct", "Version": "2022-01-01"],
            body: body,
            accessKeyId: "AKLTTEST",
            secretAccessKey: "SecretTestKey123",
            service: "billing",
            region: "cn-beijing",
            contentType: "application/json",
            now: fixed
        )
        XCTAssertEqual(signed.headers["Authorization"], signed2.headers["Authorization"])
    }

    func testQueryBalanceAcctMapsAvailableBalance() async throws {
        let http = MockHTTPClient(statusCode: 200, json: sampleJSON)
        let provider = VolcengineBalanceProvider(http: http)
        let snap = try await provider.fetchBalance(account: account(), credentials: credentials())

        XCTAssertEqual(snap.amount, 77.01)
        XCTAssertNil(snap.used)
        XCTAssertNil(snap.total)
        XCTAssertEqual(snap.unit, "¥")
        XCTAssertEqual(snap.providerKind, .volcengine)
        XCTAssertEqual(snap.source, .api)
        XCTAssertTrue(snap.detail.contains("现金") || snap.detail.contains("83"))
        XCTAssertTrue(snap.detail.contains("冻结") || snap.detail.contains("5.01"))
        XCTAssertEqual(snap.status, .healthy)
        XCTAssertEqual(http.authorizationHeaders.first?.hasPrefix("HMAC-SHA256"), true)
    }

    func testApiErrorInMetadataThrows() async {
        let errJSON = """
        {
          "ResponseMetadata": {
            "Error": { "Code": "InvalidAccessKey", "Message": "The access key is invalid" }
          }
        }
        """
        let http = MockHTTPClient(statusCode: 200, json: errJSON)
        let provider = VolcengineBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(account: account(), credentials: credentials())
            XCTFail("expected providerMessage")
        } catch BalanceProviderError.providerMessage(let msg) {
            XCTAssertTrue(msg.contains("invalid") || msg.contains("Invalid"))
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testMissingPackedCredentialThrows() async {
        let http = MockHTTPClient(statusCode: 200, json: sampleJSON)
        let provider = VolcengineBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: account(),
                credentials: ProviderCredentials(apiKey: "only-one-line-no-sk")
            )
            XCTFail("expected missingCredential")
        } catch BalanceProviderError.missingCredential {
            // ok
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testHttpErrorPropagates() async {
        let http = MockHTTPClient(statusCode: 403, body: Data("forbidden".utf8))
        let provider = VolcengineBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(account: account(), credentials: credentials())
            XCTFail("expected httpStatus")
        } catch BalanceProviderError.httpStatus(let code, _) {
            XCTAssertEqual(code, 403)
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    func testProviderKindFlags() {
        XCTAssertTrue(ProviderKind.volcengine.needsAccessKeyPair)
        XCTAssertTrue(ProviderKind.volcengine.needsSecret)
        XCTAssertFalse(ProviderKind.volcengine.needsUserId)
        XCTAssertEqual(ProviderKind.volcengine.defaultManualUnit, "¥")
        XCTAssertEqual(ProviderRegistry.provider(for: .volcengine).kind, .volcengine)
    }
}
