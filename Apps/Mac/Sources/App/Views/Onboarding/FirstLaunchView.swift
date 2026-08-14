import SwiftUI
import Domain

struct FirstLaunchView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared
    @FocusState private var focusedAction: OnboardingAction?

    private enum OnboardingAction: Hashable {
        case primary
        case secondary
        case tertiary
    }

    var body: some View {
        let _ = l10n.revision
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

            stepIndicator
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            ScrollView(.vertical, showsIndicators: true) {
                stepContent
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                            .fill(SBTheme.panel)
                            .overlay(
                                RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                                    .stroke(SBTheme.cardStroke, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t("onboarding.title"))
        .onAppear {
            focusedAction = .primary
        }
        .onChange(of: model.onboardingStep) { _, _ in
            focusedAction = .primary
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("AppLogo")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(l10n.t("onboarding.title"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SBTheme.text)
                Text(stepTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step == model.onboardingStep ? SBTheme.accent : SBTheme.stroke)
                    .frame(height: 4)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.onboardingStep {
        case .privacy:
            PrivacySummaryView()
        case .compatibility:
            CompatibilityView(model: model, presentation: .embedded)
        case .addProvider:
            providerStep
        case .notifications:
            notifyStep
        }
    }

    private var providerStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.t("onboarding.provider.title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SBTheme.text)
                .accessibilityAddTraits(.isHeader)
            Text(l10n.t("onboarding.provider.subtitle"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(l10n.t("onboarding.provider.no_keys"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t("onboarding.provider.title"))
    }

    private var notifyStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.t("onboarding.notify.title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SBTheme.text)
                .accessibilityAddTraits(.isHeader)
            Text(l10n.t("onboarding.notify.subtitle"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(l10n.t("onboarding.notify.optional"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t("onboarding.notify.title"))
    }

    private var footer: some View {
        VStack(spacing: 8) {
            switch model.onboardingStep {
            case .privacy:
                primaryButton(l10n.t("onboarding.privacy.continue")) {
                    model.acknowledgePrivacy()
                }
            case .compatibility:
                HStack(spacing: 8) {
                    secondaryButton(l10n.t("onboarding.compat.later")) {
                        model.skipCompatibilityForNow()
                    }
                    .focused($focusedAction, equals: .secondary)
                    primaryButton(l10n.t("onboarding.compat.continue")) {
                        model.continueFromCompatibility()
                    }
                }
            case .addProvider:
                VStack(spacing: 8) {
                    primaryButton(l10n.t("onboarding.provider.add")) {
                        model.chooseAddFirstProvider()
                    }
                    HStack(spacing: 8) {
                        secondaryButton(l10n.t("onboarding.provider.existing")) {
                            model.chooseOpenExistingConfiguration()
                        }
                        .focused($focusedAction, equals: .secondary)
                        secondaryButton(l10n.t("onboarding.provider.continue")) {
                            model.continueFromProviderStep()
                        }
                        .focused($focusedAction, equals: .tertiary)
                    }
                }
            case .notifications:
                HStack(spacing: 8) {
                    secondaryButton(l10n.t("onboarding.notify.skip")) {
                        model.skipNotificationsFromOnboarding()
                    }
                    .focused($focusedAction, equals: .secondary)
                    .keyboardShortcut(.cancelAction)
                    primaryButton(l10n.t("onboarding.notify.enable")) {
                        model.enableNotificationsFromOnboarding()
                    }
                }
            }
        }
    }

    private var stepTitle: String {
        switch model.onboardingStep {
        case .privacy: l10n.t("onboarding.step.privacy")
        case .compatibility: l10n.t("onboarding.step.compatibility")
        case .addProvider: l10n.t("onboarding.step.provider")
        case .notifications: l10n.t("onboarding.step.notifications")
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    Capsule(style: .continuous)
                        .fill(SBTheme.accentGradient)
                )
        }
        .buttonStyle(.plain)
        .focused($focusedAction, equals: .primary)
        .keyboardShortcut(.defaultAction)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SBTheme.text)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SBTheme.footerFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(SBTheme.stroke, lineWidth: 0.8)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}
