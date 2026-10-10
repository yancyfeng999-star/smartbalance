import SwiftUI
import Domain

/// Manual update details. Release notes are plain text only — never a WebView.
struct UpdateDetailsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 10) {
            if isBusy {
                UpdateProgressView(model: model)
            }
            facts
            notes
            validationBlock
            if model.updateAwaitingInstallConfirm {
                confirmBlock
            }
            if model.updatePhase == .failed {
                ActionableErrorView(presentation: ActionableErrorPolicy.presentation(for: .updateInstallFailed)) { action in
                    model.performErrorAction(action, kind: .updateInstallFailed)
                }
            }
            actions
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t("update.details.title"))
    }

    private var isBusy: Bool {
        switch model.updatePhase {
        case .downloading, .validating, .installing: return true
        default: return false
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 6) {
            fact(l10n.t("update.details.current"), details?.currentVersion ?? model.appVersion)
            fact(l10n.t("update.details.target"), details?.targetVersion ?? l10n.t("update.unknown_value"))
            fact(l10n.t("update.details.published"), publishedText)
            fact(l10n.t("update.details.filename"), details?.asset?.fileName ?? l10n.t("update.unknown_value"))
            fact(l10n.t("update.details.size"), sizeText)
            fact(l10n.t("update.details.min_os"), details?.minimumMacOS ?? UpdateSafetyLimits.defaultMinimumMacOS)
            fact(l10n.t("update.details.checksum"), l10n.t(checksumKey))
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l10n.t("update.details.notes"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SBTheme.text)
            Text(details?.releaseNotesPlainText.isEmpty == false ? (details?.releaseNotesPlainText ?? "") : l10n.t("update.unknown_value"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var validationBlock: some View {
        Group {
            if let issues = model.updateValidation?.issues, !issues.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(issues, id: \.rawValue) { issue in
                        Text(l10n.t(issue.localizationKey))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(issue.blocksInstall ? SBTheme.danger : SBTheme.warn)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var confirmBlock: some View {
        Text(l10n.t(UpdateInstallConfirmCopy.messageKey(for: assetKind)))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(SBTheme.warn)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(l10n.t("update.action.open_release")) {
                    model.openUpdateURL()
                }
                .buttonStyle(SBButtonStyle(kind: .normal))
                .accessibilityLabel(l10n.t("update.action.open_release"))

                if model.updateValidation?.canInstall == false || model.updatePhase == .failed {
                    Button(l10n.t("update.action.copy_error")) {
                        model.copyUpdateErrorSummary()
                    }
                    .buttonStyle(SBButtonStyle(kind: .normal))
                    .accessibilityLabel(l10n.t("update.action.copy_error"))
                }
            }
            if !isBusy {
                if model.updateAwaitingInstallConfirm {
                    HStack(spacing: 8) {
                        Button(l10n.t("update.action.cancel")) {
                            model.cancelInstallConfirmation()
                        }
                        .buttonStyle(SBButtonStyle(kind: .normal))
                        .accessibilityLabel(l10n.t("update.action.cancel"))

                        Button(l10n.t(UpdateInstallConfirmCopy.confirmActionKey(for: assetKind))) {
                            model.confirmInstallUpdate()
                        }
                        .buttonStyle(SBButtonStyle(kind: .accent))
                        .accessibilityLabel(l10n.t(UpdateInstallConfirmCopy.confirmActionKey(for: assetKind)))
                    }
                } else {
                    Button(l10n.t("update.action.install")) {
                        model.requestInstallUpdate()
                    }
                    .buttonStyle(SBButtonStyle(kind: .accent))
                    .disabled(model.updateValidation?.canInstall != true)
                    .accessibilityLabel(l10n.t("update.action.install"))
                }
            }
        }
    }

    private var details: UpdateReleaseDetails? { model.updateDetails }

    private var assetKind: UpdateAssetKind {
        details?.asset?.kind ?? .pkg
    }

    private var checksumKey: String {
        model.updateValidation?.checksumDisplay.localizationKey ?? UpdateChecksumDisplay.pending.localizationKey
    }

    private var publishedText: String {
        guard let date = details?.publishedAt else { return l10n.t("update.unknown_value") }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private var sizeText: String {
        guard let size = details?.asset?.byteSize else { return l10n.t("update.unknown_value") }
        return UpdateByteCountFormatter.displayString(size)
    }

    private func fact(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SBTheme.text)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
