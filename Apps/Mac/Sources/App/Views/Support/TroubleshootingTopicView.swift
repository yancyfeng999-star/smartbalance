import SwiftUI
import Domain

struct TroubleshootingTopicView: View {
    let topicID: HelpTopicID

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let _ = l10n.revision
        let topic = HelpCenterCatalog.topic(topicID)
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.t(topic.titleKey))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SupportPalette.text(contrast: contrast))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            ForEach(topic.bodyKeys, id: \.self) { key in
                Text(l10n.t(key))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SupportPalette.text(contrast: contrast))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.t(topic.titleKey))
        .accessibilityIdentifier("help.topic.\(topicID.rawValue).detail")
    }
}
