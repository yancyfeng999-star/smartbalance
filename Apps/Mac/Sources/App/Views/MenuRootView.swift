import SwiftUI
import Domain

struct MenuRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                Group {
                    if model.selectedTab == .home {
                        HomeView(model: model)
                    } else {
                        SettingsView(model: model)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            footer
        }
        .frame(width: 380, height: 560)
        .background(SBTheme.bg)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Brand.displayTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SBTheme.text)
                Text(model.statusLine)
                    .font(.system(size: 11))
                    .foregroundStyle(SBTheme.muted)
            }
            Spacer()
            HStack(spacing: 6) {
                tabButton("首页", tab: .home)
                tabButton("设置", tab: .settings)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func tabButton(_ title: String, tab: AppModel.Tab) -> some View {
        Button {
            model.selectedTab = tab
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(model.selectedTab == tab ? SBTheme.text : SBTheme.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(model.selectedTab == tab ? SBTheme.panel : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    model.selectedTab == tab
                                        ? SBTheme.accent.opacity(0.45)
                                        : SBTheme.stroke,
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack {
            Button {
                model.refresh()
            } label: {
                Label(model.isRefreshing ? "刷新中…" : "刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SBButtonStyle(kind: .normal))
            .disabled(model.isRefreshing)

            Spacer()

            Button("退出 \(Brand.nameCN)") {
                model.quit()
            }
            .buttonStyle(SBButtonStyle(kind: .danger))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(SBTheme.bg.opacity(0.95))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SBTheme.stroke)
                .frame(height: 1)
        }
    }
}

struct SBButtonStyle: ButtonStyle {
    enum Kind { case normal, accent, danger }
    var kind: Kind = .normal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(border, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .normal: SBTheme.text
        case .accent: .white
        case .danger: Color(red: 1, green: 0.54, blue: 0.50)
        }
    }

    private var background: Color {
        switch kind {
        case .normal: SBTheme.panel
        case .accent: SBTheme.accent
        case .danger: SBTheme.danger.opacity(0.12)
        }
    }

    private var border: Color {
        switch kind {
        case .normal: SBTheme.stroke
        case .accent: SBTheme.accent.opacity(0.6)
        case .danger: SBTheme.danger.opacity(0.35)
        }
    }
}
