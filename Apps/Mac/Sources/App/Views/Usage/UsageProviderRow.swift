import SwiftUI
import Domain

struct UsageProviderRow: View {
    let summary: UsageProviderSummary
    var relativeAmount: Double? = nil

    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 9) {
                ProviderLogoView(kind: summary.providerKind, size: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.providerKind.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SBTheme.text)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        if summary.accountCount > 1 {
                            Text(accountCountText)
                        }
                        Text(qualityText)
                    }
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(qualityColor)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(UsageDisplayFormatter.amount(summary.totalAmount, unit: summary.unit))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(SBTheme.text)
                    .monospacedDigit()
            }

            if let relativeAmount {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(SBTheme.progressTrack)
                        Capsule(style: .continuous)
                            .fill(SBTheme.accent)
                            .frame(width: geometry.size.width * min(max(relativeAmount, 0), 1))
                    }
                }
                .frame(height: 5)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.providerKind.displayName)
        .accessibilityValue(accessibilityValue)
    }

    private var accountCountText: String {
        String(format: l10n.t("usage.accounts_count"), summary.accountCount)
    }

    private var qualityText: String {
        switch summary.quality {
        case .provider: l10n.t("usage.provider_quality")
        case .estimated: l10n.t("usage.estimated_quality")
        case .mixed: l10n.t("usage.mixed_quality")
        }
    }

    private var qualityColor: Color {
        switch summary.quality {
        case .provider: SBTheme.ok
        case .estimated: SBTheme.warn
        case .mixed: SBTheme.accentSoft
        }
    }

    private var accessibilityValue: String {
        let amount = UsageDisplayFormatter.amount(summary.totalAmount, unit: summary.unit)
        let accounts = summary.accountCount > 1 ? ", \(accountCountText)" : ""
        return "\(amount), \(summary.unit), \(qualityText)\(accounts)"
    }
}

enum UsageDisplayFormatter {
    static func amount(_ amount: Double, unit: String) -> String {
        let value = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), amount)
        let normalized = UsageUnit.normalize(unit)
        switch normalized {
        case "CNY", "USD":
            return "\(UsageUnit.symbol(for: normalized))\(value)"
        default:
            return normalized.isEmpty ? value : "\(value) \(normalized)"
        }
    }

    static func locale(for language: AppLanguage) -> Locale {
        Locale(identifier: language.rawValue)
    }

    static func date(_ date: Date, language: AppLanguage, includeYear: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale(for: language)
        formatter.setLocalizedDateFormatFromTemplate(includeYear ? "yMMMd" : "MMMd")
        return formatter.string(from: date)
    }

    static func dateTime(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale(for: language)
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
