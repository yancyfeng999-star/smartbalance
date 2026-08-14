import Foundation

public struct FirstLaunchState: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var completedAt: Date?
    public var acknowledgedPrivacy: Bool
    public var lastCompatibilityReport: CompatibilityReport?

    public init(
        schemaVersion: Int = FirstLaunchState.currentSchemaVersion,
        completedAt: Date? = nil,
        acknowledgedPrivacy: Bool = false,
        lastCompatibilityReport: CompatibilityReport? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.completedAt = completedAt
        self.acknowledgedPrivacy = acknowledgedPrivacy
        self.lastCompatibilityReport = lastCompatibilityReport
    }

    public var isCompleted: Bool { completedAt != nil }
}

public enum FirstLaunchLoadResult: Sendable, Equatable {
    case missing
    case loaded(FirstLaunchState)
    case corrupt
}

public enum SessionRoute: String, Sendable, Equatable {
    case onboarding
    case compatibility
    case home
}

public enum OnboardingStep: String, Codable, Sendable, Equatable, CaseIterable {
    case privacy
    case compatibility
    case addProvider
    case notifications
}

public enum FirstLaunchRouter: Sendable {
    public static func route(
        loadResult: FirstLaunchLoadResult,
        hasExistingAccounts: Bool = false,
        completedThisSession: Bool = false
    ) -> SessionRoute {
        if completedThisSession {
            return .home
        }
        switch loadResult {
        case .corrupt:
            return .compatibility
        case .missing:
            return hasExistingAccounts ? .home : .onboarding
        case .loaded(let state):
            return state.isCompleted ? .home : .onboarding
        }
    }

    public static func shouldSeedCompletedState(
        loadResult: FirstLaunchLoadResult,
        hasExistingAccounts: Bool
    ) -> Bool {
        loadResult == .missing && hasExistingAccounts
    }

    public static func initialStep(for loadResult: FirstLaunchLoadResult) -> OnboardingStep {
        switch loadResult {
        case .loaded(let state) where state.acknowledgedPrivacy && !state.isCompleted:
            return .compatibility
        default:
            return .privacy
        }
    }

    public static func nextStep(after step: OnboardingStep) -> OnboardingStep? {
        switch step {
        case .privacy: return .compatibility
        case .compatibility: return .addProvider
        case .addProvider: return .notifications
        case .notifications: return nil
        }
    }
}
