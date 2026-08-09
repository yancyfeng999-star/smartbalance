import XCTest
@testable import Infrastructure
@testable import Domain

final class ApinebulaProviderTests: XCTestCase {
    /// 实测量级：quota 99734740 → ¥199.46948；此处用整点 500000 → ¥1
    private let standardJSON = """
    {"success":true,"data":{"quota":99734740,"used_quota":20265260,"username":"yancyfeng999","id":12210}}
    """

    private func account(userId: String? = "12210") -> BalanceAccount {
        BalanceAccount(
            kind: .apinebula,
            displayName: "apinebula",
            userId: userId,
            alertThreshold: 10
        )
    }

    func testQuotaMapsToCNY() async throws {
        let http = MockHTTPClient(statusCode: 200, json: standardJSON)
        let provider = ApinebulaBalanceProvider(http: http)
        let snap = try await provider.fetchBalance(
            account: account(),
            credentials: ProviderCredentials(apiKey: "sys-token", userId: "12210")
        )

        XCTAssertEqual(snap.providerKind, .apinebula)
        XCTAssertEqual(snap.unit, "¥")
        XCTAssertEqual(snap.amount!, 99734740.0 / 500_000.0, accuracy: 0.0001)
        XCTAssertEqual(snap.used!, 20265260.0 / 500_000.0, accuracy: 0.0001)
        XCTAssertEqual(snap.total!, 240.0, accuracy: 0.0001)
        XCTAssertTrue(snap.detail.contains("yancyfeng999"))
        XCTAssertTrue(snap.detail.contains("UID 12210"))
        XCTAssertEqual(http.authorizationHeaders.first, "Bearer sys-token")
        XCTAssertEqual(http.customHeaders["New-API-User"]?.first, "12210")
    }

    func testSessionCookieAuth() async throws {
        let http = MockHTTPClient(statusCode: 200, json: standardJSON)
        let provider = ApinebulaBalanceProvider(http: http)
        let session = "MTc4NjI3Mzg3MHxEWDhFQVFMX2dBQUJFQUVRQUFEX2xfLUFBQVVHYzNSeWFXNW5EQWdBQm5OMFlYUjFjd05wYm5RRUFnQUNCbk4w"
        let snap = try await provider.fetchBalance(
            account: account(),
            credentials: ProviderCredentials(apiKey: session, userId: "12210")
        )
        XCTAssertEqual(snap.amount!, 99734740.0 / 500_000.0, accuracy: 0.0001)
        XCTAssertTrue(http.customHeaders["Cookie"]?.first?.contains("session=") == true)
        XCTAssertTrue(http.authorizationHeaders.isEmpty)
        XCTAssertTrue(snap.detail.contains("session"))
    }

    func testMissingUserId() async {
        let http = MockHTTPClient(statusCode: 200, json: standardJSON)
        let provider = ApinebulaBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: account(userId: nil),
                credentials: ProviderCredentials(apiKey: "tok", userId: nil)
            )
            XCTFail("expected missingUserId")
        } catch BalanceProviderError.missingUserId {
            // ok
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func testDisplayNameAndNotManual() {
        XCTAssertEqual(ProviderKind.apinebula.displayName, "apinebula")
        XCTAssertFalse(ProviderKind.apinebula.isManualEntry)
        XCTAssertTrue(ProviderKind.apinebula.needsUserId)
        XCTAssertEqual(ProviderKind.apinebula.defaultBaseURL, "https://apinebula.ai")
        XCTAssertEqual(ProviderKind.apinebula.defaultConsoleURL, "https://apinebula.ai/zh/console/topup")
        XCTAssertEqual(ProviderRegistry.provider(for: .apinebula).kind, .apinebula)
    }

    func testResolveSessionCookie() {
        XCTAssertNil(ApinebulaBalanceProvider.resolveSessionCookie("sk-abc123"))
        XCTAssertNil(ApinebulaBalanceProvider.resolveSessionCookie("short"))
        let sess = String(repeating: "A", count: 120)
        XCTAssertEqual(ApinebulaBalanceProvider.resolveSessionCookie(sess), sess)
        XCTAssertEqual(
            ApinebulaBalanceProvider.resolveSessionCookie("session=abc; other=1"),
            "abc"
        )
    }
}
