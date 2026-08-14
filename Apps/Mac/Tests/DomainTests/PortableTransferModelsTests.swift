import XCTest
@testable import Domain

final class PortableTransferModelsTests: XCTestCase {
    func testPortableEncodingOmitsSecretsAndCredentialRefs() throws {
        var account = BalanceAccount(
            id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            kind: .deepseek,
            displayName: "Export Probe",
            secretRef: "sk-test-secret-ref-must-not-export",
            enabled: true
        )
        account.userId = "fixture-user-7"
        var email = EmailAlertSettings()
        email.enabled = true
        email.smtpHost = "smtp.example.test"
        email.username = "alerts@example.test"
        email.passwordRef = "smtp-secret-ref-must-not-export"
        email.fromAddress = "alerts@example.test"
        email.toAddresses = ["owner@example.test"]
        let settings = AppSettings(
            accounts: [account],
            email: email,
            themeMode: ThemeMode.light.rawValue,
            appLanguage: AppLanguage.en.rawValue
        )

        let portable = PortableSettings.make(from: settings, appVersion: "0.3.1", now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(portable.format, PortableSettings.formatID)
        XCTAssertEqual(portable.format, "smartbalance.portable-settings")
        XCTAssertEqual(portable.formatVersion, PortableSettings.currentFormatVersion)
        XCTAssertEqual(portable.formatVersion, 2)
        XCTAssertEqual(portable.appVersion, "0.3.1")
        XCTAssertEqual(portable.accounts.count, 1)
        XCTAssertEqual(portable.accounts[0].userId, "fixture-user-7")
        XCTAssertEqual(portable.email.smtpHost, "smtp.example.test")

        let data = try PortableSettings.encode(portable)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertFalse(json.contains("secretRef"), json)
        XCTAssertFalse(json.contains("passwordRef"), json)
        XCTAssertFalse(json.contains("\"secrets\""), json)
        XCTAssertFalse(json.contains("sk-test-secret-ref-must-not-export"), json)
        XCTAssertFalse(json.contains("smtp-secret-ref-must-not-export"), json)
        XCTAssertFalse(json.contains("Bearer "), json)
        XCTAssertFalse(json.contains("Cookie"), json)
        XCTAssertFalse(json.contains("api_key"), json)
        XCTAssertTrue(json.contains("smartbalance.portable-settings"))
        XCTAssertTrue(json.contains("fixture-user-7"))
    }

    func testImportGeneratesNewCredentialRefsAndRequiresReentry() throws {
        let originalRef = "11111111-1111-4111-8111-111111111111"
        let account = BalanceAccount(
            id: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
            kind: .openrouter,
            displayName: "Import Probe",
            secretRef: originalRef,
            enabled: true
        )
        var email = EmailAlertSettings()
        email.passwordRef = "smtp-password"
        email.smtpHost = "smtp.example.test"
        let settings = AppSettings(accounts: [account], email: email)

        let portable = PortableSettings.make(from: settings, appVersion: "0.3.1")
        let result = portable.importAsSettings()

        XCTAssertTrue(result.credentialsNeedReentry)
        XCTAssertEqual(result.settings.accounts.count, 1)
        XCTAssertEqual(result.settings.accounts[0].id, account.id)
        XCTAssertEqual(result.settings.accounts[0].displayName, "Import Probe")
        XCTAssertNotEqual(result.settings.accounts[0].secretRef, originalRef)
        XCTAssertFalse(result.settings.accounts[0].secretRef.isEmpty)
        XCTAssertNotEqual(result.settings.email.passwordRef, "smtp-password")
        XCTAssertFalse(result.settings.email.passwordRef.isEmpty)
        XCTAssertEqual(result.settings.email.smtpHost, "smtp.example.test")
    }

    func testPortableAccountDoesNotCarrySecretRefProperty() throws {
        let settings = AppSettings(accounts: [
            BalanceAccount(kind: .kimi, secretRef: "must-not-round-trip"),
        ])
        let portable = PortableSettings.make(from: settings, appVersion: "0.3.1")
        let encoded = try PortableSettings.encode(portable)
        let decoded = try PortableSettings.decode(encoded)
        XCTAssertEqual(decoded.accounts.count, 1)
        XCTAssertEqual(decoded.accounts[0].kind, .kimi)
        let mirror = Mirror(reflecting: decoded.accounts[0])
        let labels = Set(mirror.children.compactMap(\.label))
        XCTAssertFalse(labels.contains("secretRef"))
        XCTAssertFalse(labels.contains("passwordRef"))
    }
}
