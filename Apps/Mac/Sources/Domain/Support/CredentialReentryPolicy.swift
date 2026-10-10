import Foundation

/// Non-sensitive account credential status used to guide the user after an
/// import or an upgrade. It never carries a credential value.
public enum CredentialReentryPolicy {
    public static func missingAccountCredentialCount(
        settings: AppSettings,
        presence: (String) -> CredentialPresence
    ) -> Int {
        settings.accounts.reduce(into: 0) { count, account in
            guard account.kind.needsSecret else { return }
            if presence(account.secretRef) == .missing {
                count += 1
            }
        }
    }
}
