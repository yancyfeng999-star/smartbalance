import LocalAuthentication
import XCTest
@testable import Infrastructure

final class LocalSecretStoreTests: XCTestCase {
    func testBiometricsAreAttemptedBeforeDevicePasswordFallback() {
        XCTAssertEqual(
            LocalSecretStore.authenticationPolicies(biometricsAvailable: true).map(\.rawValue),
            [LAPolicy.deviceOwnerAuthenticationWithBiometrics.rawValue, LAPolicy.deviceOwnerAuthentication.rawValue]
        )
    }

    func testUnavailableBiometricsUsesDevicePasswordOnly() {
        XCTAssertEqual(
            LocalSecretStore.authenticationPolicies(biometricsAvailable: false).map(\.rawValue),
            [LAPolicy.deviceOwnerAuthentication.rawValue]
        )
    }
}
