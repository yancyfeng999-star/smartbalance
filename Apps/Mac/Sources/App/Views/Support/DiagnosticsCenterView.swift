import SwiftUI
import Domain

struct DiagnosticsCenterView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared
    @State private var showingExport = false

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 10) {
            if showingExport {
                DiagnosticExportSheet(
                    excludedFields: model.diagnosticReport?.excludedFields ?? DiagnosticReport.defaultExcludedFields,
                    onConfirm: {
                        showingExport = false
                        model.exportDiagnostics()
                    },
                    onCancel: { showingExport = false }
                )
            } else {
                header
                if model.isCollectingDiagnostics && model.diagnosticReport == nil {
                    Text(l10n.t("diagnostics.loading"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SBTheme.muted)
                }
                if let report = model.diagnosticReport {
                    allowlistFacts(report)
                    ForEach(report.checks) { item in
                        DiagnosticCheckRow(item: item)
                    }
                }
                actions
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t("diagnostics.title"))
        .task {
            if model.diagnosticReport == nil {
                await model.refreshDiagnostics()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l10n.t("diagnostics.title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SBTheme.text)
                .accessibilityAddTraits(.isHeader)
            Text(l10n.t("diagnostics.subtitle"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func allowlistFacts(_ report: DiagnosticReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l10n.t("diagnostics.facts.title"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SBTheme.text)
            Text(DiagnosticReadableSummary.refreshLine(report.refresh))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(DiagnosticReadableSummary.providerLines(report.providers), id: \.self) { line in
                Text(line)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(SBTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(l10n.t(usageHealthKey(report.usage.health)))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(DiagnosticReadableSummary.usageLine(report.usage))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(l10n.t("diagnostics.facts.title"))
    }

    private func usageHealthKey(_ raw: String) -> String {
        UsageStorageHealth(rawValue: raw)?.messageKey ?? UsageStorageHealth.available.messageKey
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                actionButton(titleKey: "diagnostics.recheck", systemName: "arrow.clockwise") {
                    Task { await model.refreshDiagnostics() }
                }
                actionButton(titleKey: "diagnostics.copy", systemName: "doc.on.doc") {
                    model.copyDiagnosticsSummary()
                }
            }
            HStack(spacing: 8) {
                actionButton(titleKey: "diagnostics.export", systemName: "square.and.arrow.up") {
                    showingExport = true
                }
                actionButton(titleKey: "diagnostics.open_settings", systemName: "gearshape") {
                    model.openSettingsFromDiagnostics()
                }
            }
            HStack(spacing: 8) {
                actionButton(titleKey: "diagnostics.open_logs", systemName: "folder") {
                    model.openLogs()
                }
                actionButton(titleKey: "diagnostics.open_help", systemName: "questionmark.circle") {
                    model.openDiagnosticsHelp()
                }
                .supportButtonLabel(
                    l10n.t("diagnostics.open_help"),
                    identifier: SupportAccessibilityID.navHelp.rawValue
                )
            }
        }
        .padding(.top, 4)
    }

    private func actionButton(titleKey: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(l10n.t(titleKey), systemImage: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SBTheme.text)
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SBTheme.footerFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(SBTheme.stroke, lineWidth: 0.8)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l10n.t(titleKey))
        .disabled(model.isCollectingDiagnostics && titleKey == "diagnostics.recheck")
    }
}
