import XCTest
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
}
