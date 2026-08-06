import SwiftUI
import AppKit
import Domain

/// 浅色软灰底 + 白卡片 + 圆角胶囊底栏；深色跟随系统。
enum SBTheme {

    // 壳：截图浅色 ~ #EBEDF5
    static let bg = adaptive(
        light: NSColor(srgbRed: 0.92, green: 0.93, blue: 0.96, alpha: 1),
        dark: NSColor(srgbRed: 0x0F / 255, green: 0x11 / 255, blue: 0x15 / 255, alpha: 1)
    )

    static let panel = adaptive(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.96),
        dark: NSColor(srgbRed: 0x1A / 255, green: 0x1D / 255, blue: 0x24 / 255, alpha: 1)
    )

    /// 选中/强调卡片淡蓝底（ChatGPT 卡那种）
    static let cardTint = adaptive(
        light: NSColor(srgbRed: 0.93, green: 0.94, blue: 1.0, alpha: 1),
        dark: NSColor(srgbRed: 0.16, green: 0.18, blue: 0.28, alpha: 1)
    )

    static let footerFill = adaptive(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.88),
        dark: NSColor(srgbRed: 0.12, green: 0.13, blue: 0.16, alpha: 1)
    )

    static let text = adaptive(
        light: NSColor(srgbRed: 0.12, green: 0.13, blue: 0.18, alpha: 1),
        dark: NSColor(srgbRed: 0.95, green: 0.96, blue: 0.97, alpha: 1)
    )

    static let muted = adaptive(
        light: NSColor(srgbRed: 0.45, green: 0.48, blue: 0.55, alpha: 1),
        dark: NSColor(srgbRed: 0.60, green: 0.64, blue: 0.70, alpha: 1)
    )

    static let accent = Color(red: 0.35, green: 0.42, blue: 0.95) // soft indigo like screenshot
    static let ok = Color(red: 0.25, green: 0.78, blue: 0.48)
    static let warn = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let danger = Color(red: 1.0, green: 0.27, blue: 0.23)

    static let stroke = adaptive(
        light: NSColor(srgbRed: 0.55, green: 0.58, blue: 0.75, alpha: 0.18),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10)
    )

    static let cardStroke = adaptive(
        light: NSColor(srgbRed: 0.45, green: 0.50, blue: 0.85, alpha: 0.22),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.12)
    )

    static let progressTrack = adaptive(
        light: NSColor(srgbRed: 0.78, green: 0.80, blue: 0.88, alpha: 0.55),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10)
    )

    static let chipIdle = adaptive(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.7),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.06)
    )

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
