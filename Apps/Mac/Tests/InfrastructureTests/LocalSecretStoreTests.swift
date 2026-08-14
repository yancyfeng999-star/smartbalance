import XCTest
@testable import Domain
@testable import Infrastructure

final class LocalSecretStoreTests: XCTestCase {
    func testOrdinaryKeychainSecretCanBeReadByANewStoreInstance() throws {
        let account = "test.ordinary-keychain.\(UUID().uuidString)"
        let writer = LocalSecretStore()
        defer { writer.delete(account: account) }

        try writer.set("test-secret", account: account)

        let reader = LocalSecretStore()
        XCTAssertEqual(reader.get(account: account), "test-secret")
    }

    func testAvailabilityStatusIsNonSensitiveEnumOnly() {
        let status = LocalSecretStore().availabilityStatus()
        XCTAssertTrue(
            [DiagnosticKeychainStatus.available, .unavailable, .unknown].contains(status)
        )
        XCTAssertFalse(String(describing: status).contains("com.smartbalance"))
        XCTAssertFalse(String(describing: status).contains("plain"))
    }
}
