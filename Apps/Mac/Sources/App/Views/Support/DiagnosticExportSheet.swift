import SwiftUI
import Domain

struct DiagnosticExportSheet: View {
    let excludedFields: [String]
    var onConfirm: () -> Void
    var onCancel: () -> Void
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.t("diagnostics.export.title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SBTheme.text)
                .accessibilityAddTraits(.isHeader)

            Text(l10n.t("diagnostics.export.excluded_intro"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(excludedFields, id: \.self) { field in
                    Text("· \(field)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(SBTheme.text)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(SBTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(SBTheme.stroke, lineWidth: 0.8)
                    )
            )

            HStack(spacing: 8) {
                Button(l10n.t("diagnostics.export.cancel"), action: onCancel)
                    .buttonStyle(SBButtonStyle(kind: .normal))
                    .accessibilityLabel(l10n.t("diagnostics.export.cancel"))
                Button(l10n.t("diagnostics.export.confirm"), action: onConfirm)
                    .buttonStyle(SBButtonStyle(kind: .accent))
                    .accessibilityLabel(l10n.t("diagnostics.export.confirm"))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
