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

    func testMissingSessionFailsClearly() async {
        let http = MockHTTPClient(statusCode: 200, json: standardJSON)
        let provider = ApinebulaBalanceProvider(http: http)
        do {
            _ = try await provider.fetchBalance(
                account: account(userId: nil),
                credentials: ProviderCredentials(apiKey: "", userId: nil)
            )
            XCTFail("expected error")
        } catch let BalanceProviderError.providerMessage(msg) {
            XCTAssertTrue(msg.contains("Chrome") || msg.contains("导入"), msg)
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func testDisplayNameAndNotManual() {
        XCTAssertEqual(ProviderKind.apinebula.displayName, "apinebula")
        XCTAssertFalse(ProviderKind.apinebula.isManualEntry)
        XCTAssertFalse(ProviderKind.apinebula.needsUserId)
        XCTAssertTrue(ProviderKind.apinebula.supportsBrowserSessionImport)
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

    func testExtractUserIdFromNestedSession() {
        // 构造：outer = b64( "1|" + b64url(gob) + "|mac" )
        // gob 含 "id" + int 12210 → 编码 uint 24420 = 0x5F64 → FE 5F 64
        var gob = Data()
        gob.append(contentsOf: [0x00])
        gob.append(contentsOf: Array("id".utf8))
        gob.append(contentsOf: [0x03])
        gob.append(contentsOf: Array("int".utf8))
        gob.append(contentsOf: [0x04, 0x04, 0x00, 0xFE, 0x5F, 0x64])
        gob.append(contentsOf: Array("username".utf8))

        let innerB64 = gob.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        let outerPlain = "1786273870|\(innerB64)|fakesig"
        let outerB64 = Data(outerPlain.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))

        XCTAssertEqual(SessionCookieParser.extractNewAPIUserId(fromSession: outerB64), "12210")
    }

    func testSupportsBrowserImport() {
        XCTAssertTrue(ProviderKind.apinebula.supportsBrowserSessionImport)
        XCTAssertFalse(ProviderKind.apinebula.needsUserId)
    }
}
