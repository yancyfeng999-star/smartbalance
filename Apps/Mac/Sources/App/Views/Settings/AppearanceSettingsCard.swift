import SwiftUI
import Domain

/// 外观：浅色 / 深色 / 跟随系统（对齐智额）。
struct AppearanceSettingsCard: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared

    private var current: ThemeMode {
        model.settings.resolvedThemeMode
    }

    var body: some View {
        let _ = l10n.revision
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.40, blue: 0.55),
                                    Color(red: 0.78, green: 0.28, blue: 0.82),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Image(systemName: current.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t("settings.appearance"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SBTheme.text)
                    Text(l10n.t("settings.choose_theme"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SBTheme.muted)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                ForEach(ThemeMode.allCases) { mode in
                    themeChip(mode)
                }
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
    }

    private func themeChip(_ mode: ThemeMode) -> some View {
        let on = current == mode
        return Button {
            AppMotion.withSelection {
                model.setThemeMode(mode)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(themeLabel(mode))
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .foregroundStyle(on ? SBTheme.accent : SBTheme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(on ? SBTheme.accent.opacity(0.12) : SBTheme.footerFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(on ? SBTheme.accent : SBTheme.stroke, lineWidth: on ? 1.5 : 0.9)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func themeLabel(_ mode: ThemeMode) -> String {
        switch mode {
        case .light: l10n.t("settings.theme.light")
        case .dark: l10n.t("settings.theme.dark")
        case .system: l10n.t("settings.theme.system")
        }
    }
}
