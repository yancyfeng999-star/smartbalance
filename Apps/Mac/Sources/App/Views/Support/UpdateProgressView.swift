import SwiftUI
import Domain

struct UpdateProgressView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 8) {
            if let progress = model.updateDownloadProgress {
                ProgressView(value: progress, total: 1)
                    .progressViewStyle(.linear)
                    .tint(SBTheme.accent)
                    .accessibilityLabel(l10n.t("update.progress.downloading"))
            } else {
                ProgressView()
                    .controlSize(.small)
            }
            Text(model.updateMessage ?? l10n.t("update.progress.validating"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if model.updatePhase == .downloading {
                Button(l10n.t("update.action.cancel_download")) {
                    model.cancelUpdateDownload()
                }
                .buttonStyle(SBButtonStyle(kind: .normal))
                .accessibilityLabel(l10n.t("update.action.cancel_download"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
