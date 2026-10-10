import SwiftUI
import Domain

struct BackupRestoreView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.t("settings.backup.subtitle"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: $model.restoreIncludeUsage) {
                Text(l10n.t("settings.backup.include_usage"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SBTheme.text)
            }
            .toggleStyle(.switch)
            .accessibilityLabel(l10n.t("settings.backup.include_usage"))

            Text(l10n.t("settings.backup.no_secrets"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(l10n.t("settings.backup.export")) {
                    model.exportLocalBackup()
                }
                .buttonStyle(SBButtonStyle(kind: .accent))
                .accessibilityLabel(l10n.t("settings.backup.export"))

                Button(l10n.t("settings.backup.restore")) {
                    model.pickLocalRestore()
                }
                .buttonStyle(SBButtonStyle(kind: .normal))
                .accessibilityLabel(l10n.t("settings.backup.restore"))
            }

            Button(l10n.t("settings.backup.open_dir")) {
                model.openBackupDirectory()
            }
            .buttonStyle(SBButtonStyle(kind: .normal))
            .accessibilityLabel(l10n.t("settings.backup.open_dir"))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t("settings.backup.title"))
    }
}
