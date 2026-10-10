import SwiftUI
import Domain

struct DiagnosticCheckRow: View {
    let item: DiagnosticCheck
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let _ = l10n.revision
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: statusSymbol(item.status))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusColor(item.status))
                .frame(width: 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t(item.titleKey))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SBTheme.text)
                Text(detailText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(l10n.t(item.titleKey)) · \(detailText)")
        .accessibilityValue(l10n.t("diagnostics.status.\(item.status.rawValue)"))
    }

    private var detailText: String {
        let localized = l10n.t(item.detailKey)
        if let extra = item.redactedDetail, !extra.isEmpty {
            return "\(localized) \(extra)"
        }
        return localized
    }

    private func statusSymbol(_ status: DiagnosticStatus) -> String {
        switch status {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failed: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private func statusColor(_ status: DiagnosticStatus) -> Color {
        switch status {
        case .ok: SBTheme.ok
        case .warning: SBTheme.warn
        case .failed: SBTheme.danger
        case .unknown: SBTheme.muted
        }
    }
}
