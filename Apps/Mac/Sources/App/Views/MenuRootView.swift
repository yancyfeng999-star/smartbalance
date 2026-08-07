import SwiftUI
import AppKit
import Domain

/// 菜单栏主壳：
/// - 外层 **固定宽高**（Popover 380×580），主页 / 设置同一壳，切换不跳
/// - 置顶窗铺满宿主，中间滚动
/// - 底栏三钮 / 设置右下角「完成」胶囊
struct MenuRootView: View {
    @ObservedObject var model: AppModel
    var runsInPinnedWindow: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let _ = l10n.revision
        ZStack {
            // 同一尺寸壳内切换，避免 if/else 换根视图时 ideal size 抖动
            if model.selectedTab == .settings {
                settingsShell
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            } else {
                homeShell
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            }
        }
        .background(SBTheme.shellBackground(for: colorScheme).ignoresSafeArea())
        .modifier(PinnedOrPopoverChrome(runsInPinnedWindow: runsInPinnedWindow))
        .preferredColorScheme(model.preferredColorScheme)
        .environment(\.layoutDirection, model.settings.resolvedLanguage == .ar ? .rightToLeft : .leftToRight)
        .onAppear {
            if runsInPinnedWindow {
                // 只设一次默认框，之后用户可拖；不跟内容跳
                PinnedBalanceWindowController.shared.ensureDefaultSize()
            }
            // 打开弹层时若尚未出结果，且当前没在刷，补一次
            if !model.isRefreshing,
               model.snapshots.isEmpty
                || model.snapshots.allSatisfy({ $0.status == .unknown && $0.amount == nil }) {
                model.refresh()
            }
        }
        .onChange(of: model.selectedTab) { _, _ in
            // 切 Tab 不改外框；置顶窗也禁止跟着内容收缩
            if runsInPinnedWindow {
                PinnedBalanceWindowController.shared.ensureDefaultSize(force: false)
            }
        }
    }

    // MARK: - Home shell

    private var homeShell: some View {
        VStack(spacing: 0) {
            homeHeader
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ScrollView(.vertical, showsIndicators: true) {
                HomeView(model: model)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            homeFooter
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Settings shell

    private var settingsShell: some View {
        VStack(spacing: 0) {
            settingsHeader
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ScrollView(.vertical, showsIndicators: true) {
                SettingsRootView(model: model)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            settingsFooter
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Header

    private var homeHeader: some View {
        HStack(spacing: 8) {
            Image("AppLogo")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(Brand.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SBTheme.text)
                Text(Brand.nameEN)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(SBTheme.muted)
            }

            Spacer(minLength: 8)

            Text(model.refreshTimeText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(SBTheme.muted)
                .monospacedDigit()

            Button {
                model.refresh()
            } label: {
                Image(systemName: model.isRefreshing ? "hourglass" : "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SBTheme.text)
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.plain)
            .disabled(model.isRefreshing)
            .help("刷新全部")
            .keyboardShortcut("r")

            Button {
                togglePin()
            } label: {
                // 仅当置顶窗真正打开时点亮
                let pinned = runsInPinnedWindow || model.pinWindowOpen
                Image(systemName: pinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(pinned ? SBTheme.accent : SBTheme.text)
                    .frame(width: 28, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(pinned ? SBTheme.accent.opacity(0.12) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help(
                (runsInPinnedWindow || model.pinWindowOpen)
                    ? "取消置顶"
                    : "置顶常驻窗口（点其他应用不关闭）"
            )
        }
    }

    private var settingsHeader: some View {
        HStack {
            Button {
                model.selectedTab = .home
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    Text(l10n.t("settings.back"))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(SBTheme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(SBTheme.footerFill)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(SBTheme.stroke, lineWidth: 0.9)
                        )
                )
            }
            .buttonStyle(.plain)

            Spacer()
            Text(l10n.t("settings.title"))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(SBTheme.text)
            Spacer()
            // 与左侧返回对称占位，标题居中
            Color.clear.frame(width: 72, height: 1)
        }
    }

    // MARK: - Footer

    private var homeFooter: some View {
        HStack(spacing: 8) {
            footerPill(title: l10n.t("home.open_dashboard"), systemName: "safari") {
                model.openDashboard()
            }
            .keyboardShortcut("d")
            .help("打开当前账号对应平台控制台")

            footerPill(title: l10n.t("home.settings"), systemName: "gearshape") {
                // 无动画切 Tab，避免壳层跟着 animation 抖
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    model.selectedTab = .settings
                }
            }
            .keyboardShortcut(",")

            footerPill(title: l10n.t("home.quit"), systemName: "power") {
                model.quit()
            }
            .help("完全退出智余（菜单栏图标会消失）")
        }
    }

    private var settingsFooter: some View {
        HStack {
            Spacer()
            Button {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    model.selectedTab = .home
                }
            } label: {
                Text(l10n.t("settings.done"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(SBTheme.accentGradient)
                            .shadow(color: Color(red: 0.9, green: 0.3, blue: 0.5).opacity(0.28), radius: 6, y: 2)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    /// 底栏按钮：对齐参考图深色圆角控件
    private func footerPill(title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SBTheme.text)
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SBTheme.footerFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(SBTheme.stroke, lineWidth: 0.8)
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
        case .normal: SBTheme.stroke
        case .accent: SBTheme.accent.opacity(0.5)
        case .danger: SBTheme.danger.opacity(0.35)
        }
    }
}
