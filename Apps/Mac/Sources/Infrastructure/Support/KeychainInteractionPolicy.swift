import Foundation
import Security

/// All Keychain I/O must fail closed instead of showing a password / Allow sheet.
public enum KeychainInteractionPolicy {
    public static func disableSystemPrompts() {
        _ = SecKeychainSetUserInteractionAllowed(false)
    }

    static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func applyNoPrompt(_ query: inout [String: Any]) {
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
    }

    static func shouldTreatAsInaccessible(_ status: OSStatus) -> Bool {
        status == errSecUserCanceled
            || status == errSecAuthFailed
            || status == errSecInteractionNotAllowed
    }
}
