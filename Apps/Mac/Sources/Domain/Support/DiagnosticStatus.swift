import Foundation

public enum DiagnosticStatus: String, Codable, Sendable, Equatable {
    case ok
    case warning
    case failed
    case unknown
}

public enum DiagnosticKeychainStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case available
    case unavailable
    case unknown
}

public enum DiagnosticLaunchMode: String, Codable, Sendable, Equatable {
    case menuBar
    case unknown
}

public enum DiagnosticCheckID: String, Codable, Sendable, Equatable, CaseIterable {
    case appVersion
    case macos
    case architecture
    case launchMode
    case schema
    case applicationSupport
    case logs
    case temporary
    case settings
    case usageHistory
    case migration
    case backup
    case restore
    case keychain
    case notifications
    case refresh
    case providers
    case usage
}
