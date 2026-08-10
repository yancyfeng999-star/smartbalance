import SwiftUI
import Domain

struct UsageView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared

    @State private var period: UsagePeriod = .day
    @State private var anchor = Date()

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }

    private var summary: UsageDashboardSummary {
        model.usageSummary(period: period, anchor: anchor, calendar: calendar)
    }

    var body: some View {
        let currentSummary = summary
        VStack(alignment: .leading, spacing: 12) {
            periodPicker
            periodNavigator(summary: currentSummary)

            if model.usageDataError != nil {
                Label(l10n.t("usage.save_failed"), systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content(summary: currentSummary)

            if currentSummary.hasBoundaryGap {
                Label(l10n.t("usage.boundary_hint"), systemImage: "moon.zzz")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let updatedAt = currentSummary.updatedAt {
                Text("\(l10n.t("usage.last_updated")) · \(UsageDisplayFormatter.dateTime(updatedAt, language: l10n.language))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(UsagePeriod.allCases, id: \.rawValue) { candidate in
                Button {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        period = candidate
                        anchor = Date()
                    }
                } label: {
                    Text(title(for: candidate))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(period == candidate ? Color.white : SBTheme.text)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(period == candidate ? SBTheme.accent : SBTheme.footerFill)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(period == candidate ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SBTheme.progressTrack)
        )
    }

    private func periodNavigator(summary: UsageDashboardSummary) -> some View {
        HStack(spacing: 10) {
            navigationButton(
                systemName: "chevron.left",
                label: l10n.t("usage.previous"),
                disabled: !UsageSummaryBuilder.canMoveBackward(
                    summary: summary,
                    period: period,
                    anchor: anchor,
                    calendar: calendar
                )
            ) {
                anchor = UsageSummaryBuilder.shiftedAnchor(
                    anchor,
                    period: period,
                    offset: -1,
                    calendar: calendar
                )
            }

            Text(periodLabel(summary: summary))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(SBTheme.text)
                .frame(maxWidth: .infinity)
                .lineLimit(1)

            navigationButton(
                systemName: "chevron.right",
                label: l10n.t("usage.next"),
                disabled: !UsageSummaryBuilder.canMoveForward(
                    period: period,
                    anchor: anchor,
                    now: Date(),
                    calendar: calendar
                )
            ) {
                let shifted = UsageSummaryBuilder.shiftedAnchor(
                    anchor,
                    period: period,
                    offset: 1,
                    calendar: calendar
                )
                anchor = UsageSummaryBuilder.clampedAnchor(
                    shifted,
                    period: period,
                    now: Date(),
                    calendar: calendar
                )
            }
        }
    }

    @ViewBuilder
    private func content(summary: UsageDashboardSummary) -> some View {
        if model.settings.enabledAccounts.isEmpty {
            emptyState(
                systemName: "person.crop.circle.badge.plus",
                text: l10n.t("usage.no_accounts"),
                actionTitle: l10n.t("usage.open_settings")
            ) {
                model.selectedTab = .settings
            }
        } else if !summary.hasAnyBaseline {
            emptyState(
                systemName: "gauge.with.dots.needle.0percent",
                text: l10n.t("usage.baseline_only")
            )
        } else if summary.currencies.isEmpty {
            emptyState(
                systemName: "chart.bar.xaxis",
                text: l10n.t("usage.no_spend")
            )
        } else {
            ForEach(summary.currencies) { currency in
                UsageCurrencyCard(summary: currency, period: period)
            }
        }
    }

    private func emptyState(
        systemName: String,
        text: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(SBTheme.accent)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(SBButtonStyle(kind: .accent))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                .fill(SBTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                        .stroke(SBTheme.cardStroke, lineWidth: 1)
                )
        )
    }

    private func navigationButton(
        systemName: String,
        label: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(SBTheme.text)
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SBTheme.footerFill)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .help(label)
        .accessibilityLabel(label)
    }

    private func title(for period: UsagePeriod) -> String {
        switch period {
        case .day: l10n.t("usage.day")
        case .week: l10n.t("usage.week")
        case .month: l10n.t("usage.month")
        }
    }

    private func periodLabel(summary: UsageDashboardSummary) -> String {
        let current = UsageSummaryBuilder.interval(for: period, anchor: Date(), calendar: calendar)
        if current.start == summary.interval.start {
            switch period {
            case .day: return l10n.t("usage.current_day")
            case .week: return l10n.t("usage.current_week")
            case .month: return l10n.t("usage.current_month")
            }
        }

        switch period {
        case .day:
            return UsageDisplayFormatter.date(summary.interval.start, language: l10n.language, includeYear: true)
        case .week:
            let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: summary.interval.end) ?? summary.interval.end
            return "\(UsageDisplayFormatter.date(summary.interval.start, language: l10n.language)) – \(UsageDisplayFormatter.date(inclusiveEnd, language: l10n.language))"
        case .month:
            let formatter = DateFormatter()
            formatter.locale = UsageDisplayFormatter.locale(for: l10n.language)
            formatter.setLocalizedDateFormatFromTemplate("yMMMM")
            return formatter.string(from: summary.interval.start)
        }
    }
}
