import Foundation

public enum RecoveryLimits {
    /// Two leftover unclean session markers cause this launch to enter safe mode.
    public static let uncleanMarkerThreshold = 2
}

public enum RecoverySessionPhase: String, Codable, Sendable, Equatable {
    case launching
    case healthy
    case quitting
}

public struct RecoverySessionStart: Equatable, Sendable {
    public var decision: RecoveryDecision

    public init(decision: RecoveryDecision) {
        self.decision = decision
    }

    public func route(firstLaunch: SessionRoute) -> SessionRoute {
        RecoveryRouter.route(decision: decision, firstLaunchRoute: firstLaunch)
    }
}

public struct RecoveryDecision: Equatable, Sendable {
    public var enterSafeMode: Bool
    public var reasons: [RecoveryReason]
    public var consecutiveUncleanExits: Int
    public var continuedThisSession: Bool

    public init(
        enterSafeMode: Bool,
        reasons: [RecoveryReason] = [],
        consecutiveUncleanExits: Int = 0,
        continuedThisSession: Bool = false
    ) {
        self.enterSafeMode = enterSafeMode
        self.reasons = reasons
        self.consecutiveUncleanExits = consecutiveUncleanExits
        self.continuedThisSession = continuedThisSession
    }

    public static let normal = RecoveryDecision(enterSafeMode: false)

    public var primaryReason: RecoveryReason? { reasons.first }
}

public enum RecoveryAction: String, Codable, Sendable, Equatable, CaseIterable, Hashable {
    case openDiagnostics
    case openLogs
    case restoreLatestSnapshot
    case exportSettings
    case resetSettings
    case continueNormalStart

    public var titleKey: String { "recovery.action.\(rawValue)" }
    public var detailKey: String { "recovery.action.\(rawValue).detail" }
}

public enum RecoveryActionKind: String, Sendable, Equatable {
    case informational
    case destructive
    case proceed
}

public enum RecoveryActionStatus: String, Sendable, Equatable {
    case idle
    case confirming
    case running
    case succeeded
    case failed
}

public struct RecoveryActionOutcome: Equatable, Sendable {
    public var action: RecoveryAction
    public var status: RecoveryActionStatus
    public var messageKey: String

    public init(action: RecoveryAction, status: RecoveryActionStatus, messageKey: String) {
        self.action = action
        self.status = status
        self.messageKey = messageKey
    }
}

public enum RecoverySideEffect: String, Sendable, Equatable, CaseIterable {
    case backgroundRefresh
    case providerCredentialRead
    case notificationDelivery
    case notificationAuthorization
    case smtpSend
    case updateInstall
}

public enum RecoveryLifecycleEvent: String, Sendable, Equatable {
    case windowHidden
    case explicitQuit
    case forceKill
}

public enum RecoveryRouter: Sendable {
    public static func route(
        decision: RecoveryDecision,
        firstLaunchRoute: SessionRoute
    ) -> SessionRoute {
        if decision.enterSafeMode && !decision.continuedThisSession {
            return .safeMode
        }
        return firstLaunchRoute
    }

    public static func routeAfterContinue(firstLaunchRoute: SessionRoute) -> SessionRoute {
        firstLaunchRoute == .safeMode ? .home : firstLaunchRoute
    }
}

public enum RecoveryLaunchPolicy: Sendable {
    public static func allows(_ effect: RecoverySideEffect, route: SessionRoute) -> Bool {
        route != .safeMode
    }

    public static func allowsBackgroundRefresh(route: SessionRoute) -> Bool {
        allows(.backgroundRefresh, route: route)
    }

    public static func allowsProviderCredentialRead(route: SessionRoute) -> Bool {
        allows(.providerCredentialRead, route: route)
    }

    public static func allowsNotificationDelivery(route: SessionRoute) -> Bool {
        allows(.notificationDelivery, route: route)
    }

    public static func allowsNotificationAuthorization(route: SessionRoute) -> Bool {
        allows(.notificationAuthorization, route: route)
    }

    public static func allowsSMTP(route: SessionRoute) -> Bool {
        allows(.smtpSend, route: route)
    }

    public static func allowsUpdateInstall(route: SessionRoute) -> Bool {
        allows(.updateInstall, route: route)
    }
}

public enum RecoveryMarkerLifecyclePolicy: Sendable {
    public static func shouldClearMarker(for event: RecoveryLifecycleEvent) -> Bool {
        event == .explicitQuit
    }

    public static func countsAsUncleanExit(_ event: RecoveryLifecycleEvent) -> Bool {
        event == .forceKill
    }

    public static func leftoverPhaseIsUnclean(_ phase: RecoverySessionPhase) -> Bool {
        phase != .quitting
    }
}

public enum RecoveryResetPolicy: Sendable {
    public static let mustCreateSnapshotFirst = true
    public static let deletesKeychainEntries = false
    public static let leftoverCredentialsNoticeKey = "recovery.action.resetSettings.keychain_notice"
    public static let snapshotReason = "recovery-reset"

    public static func allowedResetTargets(includeUsageHistory: Bool) -> Set<String> {
        includeUsageHistory ? ["settings", "usageHistory"] : ["settings"]
    }
}

public enum RecoveryActionPolicy: Sendable {
    public static func kind(of action: RecoveryAction) -> RecoveryActionKind {
        switch action {
        case .openDiagnostics, .openLogs, .exportSettings:
            return .informational
        case .restoreLatestSnapshot, .resetSettings:
            return .destructive
        case .continueNormalStart:
            return .proceed
        }
    }

    public static func isDangerous(_ action: RecoveryAction) -> Bool {
        kind(of: action) == .destructive
    }

    public static func requiresConfirmation(_ action: RecoveryAction) -> Bool {
        switch action {
        case .restoreLatestSnapshot, .resetSettings, .continueNormalStart:
            return true
        case .openDiagnostics, .openLogs, .exportSettings:
            return false
        }
    }

    public static func confirmActionKey(for action: RecoveryAction) -> String {
        switch action {
        case .restoreLatestSnapshot:
            return "recovery.action.restoreLatestSnapshot.confirm"
        case .resetSettings:
            return "recovery.action.resetSettings.confirm"
        case .continueNormalStart:
            return "recovery.action.continueNormalStart.confirm"
        case .openDiagnostics, .openLogs, .exportSettings:
            return action.titleKey
        }
    }

    public static func confirmMessageKey(for action: RecoveryAction) -> String {
        "\(confirmActionKey(for: action))_message"
    }

    public static func cancelActionKey() -> String {
        "recovery.action.cancel"
    }

    /// Dangerous actions must not share the vague onboarding/home "continue" copy.
    public static func usesVagueContinueLabel(_ action: RecoveryAction) -> Bool {
        let key = confirmActionKey(for: action)
        return key == "recovery.action.continue"
            || key.hasSuffix(".continue")
            || key == "onboarding.privacy.continue"
            || key == "onboarding.compat.continue"
            || key == "onboarding.provider.continue"
    }
}

public enum RecoveryContinuePolicy: Sendable {
    public static func clearsDiagnosticLedger() -> Bool { false }
    public static func resetsUncleanCount() -> Bool { false }
    public static func clearsCurrentSessionMarker() -> Bool { true }
}

public struct RecoveryResetOutcome: Equatable, Sendable {
    public var succeeded: Bool
    public var settingsSnapshotURL: URL?
    public var usageSnapshotURL: URL?
    public var keychainEntriesDeleted: Int
    public var resetUsageHistory: Bool
    public var failureReason: RestoreFailureReason?

    public init(
        succeeded: Bool,
        settingsSnapshotURL: URL? = nil,
        usageSnapshotURL: URL? = nil,
        keychainEntriesDeleted: Int = 0,
        resetUsageHistory: Bool = false,
        failureReason: RestoreFailureReason? = nil
    ) {
        self.succeeded = succeeded
        self.settingsSnapshotURL = settingsSnapshotURL
        self.usageSnapshotURL = usageSnapshotURL
        self.keychainEntriesDeleted = keychainEntriesDeleted
        self.resetUsageHistory = resetUsageHistory
        self.failureReason = failureReason
    }
}
