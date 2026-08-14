import SwiftUI
import Domain

struct SafeModeView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let _ = l10n.revision
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(reasonText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SBTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    Toggle(isOn: $model.recoveryResetIncludeUsage) {
                        Text(l10n.t("recovery.action.resetSettings.include_usage"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SBTheme.text)
                    }
                    .toggleStyle(.switch)
                    .accessibilityLabel(l10n.t("recovery.action.resetSettings.include_usage"))

                    Text(l10n.t(RecoveryResetPolicy.leftoverCredentialsNoticeKey))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SBTheme.warn)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(RecoveryAction.allCases, id: \.self) { action in
                        RecoveryActionView(
                            action: action,
                            outcome: model.recoveryActionOutcome,
                            isConfirming: model.pendingRecoveryAction == action,
                            busy: model.recoveryBusy,
                            onRequest: { model.requestRecoveryAction(action) },
                            onConfirm: { model.confirmRecoveryAction() },
                            onCancel: { model.cancelRecoveryAction() }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t("recovery.title"))
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
                Text(l10n.t("recovery.title"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SBTheme.text)
                Text(l10n.t("recovery.subtitle"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var reasonText: String {
        if let reason = model.recoveryDecision.primaryReason {
            return l10n.t(reason.localizationKey)
        }
        return l10n.t("recovery.subtitle")
    }
}
