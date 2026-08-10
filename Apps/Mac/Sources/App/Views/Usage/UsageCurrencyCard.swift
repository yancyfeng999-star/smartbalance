import SwiftUI
import Charts
import Domain

struct UsageCurrencyCard: View {
    let summary: UsageCurrencySummary
    let period: UsagePeriod

    @ObservedObject private var l10n = L10n.shared
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(summary.unit)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(SBTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(SBTheme.accent.opacity(0.11))
                    )

                Spacer()

                Text(UsageDisplayFormatter.amount(summary.totalAmount, unit: summary.unit))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(SBTheme.text)
                    .monospacedDigit()
            }

            if period != .day {
                trendChart
            }

            VStack(spacing: 10) {
                ForEach(Array(summary.providers.enumerated()), id: \.element.id) { index, provider in
                    UsageProviderRow(
                        summary: provider,
                        relativeAmount: period == .day ? relativeAmount(for: provider) : nil
                    )
                    if index < summary.providers.count - 1 {
                        Divider().overlay(SBTheme.stroke)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                .fill(SBTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                        .stroke(SBTheme.cardStroke, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(summary.unit), \(UsageDisplayFormatter.amount(summary.totalAmount, unit: summary.unit))")
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let selectedPoint {
                HStack(spacing: 5) {
                    Text(UsageDisplayFormatter.date(selectedPoint.date, language: l10n.language))
                    Text("·")
                    Text(UsageDisplayFormatter.amount(selectedPoint.amount, unit: summary.unit))
                        .monospacedDigit()
                    if selectedPoint.includesEstimate {
                        Text("· \(l10n.t("usage.estimated_quality"))")
                            .foregroundStyle(SBTheme.warn)
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SBTheme.muted)
                .lineLimit(1)
            }

            Chart {
                ForEach(summary.dailyPoints) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Amount", point.amount)
                    )
                    .foregroundStyle(
                        selectedPoint?.dayKey == point.dayKey
                            ? SBTheme.usageSelection
                            : SBTheme.accent
                    )
                    .cornerRadius(2)
                }

                if let selectedPoint {
                    RuleMark(x: .value("Selected", selectedPoint.date, unit: .day))
                        .foregroundStyle(SBTheme.usageSelection.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { _ in
                    AxisGridLine().foregroundStyle(SBTheme.stroke)
                    AxisTick().foregroundStyle(SBTheme.muted)
                    AxisValueLabel(format: .dateTime.day())
                        .foregroundStyle(SBTheme.muted)
                        .font(.system(size: 9))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(SBTheme.stroke)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(compactAmount(amount))
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(SBTheme.muted)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedDate)
            .frame(height: 112)
            .accessibilityLabel("\(summary.unit) \(periodTitle)")
            .accessibilityValue(UsageDisplayFormatter.amount(summary.totalAmount, unit: summary.unit))
        }
    }

    private var selectedPoint: UsageDailyPoint? {
        guard let selectedDate else { return nil }
        return summary.dailyPoints.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var periodTitle: String {
        switch period {
        case .day: l10n.t("usage.day")
        case .week: l10n.t("usage.week")
        case .month: l10n.t("usage.month")
        }
    }

    private func relativeAmount(for provider: UsageProviderSummary) -> Double {
        let maximum = summary.providers.map(\.totalAmount).max() ?? 0
        guard maximum > 0 else { return 0 }
        return provider.totalAmount / maximum
    }

    private func compactAmount(_ amount: Double) -> String {
        if amount >= 1_000 {
            return String(format: "%.1fk", amount / 1_000)
        }
        if amount >= 10 {
            return String(format: "%.0f", amount)
        }
        return String(format: "%.1f", amount)
    }
}
