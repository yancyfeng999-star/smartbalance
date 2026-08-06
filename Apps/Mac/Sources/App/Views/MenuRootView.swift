import SwiftUI
import AppKit
import Domain

/// 对齐智额窗口：内容铺满整窗（非「小卡片浮在白窗上」）。
/// - 菜单栏弹出：高度随内容收紧
/// - 置顶窗：背景铺满；高度按内容收缩到合适尺寸
struct MenuRootView: View {
    @ObservedObject var model: AppModel
    var runsInPinnedWindow: Bool = false

    private let maxPanelHeight: CGFloat = 640
    private let minPanelHeight: CGFloat = 240
    private let panelWidth: CGFloat = 380

    var body: some View {
        VStack(spacing: 0) {
            if model.selectedTab == .home {
                homeHeader
            } else {
                settingsHeader
            }

            // 中间：卡片区撑满剩余空间（智额同款）
            Group {
                if needsScroll {
                    ScrollView(.vertical, showsIndicators: true) {
                        content
                            .padding(.horizontal, 14)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                } else {
                    content
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if model.selectedTab == .home {
                homeFooter
            } else {
                settingsFooter
            }
        }
        .frame(width: panelWidth, height: panelHeight, alignment: .top)
        .frame(maxWidth: runsInPinnedWindow ? .infinity : panelWidth)
        .background(SBTheme.bg)
        .preferredColorScheme(nil)
        .onAppear { syncPinnedWindowSize() }
        .onChange(of: model.snapshots.count) { _, _ in syncPinnedWindowSize() }
        .onChange(of: model.selectedTab) { _, _ in syncPinnedWindowSize() }
        .onChange(of: model.banner) { _, _ in syncPinnedWindowSize() }
        .onChange(of: model.recentAlerts.count) { _, _ in syncPinnedWindowSize() }
    }

    @ViewBuilder
    private var content: some View {
        if model.selectedTab == .home {
            HomeView(model: model)
        } else {
            SettingsRootView(model: model)
        }
    }

    // MARK: - Height

    private var panelHeight: CGFloat {
        if model.selectedTab == .settings {
            return min(maxPanelHeight, 520)
        }
        let header: CGFloat = 52
        let footer: CGFloat = 56
        let pad: CGFloat = 16
        let banner: CGFloat = model.banner == nil ? 0 : 44
        let cards = model.snapshots.count
        let cardBlock: CGFloat = cards == 0
            ? 140
            : CGFloat(cards) * 120 + CGFloat(max(0, cards - 1)) * 10
        let alerts = min(2, model.recentAlerts.count)
        let alertBlock: CGFloat = alerts == 0 ? 0 : 22 + CGFloat(alerts) * 58
        let raw = header + footer + pad + banner + cardBlock + alertBlock
        return min(maxPanelHeight, max(minPanelHeight, raw))
    }

    private var needsScroll: Bool {
        if model.selectedTab == .settings { return true }
        return model.snapshots.count > 3 || model.recentAlerts.count > 2
    }

    private func syncPinnedWindowSize() {
        guard runsInPinnedWindow else { return }
        PinnedBalanceWindowController.shared.resize(width: panelWidth, height: panelHeight)
    }

    // MARK: - Header

    private var homeHeader: some View {
        HStack(spacing: 8) {
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

            // 仅显示刷新时间（如「刷新 15:21」），不要「更新于…」长文案
            Text(model.refreshTimeText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
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
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(pinned ? SBTheme.accent.opacity(0.14) : Color.clear)
                    )
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

    // MARK: - Footer

    private var homeFooter: some View {
        HStack(spacing: 8) {
            // 对齐智额：打开后台 | 设置 | 退出应用
            footerPill(title: "打开后台", systemName: "safari") {
                model.openDashboard()
            }
            .keyboardShortcut("d")
            .help("打开当前账号对应平台控制台")

            footerPill(title: "设置", systemName: "gearshape") {
                model.selectedTab = .settings
            }
            .keyboardShortcut(",")

            footerPill(title: "退出应用", systemName: "power") {
                model.quit()
            }
            .help("完全退出智余（菜单栏图标会消失）")
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(SBTheme.bg)
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
        .background(SBTheme.bg)
    }

    private func footerPill(title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(SBTheme.text.opacity(0.88))
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: SBTheme.controlCorner, style: .continuous)
                    .fill(SBTheme.footerFill)
                    .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
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
        case .normal: SBTheme.stroke
        case .accent: SBTheme.accent.opacity(0.5)
        case .danger: SBTheme.danger.opacity(0.35)
        }
    }
}
