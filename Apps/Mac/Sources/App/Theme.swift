import SwiftUI
import AppKit
import Domain

/// 浅色：软灰紫底 + 白卡片；深色：深紫粉玻璃感（跟随系统）。
enum SBTheme {

    // 壳背景
    static let bg = adaptive(
        light: NSColor(srgbRed: 0.94, green: 0.92, blue: 0.98, alpha: 1),
        dark: NSColor(srgbRed: 0.12, green: 0.08, blue: 0.22, alpha: 1)
    )

    /// 卡片 / 面板填充
    static let panel = adaptive(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95),
        dark: NSColor(srgbRed: 0.22, green: 0.15, blue: 0.34, alpha: 0.92)
    )

    /// 选中 / setup 淡色底
    static let cardTint = adaptive(
        light: NSColor(srgbRed: 0.95, green: 0.93, blue: 1.0, alpha: 1),
        dark: NSColor(srgbRed: 0.28, green: 0.18, blue: 0.42, alpha: 1)
    )

    static let footerFill = adaptive(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.88),
        dark: NSColor(srgbRed: 0.18, green: 0.12, blue: 0.28, alpha: 0.95)
    )

    static let text = adaptive(
        light: NSColor(srgbRed: 0.15, green: 0.12, blue: 0.22, alpha: 1),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95)
    )

    static let muted = adaptive(
        light: NSColor(srgbRed: 0.45, green: 0.42, blue: 0.55, alpha: 1),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55)
    )

    /// 强调色：浅色紫粉、深色热粉
    static let accent = adaptive(
        light: NSColor(srgbRed: 0.55, green: 0.32, blue: 0.85, alpha: 1),
        dark: NSColor(srgbRed: 0.85, green: 0.35, blue: 0.65, alpha: 1)
    )

    static let ok = adaptive(
        light: NSColor(srgbRed: 0.22, green: 0.78, blue: 0.55, alpha: 1),
        dark: NSColor(srgbRed: 0.35, green: 0.92, blue: 0.68, alpha: 1)
    )
    static let warn = adaptive(
        light: NSColor(srgbRed: 0.92, green: 0.62, blue: 0.22, alpha: 1),
        dark: NSColor(srgbRed: 0.98, green: 0.72, blue: 0.35, alpha: 1)
    )
    static let danger = adaptive(
        light: NSColor(srgbRed: 0.92, green: 0.32, blue: 0.42, alpha: 1),
        dark: NSColor(srgbRed: 0.98, green: 0.42, blue: 0.52, alpha: 1)
    )

    static let stroke = adaptive(
        light: NSColor(srgbRed: 0.55, green: 0.32, blue: 0.85, alpha: 0.15),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.22)
    )

    static let cardStroke = adaptive(
        light: NSColor(srgbRed: 0.55, green: 0.32, blue: 0.85, alpha: 0.18),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.25)
    )

    static let progressTrack = adaptive(
        light: NSColor(srgbRed: 0.78, green: 0.76, blue: 0.88, alpha: 0.55),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.12)
    )

    static let chipIdle = adaptive(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.7),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.08)
    )

    /// 粉紫完成按钮渐变
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.40, blue: 0.55),
                Color(red: 0.78, green: 0.28, blue: 0.82),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// 弹层背景渐变（深色更明显）
    static func shellBackground(for scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.08, blue: 0.22),
                    Color(red: 0.18, green: 0.10, blue: 0.28),
                    Color(red: 0.22, green: 0.12, blue: 0.32),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.96, blue: 1.0),
                Color(red: 0.96, green: 0.94, blue: 0.99),
                Color(red: 0.94, green: 0.92, blue: 0.98),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 置顶窗 NSWindow 背景色（随系统）
    static var windowNSBackground: NSColor {
        NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return NSColor(srgbRed: 0.12, green: 0.08, blue: 0.22, alpha: 1)
            }
            return NSColor(srgbRed: 0.94, green: 0.92, blue: 0.98, alpha: 1)
        })
    }

    static let cardCorner: CGFloat = 16
    static let shellCorner: CGFloat = 22
    static let controlCorner: CGFloat = 12
    /// 弹层固定宽高（主页 = 设置，切换不跳尺寸）。
    static let panelWidth: CGFloat = 380
    static let preferredPanelHeight: CGFloat = 580
    static let minPanelHeight: CGFloat = 420

    /// 按屏幕可见高度取固定弹层高度。
    static func panelHeight(visibleScreenHeight: CGFloat = NSScreen.main?.visibleFrame.height ?? 900) -> CGFloat {
        let maxAllowed = max(visibleScreenHeight - 80, minPanelHeight)
        return min(preferredPanelHeight, maxAllowed)
    }

    static func statusColor(_ status: BalanceStatus) -> Color {
        switch status {
        case .healthy: ok
        case .warning: warn
        case .critical, .depleted, .error: danger
        case .unknown, .setup: muted
        }
    }

    /// 状态胶囊文案（充足 / 偏低 / …）
    static func statusLabel(_ status: BalanceStatus) -> String {
        switch status {
        case .healthy: "充足"
        case .warning: "偏低"
        case .critical: "危急"
        case .depleted: "耗尽"
        case .error: "失败"
        case .setup: "待配置"
        case .unknown: "未知"
        }
    }

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? dark : light
        }))
    }
}
