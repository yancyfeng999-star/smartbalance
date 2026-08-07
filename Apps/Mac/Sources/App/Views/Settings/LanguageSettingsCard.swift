import SwiftUI
import Domain

/// 语言：可展开多语种网格（对齐智额）。
struct LanguageSettingsCard: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared
    @State private var isExpanded = false

    private var selected: AppLanguage {
        model.settings.resolvedLanguage
    }

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 0) {
            Button {
                AppMotion.toggleExpand($isExpanded)
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.35, green: 0.55, blue: 0.95),
                                        Color(red: 0.55, green: 0.35, blue: 0.90),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                        Image(systemName: "globe")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t("settings.language"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(SBTheme.text)
                        Text(l10n.t("settings.language_sub"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(SBTheme.muted)
                    }

                    Spacer(minLength: 8)

                    Text(selected.nativeName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SBTheme.text)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(SBTheme.footerFill)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(SBTheme.stroke, lineWidth: 0.9)
                                )
                        )

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SBTheme.muted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(AppMotion.chevron, value: isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().overlay(SBTheme.stroke)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                        ],
                        spacing: 8
                    ) {
                        ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, lang in
                            languageChip(lang, index: index)
                        }
                    }

                    Text(l10n.t("settings.language_hint"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(SBTheme.muted)
                }
                .padding(.top, 12)
                .transition(AppMotion.expandContent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                .fill(SBTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                        .stroke(SBTheme.cardStroke, lineWidth: 1)
                )
        )
        .animation(AppMotion.expand, value: isExpanded)
    }

    private func languageChip(_ lang: AppLanguage, index: Int) -> some View {
        let on = selected == lang
        return Button {
            AppMotion.withSelection {
                model.setLanguage(lang)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                AppMotion.withExpand {
                    isExpanded = false
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(lang.shortName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(on ? SBTheme.accent : SBTheme.muted)
                    .frame(width: 28, alignment: .leading)
                Text(lang.nativeName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(on ? SBTheme.text : SBTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SBTheme.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(on ? SBTheme.accent.opacity(0.12) : SBTheme.footerFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(on ? SBTheme.accent : SBTheme.stroke, lineWidth: on ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
