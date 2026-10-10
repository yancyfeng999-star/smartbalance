import XCTest
@testable import Domain
@testable import Infrastructure

final class LocalSecretStoreTests: XCTestCase {
    func testUnreadableWriteIsNotReportedAsSaved() {
        XCTAssertThrowsError(try LocalSecretStore.verifyReadBack(nil, matches: "private-value")) { error in
            XCTAssertFalse(error.localizedDescription.contains("private-value"))
        }
    }

    func testMismatchedWriteIsNotReportedAsSaved() {
        XCTAssertThrowsError(try LocalSecretStore.verifyReadBack("old", matches: "new"))
    }

    func testMatchingReadBackIsAccepted() {
        XCTAssertNoThrow(try LocalSecretStore.verifyReadBack("new", matches: "new"))
    }

    func testOrdinaryKeychainSecretCanBeReadByANewStoreInstance() throws {
        let account = "test.ordinary-keychain.\(UUID().uuidString)"
        let writer = LocalSecretStore()
        defer { writer.delete(account: account) }

        try writer.set("test-secret", account: account)

        let reader = LocalSecretStore()
        XCTAssertEqual(reader.get(account: account), "test-secret")
    }

    func testCredentialPresenceIsMissingOrPresentWithoutValues() throws {
        let account = "test.presence.\(UUID().uuidString)"
        let store = LocalSecretStore()
        defer { store.delete(account: account) }

        XCTAssertEqual(store.credentialPresence(for: account), .missing)
        try store.set("super-secret-value-xyz", account: account)
        XCTAssertEqual(store.credentialPresence(for: account), .present)
        XCTAssertFalse(String(describing: store.credentialPresence(for: account)).contains("super-secret"))
        XCTAssertEqual(store.credentialPresence(for: "missing-\(UUID().uuidString)"), .missing)
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
