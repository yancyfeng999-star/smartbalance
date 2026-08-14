import SwiftUI
import Domain

struct SettingsTransferView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.t("settings.transfer.subtitle"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Text(l10n.t("settings.transfer.no_secrets"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(l10n.t("settings.transfer.export")) {
                    model.exportSettingsTransfer()
                }
                .buttonStyle(SBButtonStyle(kind: .accent))
                .accessibilityLabel(l10n.t("settings.transfer.export"))

                Button(l10n.t("settings.transfer.import")) {
                    model.pickSettingsImport()
                }
                .buttonStyle(SBButtonStyle(kind: .normal))
                .accessibilityLabel(l10n.t("settings.transfer.import"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t("settings.transfer.title"))
    }
}
