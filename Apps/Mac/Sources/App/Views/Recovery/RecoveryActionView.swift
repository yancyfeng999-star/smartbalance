import SwiftUI
import Domain

struct RecoveryActionView: View {
    let action: RecoveryAction
    var outcome: RecoveryActionOutcome?
    var isConfirming: Bool
    var busy: Bool
    let onRequest: () -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.t(action.titleKey))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SBTheme.text)
            Text(l10n.t(action.detailKey))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if isConfirming {
                Text(l10n.t(RecoveryActionPolicy.confirmMessageKey(for: action)))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SBTheme.warn)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button(l10n.t(RecoveryActionPolicy.confirmActionKey(for: action))) {
                        onConfirm()
                    }
                    .buttonStyle(SBButtonStyle(kind: RecoveryActionPolicy.isDangerous(action) ? .danger : .accent))
                    .disabled(busy)
                    .accessibilityLabel(l10n.t(RecoveryActionPolicy.confirmActionKey(for: action)))

                    Button(l10n.t(RecoveryActionPolicy.cancelActionKey())) {
                        onCancel()
                    }
                    .buttonStyle(SBButtonStyle(kind: .normal))
                    .disabled(busy)
                    .accessibilityLabel(l10n.t(RecoveryActionPolicy.cancelActionKey()))
                }
            } else {
                Button(l10n.t(action.titleKey)) {
                    onRequest()
                }
                .buttonStyle(SBButtonStyle(kind: buttonKind))
                .disabled(busy)
                .supportButtonLabel(l10n.t(action.titleKey), identifier: "recovery.action.\(action.rawValue)")
            }

            if let outcome, outcome.action == action, outcome.status == .succeeded || outcome.status == .failed {
                Text(l10n.t(outcome.messageKey))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(outcome.status == .failed ? SBTheme.danger : SBTheme.ok)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                .fill(SBTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                        .stroke(SBTheme.cardStroke, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t(action.titleKey))
    }

    private var buttonKind: SBButtonStyle.Kind {
        if RecoveryActionPolicy.isDangerous(action) { return .danger }
        if action == .continueNormalStart { return .accent }
        return .normal
    }
}
