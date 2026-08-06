import SwiftUI
import AppKit
import Domain

/// 首页布局对齐智额：
/// - 右上角：刷新 + 图钉
/// - 底部：中部设置 · 右下退出
struct MenuRootView: View {
    @ObservedObject var model: AppModel
    /// 是否在独立置顶窗口中运行
    var runsInPinnedWindow: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.selectedTab == .home {
                homeHeader
            } else {
                settingsHeader
            }

            ScrollView {
                Group {
                    if model.selectedTab == .home {
                        HomeView(model: model)
                    } else {
                        SettingsRootView(model: model)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }

            if model.selectedTab == .home {
                homeFooter
            } else {
                settingsFooter
            }
        }
        .frame(width: 400, height: 560)
        .background(SBTheme.bg)
        .preferredColorScheme(nil)
    }

    // MARK: - Home header（右上：刷新 + 图钉）

    private var homeHeader: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Brand.displayTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(SBTheme.text)
                Text(Brand.nameEN)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
            }

            Spacer(minLength: 8)

            Text(model.statusLine)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(SBTheme.muted)
                .monospacedDigit()

            // 刷新
            Button {
                model.refresh()
            } label: {
                Image(systemName: model.isRefreshing ? "hourglass" : "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 26)
                    .foregroundStyle(SBTheme.text)
            }
            .buttonStyle(.plain)
            .disabled(model.isRefreshing)
            .help("刷新全部")
            .keyboardShortcut("r")

            // 图钉
            Button {
                togglePin()
            } label: {
                let pinned = runsInPinnedWindow || model.settings.windowPinned || PinnedBalanceWindowController.shared.isPinned
                Image(systemName: pinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 26)
                    .foregroundStyle(pinned ? SBTheme.accent : SBTheme.text)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(pinned ? SBTheme.accent.opacity(0.12) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help(runsInPinnedWindow || model.settings.windowPinned
                  ? "取消置顶"
                  : "置顶常驻窗口（点其他应用不关闭）")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Settings header

    private var settingsHeader: some View {
        HStack {
            Button {
                model.selectedTab = .home
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("返回")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(SBTheme.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(SBTheme.panel)
                        .overlay(Capsule().stroke(SBTheme.stroke, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("设置")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(SBTheme.text)

            Spacer()

            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Home footer（中部设置 · 右下退出）

    private var homeFooter: some View {
        HStack(spacing: 8) {
            // 左占位，让设置视觉居中、退出靠右（三等分槽位，对齐智额工具条）
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 32)

            footerCommandButton(title: "设置", systemName: "gearshape") {
                model.selectedTab = .settings
            }
            .keyboardShortcut(",")

            footerCommandButton(title: "退出", systemName: "power") {
                model.quit()
            }
            .help("完全退出智余（菜单栏图标会消失）")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(SBTheme.panelElevated.opacity(0.98))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SBTheme.stroke)
                .frame(height: 1)
        }
    }

    private var settingsFooter: some View {
        HStack {
            Spacer()
            Button {
                model.selectedTab = .home
            } label: {
                Text("完成")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(SBTheme.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(SBTheme.panelElevated.opacity(0.98))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SBTheme.stroke)
                .frame(height: 1)
        }
    }

    private func footerCommandButton(
        title: String,
        systemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SBTheme.text)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SBTheme.panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(SBTheme.strokeStrong, lineWidth: 0.8)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func togglePin() {
        if runsInPinnedWindow {
            PinnedBalanceWindowController.shared.close()
            return
        }
        PinnedBalanceWindowController.shared.bind(model: model)
        PinnedBalanceWindowController.shared.toggle()
    }
}

// MARK: - Shared buttons

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
                RoundedRectangle(cornerRadius: SBTheme.controlCorner, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: SBTheme.controlCorner, style: .continuous)
                            .stroke(border, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .normal: SBTheme.text
        case .accent: .white
        case .danger: SBTheme.danger
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
        case .normal: SBTheme.strokeStrong
        case .accent: SBTheme.accent.opacity(0.55)
        case .danger: SBTheme.danger.opacity(0.35)
        }
    }
}
