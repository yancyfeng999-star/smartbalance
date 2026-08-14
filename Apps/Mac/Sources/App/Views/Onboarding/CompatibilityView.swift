import SwiftUI
import Domain

enum CompatibilityPresentation {
    case embedded
    case blocking
    case settings
}

struct CompatibilityView: View {
    @ObservedObject var model: AppModel
    var presentation: CompatibilityPresentation = .embedded
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 10) {
            if presentation != .embedded {
                Text(l10n.t("compat.title"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SBTheme.text)
                    .accessibilityAddTraits(.isHeader)
            } else {
                Text(l10n.t("onboarding.compat.title"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SBTheme.text)
                    .accessibilityAddTraits(.isHeader)
            }

            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if let report = model.compatibilityReport {
                ForEach(report.checks) { item in
                    checkRow(item)
                }
            } else {
                Text(l10n.t("compat.loading"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
            }

            if presentation != .embedded {
                actionRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t("compat.title"))
        .task {
            if model.compatibilityReport == nil {
                await model.refreshCompatibilityReport()
            }
        }
    }

    private var subtitle: String {
        if presentation == .blocking {
            return l10n.t("compat.corrupt_state_detail")
        }
        return l10n.t("onboarding.compat.subtitle")
    }

    private var actionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if presentation == .blocking {
                Text(l10n.t("compat.corrupt_state"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SBTheme.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button(l10n.t("compat.open_settings")) {
                    model.openSettingsFromCompatibility()
                }
                .buttonStyle(SBButtonStyle(kind: .normal))
                .accessibilityLabel(l10n.t("compat.open_settings"))
                .keyboardShortcut("s")

                Button(l10n.t(presentation == .settings ? "compat.refresh" : "compat.continue_home")) {
                    if presentation == .settings {
                        Task { await model.refreshCompatibilityReport() }
                    } else {
                        model.dismissCompatibilityToHome()
                    }
                }
                .buttonStyle(SBButtonStyle(kind: .accent))
                .accessibilityLabel(l10n.t(presentation == .settings ? "compat.refresh" : "compat.continue_home"))
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func checkRow(_ item: CompatibilityCheck) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: statusSymbol(item.status))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusColor(item.status))
                .frame(width: 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t("compat.check.\(item.id)"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SBTheme.text)
                Text(l10n.t(item.messageKey))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(l10n.t("compat.check.\(item.id)")) · \(l10n.t(item.messageKey))")
        .accessibilityValue(l10n.t("compat.status.\(item.status.rawValue)"))
    }

    private func statusSymbol(_ status: CompatibilityStatus) -> String {
        switch status {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failed: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private func statusColor(_ status: CompatibilityStatus) -> Color {
        switch status {
        case .ok: SBTheme.ok
        case .warning: SBTheme.warn
        case .failed: SBTheme.danger
        case .unknown: SBTheme.muted
        }
    }
}
