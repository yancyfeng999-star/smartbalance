import Foundation

/// Destinations views and AppModel must use. Tests cover this instead of constructing AppModel.
public enum SupportErrorDestination: String, Sendable, Equatable {
    case refresh
    case settings
    case settingsAPIAccounts
    case logs
    case diagnostics
    case backupRestore
    case help
    case retryExportDiagnostics
    case retryExportTransfer
    case retryExportBackup
    case retryUpdateCheck
    case retryUpdateInstall
}

public enum SupportViewMapping: Sendable {
    public static func cardKind(status: BalanceStatus, errorMessage: String?) -> ActionableErrorKind? {
        ActionableErrorPolicy.kind(snapshotStatus: status, errorMessage: errorMessage)
    }

    public static func homeBannerKind(
        noticeKey: String?,
        bannerKey: String?,
        usageHealth: UsageStorageHealth?,
        usageDataError: String?
    ) -> ActionableErrorKind? {
        ActionableErrorPolicy.kind(
            noticeKey: noticeKey,
            bannerKey: bannerKey,
            usageHealth: usageHealth,
            usageDataError: usageDataError
        )
    }

    public static func destination(
        for action: ErrorNextAction,
        kind: ActionableErrorKind,
        bannerKey: String? = nil
    ) -> SupportErrorDestination {
        switch action {
        case .openSettings:
            return .settings
        case .reenterCredentials:
            return .settingsAPIAccounts
        case .openLogs:
            return .logs
        case .exportDiagnostics:
            return .diagnostics
        case .restoreBackup:
            return .backupRestore
        case .viewHelp:
            return .help
        case .retry:
            return retryDestination(kind: kind, bannerKey: bannerKey)
        }
    }

    private static func retryDestination(
        kind: ActionableErrorKind,
        bannerKey: String?
    ) -> SupportErrorDestination {
        switch kind {
        case .refreshFailed, .refreshPartialFailed, .networkFailed, .credentialsMissing, .usageSaveFailed:
            return .refresh
        case .usageLoadFailed, .usageNeedsRestore, .restoreFailed:
            return .backupRestore
        case .diagnosticsExportFailed:
            return .retryExportDiagnostics
        case .exportFailed:
            switch bannerKey {
            case "settings.transfer.export_failed", "recovery.result.export_failed":
                return .retryExportTransfer
            case "settings.backup.export_failed":
                return .retryExportBackup
            default:
                return .retryExportDiagnostics
            }
        case .updateCheckFailed:
            return .retryUpdateCheck
        case .updateInstallFailed:
            return .retryUpdateInstall
        case .settingsCorrupt, .compatibilityBlocked:
            return .settings
        }
    }
}
