import SwiftUI
import Domain

struct ActionableErrorView: View {
    let presentation: ActionableErrorPresentation
    var messageOverride: String? = nil
    let onAction: (ErrorNextAction) -> Void

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var focusedAction: ErrorNextAction?

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n.t(presentation.titleKey))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SupportPalette.danger(contrast: contrast))
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)

            Text(messageOverride ?? l10n.t(presentation.messageKey))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SupportPalette.text(contrast: contrast))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(actionRows, id: \.0) { pair in
                    HStack(spacing: 8) {
                        actionButton(pair.0)
                        if let second = pair.1 {
                            actionButton(second)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                .fill(SBTheme.warn.opacity(contrast == .increased ? 0.18 : 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                        .stroke(SupportPalette.cardStroke(contrast: contrast), lineWidth: contrast == .increased ? 1.5 : 1)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t(presentation.titleKey))
        .onAppear {
            focusedAction = presentation.actions.first
        }
    }

    private var actionRows: [(ErrorNextAction, ErrorNextAction?)] {
        var rows: [(ErrorNextAction, ErrorNextAction?)] = []
        let actions = presentation.actions
        var index = 0
        while index < actions.count {
            let first = actions[index]
            let second = index + 1 < actions.count ? actions[index + 1] : nil
            rows.append((first, second))
            index += 2
        }
        return rows
    }

    private func actionButton(_ action: ErrorNextAction) -> some View {
        let label = l10n.t(SupportAccessibilityCatalog.labelKey(for: action))
        let button = Button {
            onAction(action)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SBTheme.accent)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 28)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SBTheme.footerFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(SupportPalette.stroke(contrast: contrast), lineWidth: 0.8)
                        )
                )
        }
        .buttonStyle(.plain)
        .focused($focusedAction, equals: action)
        .supportButtonLabel(label, identifier: SupportAccessibilityCatalog.identifier(for: action))

        if action == presentation.actions.first {
            return AnyView(button.keyboardShortcut(.defaultAction))
        }
        return AnyView(button)
    }
}
