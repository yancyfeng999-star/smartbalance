import XCTest
import Security
@testable import Infrastructure

final class KeychainInteractionPolicyTests: XCTestCase {
    func testQueriesNeverRequestAuthenticationUI() {
        var query = KeychainInteractionPolicy.baseQuery(
            service: "com.smartbalance.zhiyu.plain",
            account: "test.account"
        )
        KeychainInteractionPolicy.applyNoPrompt(&query)

        XCTAssertEqual(
            query[kSecUseAuthenticationUI as String] as? String,
            kSecUseAuthenticationUIFail as String
        )
        XCTAssertEqual(query[kSecAttrService as String] as? String, "com.smartbalance.zhiyu.plain")
        XCTAssertEqual(query[kSecClass as String] as! CFString, kSecClassGenericPassword)
    }

    func testInteractionRequiredStatusesAreTreatedAsMissingAndNotRetried() {
        XCTAssertTrue(KeychainInteractionPolicy.shouldTreatAsInaccessible(errSecUserCanceled))
        XCTAssertTrue(KeychainInteractionPolicy.shouldTreatAsInaccessible(errSecAuthFailed))
        XCTAssertTrue(KeychainInteractionPolicy.shouldTreatAsInaccessible(errSecInteractionNotAllowed))
        XCTAssertFalse(KeychainInteractionPolicy.shouldTreatAsInaccessible(errSecItemNotFound))
        XCTAssertFalse(KeychainInteractionPolicy.shouldTreatAsInaccessible(errSecSuccess))
    }

    func testDeniedAccountIsNotLookedUpAgain() {
        let account = "test.denied-cache.\(UUID().uuidString)"
        let store = LocalSecretStore()
        store.recordNonInteractiveDenialForTesting(account: account)

        XCTAssertNil(store.get(account: account))
        XCTAssertEqual(store.credentialPresence(for: account), .missing)
        XCTAssertEqual(store.keychainLookupCountForTesting(account: account), 0)
    }
}
