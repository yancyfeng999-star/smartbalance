import SwiftUI
import Domain

struct HelpCenterView: View {
    var onSelect: (HelpTopicID) -> Void

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.t("help.title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SupportPalette.text(contrast: contrast))
                .accessibilityAddTraits(.isHeader)
            Text(l10n.t("help.subtitle"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SupportPalette.muted(contrast: contrast))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(HelpCenterCatalog.topics) { topic in
                Button {
                    onSelect(topic.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.t(topic.titleKey))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SupportPalette.text(contrast: contrast))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if let first = topic.bodyKeys.first {
                            Text(l10n.t(first))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(SupportPalette.muted(contrast: contrast))
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                            .fill(SBTheme.panel)
                            .overlay(
                                RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                                    .stroke(SupportPalette.cardStroke(contrast: contrast), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .supportButtonLabel(
                    l10n.t(topic.titleKey),
                    identifier: "help.topic.\(topic.id.rawValue)"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t("help.title"))
    }
}
