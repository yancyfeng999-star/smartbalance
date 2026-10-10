import SwiftUI
import Domain

struct RestorePreviewView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 10) {
            if let outcome = model.restoreOutcome {
                resultBlock(outcome)
            } else if let preview = model.restorePreview {
                previewBlock(preview)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t("restore.preview.title"))
    }

    private func previewBlock(_ preview: TransferPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.t("restore.preview.title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SBTheme.text)
                .accessibilityAddTraits(.isHeader)

            fact(l10n.t("restore.preview.accounts"), "\(preview.accountCount)")
            fact(
                l10n.t("restore.preview.providers"),
                preview.providers.map(\.displayName).joined(separator: " · ")
            )
            fact(
                l10n.t("restore.preview.reentry"),
                preview.credentialsNeedReentryNames.isEmpty
                    ? l10n.t("restore.preview.reentry_none")
                    : preview.credentialsNeedReentryNames.joined(separator: " · ")
            )
            fact(
                l10n.t("restore.preview.coverage"),
                preview.coverage.map(coverageLabel).joined(separator: " · ")
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(l10n.t("restore.preview.excluded"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SBTheme.text)
                Text(preview.excludedFields.joined(separator: ", "))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(SBTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if preview.includesUsageHistory {
                Toggle(isOn: $model.restoreIncludeUsage) {
                    Text(l10n.t("restore.preview.usage"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SBTheme.text)
                }
                .toggleStyle(.switch)
                .accessibilityLabel(l10n.t("restore.preview.usage"))
            }

            if preview.isLegacySecretBackup {
                Text(l10n.t("restore.legacy.warning"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SBTheme.warn)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle(isOn: $model.restoreLegacyAcknowledged) {
                    Text(l10n.t("restore.legacy.ack"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SBTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.switch)
                .accessibilityLabel(l10n.t("restore.legacy.ack"))
            }

            HStack(spacing: 8) {
                Button(l10n.t("restore.preview.cancel")) {
                    model.cancelPendingRestore()
                }
                .buttonStyle(SBButtonStyle(kind: .normal))
                .disabled(model.restoreBusy)
                .accessibilityLabel(l10n.t("restore.preview.cancel"))

                Button(l10n.t("restore.preview.confirm")) {
                    model.confirmPendingRestore()
                }
                .buttonStyle(SBButtonStyle(kind: .accent))
                .disabled(!canConfirm(preview) || model.restoreBusy)
                .accessibilityLabel(l10n.t("restore.preview.confirm"))
            }
        }
    }

    private func resultBlock(_ outcome: RestoreOutcome) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.t(resultTitleKey(outcome)))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SBTheme.text)

            if outcome.credentialsNeedReentry {
                Text(l10n.t("restore.result.reentry"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button(l10n.t("restore.result.open_backups")) {
                    model.openBackupDirectory()
                }
                .buttonStyle(SBButtonStyle(kind: .normal))
                .accessibilityLabel(l10n.t("restore.result.open_backups"))

                Button(l10n.t("restore.result.open_diagnostics")) {
                    model.openDiagnosticsCenter()
                }
                .buttonStyle(SBButtonStyle(kind: .accent))
                .accessibilityLabel(l10n.t("restore.result.open_diagnostics"))
            }
        }
    }

    private func resultTitleKey(_ outcome: RestoreOutcome) -> String {
        switch outcome.status {
        case .succeeded: return "restore.result.ok"
        case .cancelled: return "restore.result.cancelled"
        case .failed: return "restore.result.failed"
        }
    }

    private func canConfirm(_ preview: TransferPreview) -> Bool {
        if preview.isLegacySecretBackup {
            return model.restoreLegacyAcknowledged
        }
        return true
    }

    private func coverageLabel(_ item: TransferCoverageItem) -> String {
        switch item {
        case .accounts: return l10n.t("restore.coverage.accounts")
        case .alertsAndMail: return l10n.t("restore.coverage.alerts")
        case .refreshThemeLanguage: return l10n.t("restore.coverage.theme")
        case .usageHistory: return l10n.t("restore.coverage.usage")
        }
    }

    private func fact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SBTheme.text)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
