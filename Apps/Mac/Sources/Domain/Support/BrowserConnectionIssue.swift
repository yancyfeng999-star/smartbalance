import Foundation

/// Structured status; never infer a login failure from an arbitrary network error.
public enum BrowserConnectionIssue: String, Codable, Sendable {
    case loginRequired
}

/// Remind once until a successful refresh, without persisting account identifiers.
public struct BrowserLoginReminderPolicy: Sendable {
    private var reminded: Set<UUID> = []

    public init() {}

    public mutating func shouldRemind(for snapshot: BalanceSnapshot) -> Bool {
        guard snapshot.providerKind?.supportsBrowserSessionImport == true else { return false }
        if snapshot.connectionIssue == .loginRequired {
            return reminded.insert(snapshot.accountId).inserted
        }
        if snapshot.errorMessage == nil, ![BalanceStatus.error, .setup, .unknown].contains(snapshot.status) {
            reminded.remove(snapshot.accountId)
        }
        return false
    }
}
