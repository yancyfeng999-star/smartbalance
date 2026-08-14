import Foundation

public enum RecoveryReason: String, Codable, Sendable, Equatable, CaseIterable {
    case consecutiveUncleanExits
    case settingsCorrupt
    case interruptedUpdate
    case usageCorrupt

    public var localizationKey: String {
        "recovery.reason.\(rawValue)"
    }

    public var entersSafeModeImmediately: Bool {
        switch self {
        case .consecutiveUncleanExits, .settingsCorrupt, .interruptedUpdate:
            return true
        case .usageCorrupt:
            return false
        }
    }
}
