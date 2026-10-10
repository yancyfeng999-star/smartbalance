import Foundation

public enum ActionableErrorKind: String, CaseIterable, Sendable, Equatable {
    case refreshFailed
    case refreshPartialFailed
    case networkFailed
    case usageSaveFailed
    case usageLoadFailed
    case usageNeedsRestore
    case credentialsMissing
    case diagnosticsExportFailed
    case exportFailed
    case restoreFailed
    case updateCheckFailed
    case updateInstallFailed
    case settingsCorrupt
    case compatibilityBlocked
}

public enum ErrorNextAction: String, CaseIterable, Sendable, Equatable {
    case retry
    case openSettings
    case reenterCredentials
    case openLogs
    case exportDiagnostics
    case restoreBackup
    case viewHelp
}

public struct ActionableErrorPresentation: Equatable, Sendable {
    public var kind: ActionableErrorKind
    public var titleKey: String
    public var messageKey: String
    public var actions: [ErrorNextAction]
    public var helpTopic: HelpTopicID

    public init(
        kind: ActionableErrorKind,
        titleKey: String,
        messageKey: String,
        actions: [ErrorNextAction],
        helpTopic: HelpTopicID
    ) {
        self.kind = kind
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.actions = actions
        self.helpTopic = helpTopic
    }
}

public enum ActionableErrorPolicy: Sendable {
    public static func presentation(for kind: ActionableErrorKind) -> ActionableErrorPresentation {
        switch kind {
        case .refreshFailed:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.refresh.failed.title",
                messageKey: "error.refresh.failed.message",
                actions: [.retry, .openSettings, .viewHelp],
                helpTopic: .refreshFailed
            )
        case .refreshPartialFailed:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.refresh.partial.title",
                messageKey: "error.refresh.partial.message",
                actions: [.retry, .viewHelp],
                helpTopic: .refreshFailed
            )
        case .networkFailed:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.network.title",
                messageKey: "error.network.message",
                actions: [.retry, .viewHelp],
                helpTopic: .refreshFailed
            )
        case .usageSaveFailed:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.usage.save.title",
                messageKey: "error.usage.save.message",
                actions: [.retry, .exportDiagnostics, .viewHelp],
                helpTopic: .usageHistory
            )
        case .usageLoadFailed:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.usage.load.title",
                messageKey: "error.usage.load.message",
                actions: [.restoreBackup, .viewHelp],
                helpTopic: .usageHistory
            )
        case .usageNeedsRestore:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.usage.restore.title",
                messageKey: "error.usage.restore.message",
                actions: [.restoreBackup, .viewHelp],
                helpTopic: .usageHistory
            )
        case .credentialsMissing:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.credentials.title",
                messageKey: "error.credentials.message",
                actions: [.reenterCredentials, .openSettings, .viewHelp],
                helpTopic: .credentials
            )
        case .diagnosticsExportFailed:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.diagnostics.export.title",
                messageKey: "error.diagnostics.export.message",
                actions: [.retry, .openLogs, .viewHelp],
                helpTopic: .diagnostics
            )
        case .exportFailed:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.export.failed.title",
                messageKey: "error.export.failed.message",
                actions: [.retry, .openSettings, .viewHelp],
                helpTopic: .backupRestore
            )
        case .restoreFailed:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.restore.failed.title",
                messageKey: "error.restore.failed.message",
                actions: [.retry, .openLogs, .viewHelp],
                helpTopic: .backupRestore
            )
        case .updateCheckFailed:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.update.check.title",
                messageKey: "error.update.check.message",
                actions: [.retry, .viewHelp],
                helpTopic: .updates
            )
        case .updateInstallFailed:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.update.install.title",
                messageKey: "error.update.install.message",
                actions: [.retry, .openLogs, .viewHelp],
                helpTopic: .updates
            )
        case .settingsCorrupt:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.settings.corrupt.title",
                messageKey: "error.settings.corrupt.message",
                actions: [.openSettings, .restoreBackup, .viewHelp],
                helpTopic: .backupRestore
            )
        case .compatibilityBlocked:
            return ActionableErrorPresentation(
                kind: kind,
                titleKey: "error.compat.blocked.title",
                messageKey: "error.compat.blocked.message",
                actions: [.openSettings, .viewHelp],
                helpTopic: .gettingStarted
            )
        }
    }

    public static func kind(
        noticeKey: String?,
        bannerKey: String? = nil,
        usageHealth: UsageStorageHealth? = nil,
        usageDataError: String? = nil,
        snapshotStatus: BalanceStatus? = nil,
        errorMessage: String? = nil
    ) -> ActionableErrorKind? {
        if let snapshotStatus {
            return kind(snapshotStatus: snapshotStatus, errorMessage: errorMessage)
        }
        if usageHealth == .needsRestore {
            return .usageNeedsRestore
        }
        if usageHealth == .loadFailed || usageDataError == "load" {
            return .usageLoadFailed
        }
        if usageHealth == .lastSaveFailed || usageDataError == "save" {
            return .usageSaveFailed
        }
        if let mapped = kind(messageKey: noticeKey) {
            return mapped
        }
        return kind(messageKey: bannerKey)
    }

    public static func kind(snapshotStatus: BalanceStatus, errorMessage: String?) -> ActionableErrorKind? {
        switch snapshotStatus {
        case .setup:
            return .credentialsMissing
        case .error:
            return classifyCardFailure(errorMessage)
        case .healthy, .warning, .caution, .critical, .depleted, .unknown:
            return nil
        }
    }

    public static func kind(messageKey: String?) -> ActionableErrorKind? {
        guard let messageKey, !messageKey.isEmpty else { return nil }
        switch messageKey {
        case RefreshMessageKey.failed:
            return .refreshFailed
        case RefreshMessageKey.partialFailed:
            return .refreshPartialFailed
        case RefreshMessageKey.usageSaveFailed, "usage.save_failed":
            return .usageSaveFailed
        case "usage.load_failed":
            return .usageLoadFailed
        case "diagnostics.export.failed":
            return .diagnosticsExportFailed
        case "settings.transfer.export_failed",
             "settings.backup.export_failed",
             "recovery.result.export_failed":
            return .exportFailed
        case "restore.result.failed",
             "recovery.result.restore_failed":
            return .restoreFailed
        case "recovery.result.reset_failed":
            return .settingsCorrupt
        case "update.check.failed", "update.check.http_failed", "update.check.parse_failed":
            return .updateCheckFailed
        default:
            if messageKey.hasPrefix("restore.error.") {
                return .restoreFailed
            }
            if messageKey.hasPrefix("update.error."), messageKey != "update.error.copied" {
                return .updateInstallFailed
            }
            return nil
        }
    }

    public static func classifyCardFailure(_ message: String?) -> ActionableErrorKind {
        let text = (message ?? "").lowercased()
        if looksLikeCredentialFailure(text) {
            return .credentialsMissing
        }
        if looksLikeNetworkFailure(text) {
            return .networkFailed
        }
        return .refreshFailed
    }

    private static func looksLikeCredentialFailure(_ text: String) -> Bool {
        let tokens = [
            "未配置密钥", "未配置", "尚未录入", "密钥", "凭据",
            "unrecognized provider", "unauthorized", "401",
            "cookie", "credential", "password", "api key", "apikey",
            "access token", "未授权", "登录过期",
        ]
        return tokens.contains { text.contains($0) }
    }

    private static func looksLikeNetworkFailure(_ text: String) -> Bool {
        let tokens = [
            "超时", "timeout", "timed out", "网络", "network",
            "连接", "connection", "offline", "无法连接", "dns",
            "not connected", "nsurlerror",
        ]
        return tokens.contains { text.contains($0) }
    }
}
