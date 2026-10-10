import SwiftUI

struct PrivacySummaryView: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.t("onboarding.privacy.title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SBTheme.text)
                .accessibilityAddTraits(.isHeader)

            Text(l10n.t("onboarding.privacy.subtitle"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            bullet(l10n.t("onboarding.privacy.local"))
            bullet(l10n.t("onboarding.privacy.no_upload"))
            bullet(l10n.t("onboarding.privacy.keychain"))
            bullet(l10n.t("onboarding.privacy.no_secrets"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t("onboarding.privacy.title"))
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SBTheme.ok)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
