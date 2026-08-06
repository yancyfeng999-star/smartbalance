import SwiftUI
import AppKit
import Domain

/// 视觉与布局对齐智额截图：
/// - 顶栏：品牌 + 刷新文案 + 沙漏/刷新 + 图钉
/// - 底栏三等分：刷新 | 设置 | 退出应用
/// - 高度随内容收缩，上限滚动
struct MenuRootView: View {
    @ObservedObject var model: AppModel
    var runsInPinnedWindow: Bool = false

    private let maxPanelHeight: CGFloat = 640
    private let minPanelHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.selectedTab == .home {
                homeHeader
            } else {
                settingsHeader
            }

            Group {
                if needsScroll {
                    ScrollView {
                        content
                            .padding(.horizontal, 12)
                            .padding(.bottom, 10)
                    }
                } else {
                    content
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }
            .frame(maxHeight: contentMaxHeight, alignment: .top)

            if model.selectedTab == .home {
                homeFooter
            } else {
                settingsFooter
            }
        }
        .padding(.top, 4)
        .frame(width: SBTheme.panelWidth)
        .frame(height: panelHeight)
        .background(SBTheme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .preferredColorScheme(nil)
    }

    @ViewBuilder
    private var content: some View {
        if model.selectedTab == .home {
            HomeView(model: model)
        } else {
            SettingsRootView(model: model)
        }
    }

    // MARK: - Dynamic height

    /// 按卡片数量估算高度，内容少则矮，多则到上限后滚动。
    private var panelHeight: CGFloat {
        if model.selectedTab == .settings {
            return min(maxPanelHeight, 520)
        }
        let header: CGFloat = 48
        let footer: CGFloat = 54
        let pad: CGFloat = 14
        let banner: CGFloat = model.banner == nil ? 0 : 44
        let cards = model.snapshots.count
        let cardBlock: CGFloat = {
            if cards == 0 { return 132 }
            // 单卡约 118，间距 10
            return CGFloat(cards) * 118 + CGFloat(max(0, cards - 1)) * 10
        }()
        let alerts = min(2, model.recentAlerts.count)
        let alertBlock: CGFloat = alerts == 0 ? 0 : 22 + CGFloat(alerts) * 58
        let raw = header + footer + pad + banner + cardBlock + alertBlock
        return min(maxPanelHeight, max(minPanelHeight, raw))
    }

    private var contentMaxHeight: CGFloat {
        max(80, panelHeight - 48 - 54)
    }

    private var needsScroll: Bool {
        if model.selectedTab == .settings { return true }
        // 超过大约 4 张卡就滚
        return model.snapshots.count > 3 || model.recentAlerts.count > 2
    }

    // MARK: - Header

    private var homeHeader: some View {
        HStack(spacing: 8) {
            // 品牌标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.55, blue: 1.0),
                                Color(red: 0.55, green: 0.35, blue: 0.95),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Text("余")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(Brand.displayTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(SBTheme.text)
                Text(Brand.nameEN)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
            }

            Spacer(minLength: 6)

            Text(model.statusLine)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(SBTheme.muted)
                .monospacedDigit()

            Button {
                model.refresh()
            } label: {
                Image(systemName: model.isRefreshing ? "hourglass" : "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SBTheme.muted)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .disabled(model.isRefreshing)
            .help("刷新全部")
            .keyboardShortcut("r")

            Button {
                togglePin()
            } label: {
                let pinned = runsInPinnedWindow || model.settings.windowPinned || PinnedBalanceWindowController.shared.isPinned
                Image(systemName: pinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(pinned ? SBTheme.accent : SBTheme.muted)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help(runsInPinnedWindow || model.settings.windowPinned ? "取消置顶" : "置顶常驻窗口")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

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
                    Capsule().fill(SBTheme.footerFill)
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
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Footer（三等分：刷新 | 设置 | 退出应用）

    private var homeFooter: some View {
        HStack(spacing: 8) {
            footerPill(title: "刷新", systemName: "arrow.triangle.2.circlepath") {
                model.refresh()
            }
            .disabled(model.isRefreshing)

            footerPill(title: "设置", systemName: "gearshape") {
                model.selectedTab = .settings
            }
            .keyboardShortcut(",")

            footerPill(title: "退出应用", systemName: "power") {
                model.quit()
            }
            .help("完全退出智余（菜单栏图标会消失）")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var settingsFooter: some View {
        HStack {
            Spacer()
            Button {
                model.selectedTab = .home
            } label: {
                Text("完成")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(SBTheme.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func footerPill(title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(SBTheme.text.opacity(0.85))
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: SBTheme.controlCorner, style: .continuous)
                    .fill(SBTheme.footerFill)
                    .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
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

// MARK: - Shared buttons (settings forms)

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
        case .normal: SBTheme.stroke
        case .accent: SBTheme.accent.opacity(0.5)
        case .danger: SBTheme.danger.opacity(0.35)
        }
    }
}
