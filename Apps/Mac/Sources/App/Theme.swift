import SwiftUI
import AppKit
import Domain

/// 视觉 token：浅色软灰；深色冷海军蓝玻璃（对齐参考图 membership 壳）。
enum SBTheme {

    // MARK: - Surfaces

    /// 弹层/窗底色（solid，供 NSWindow / 兼容）
    static let bg = adaptive(
        light: NSColor(srgbRed: 0.93, green: 0.94, blue: 0.97, alpha: 1),
        dark: NSColor(srgbRed: 0.07, green: 0.09, blue: 0.14, alpha: 1)
    )

    /// 卡片填充
    static let panel = adaptive(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.92),
        // 深色玻璃抬升 ~ white 8–11% on navy
        dark: NSColor(srgbRed: 0.16, green: 0.18, blue: 0.24, alpha: 1)
    )

    /// 选中 / setup 淡蓝底
    static let cardTint = adaptive(
        light: NSColor(srgbRed: 0.93, green: 0.95, blue: 1.0, alpha: 1),
        dark: NSColor(srgbRed: 0.14, green: 0.20, blue: 0.34, alpha: 1)
    )

    /// 底栏按钮填充
    static let footerFill = adaptive(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.72),
        dark: NSColor(srgbRed: 0.14, green: 0.16, blue: 0.22, alpha: 1)
    )

    // MARK: - Text

    static let text = adaptive(
        light: NSColor(srgbRed: 0.12, green: 0.13, blue: 0.18, alpha: 1),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95)
    )

    static let muted = adaptive(
        light: NSColor(srgbRed: 0.45, green: 0.48, blue: 0.55, alpha: 1),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55)
    )

    // MARK: - Accents & status（参考图蓝强调 + 系统绿/橙/红）

    /// #2866F7
    static let accent = Color(red: 0.157, green: 0.400, blue: 0.969)
    /// #7BA0FF
    static let accentSoft = Color(red: 0.482, green: 0.627, blue: 1.0)

    /// #30D158
    static let ok = Color(red: 0.188, green: 0.820, blue: 0.345)
    /// #FF9F0A
    static let warn = Color(red: 1.0, green: 0.624, blue: 0.039)
    /// #FF453A
    static let danger = Color(red: 1.0, green: 0.271, blue: 0.227)

    static let stroke = adaptive(
        light: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.08),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10)
    )

    static let cardStroke = adaptive(
        light: NSColor(srgbRed: 0.16, green: 0.40, blue: 0.97, alpha: 0.18),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.12)
    )

    /// 选中卡片描边（参考图 ChatGPT 卡蓝边）
    static let selectionStroke = Color(red: 0.157, green: 0.400, blue: 0.969).opacity(0.45)

    static let progressTrack = adaptive(
        light: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.08),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10)
    )

    static let chipIdle = adaptive(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.7),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.08)
    )

    /// 「完成」按钮：粉紫胶囊（设置页）
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

    /// 弹层背景渐变（深色：冷海军蓝）
    static func shellBackground(for scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.09, blue: 0.14),
                    Color(red: 0.10, green: 0.11, blue: 0.18),
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.94, blue: 0.97),
                Color(red: 0.90, green: 0.92, blue: 0.98),
                Color(red: 0.94, green: 0.93, blue: 0.97),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var windowNSBackground: NSColor {
        NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return NSColor(srgbRed: 0.07, green: 0.09, blue: 0.14, alpha: 1)
            }
            return NSColor(srgbRed: 0.93, green: 0.94, blue: 0.97, alpha: 1)
        })
    }

    static let cardCorner: CGFloat = 14
    static let shellCorner: CGFloat = 22
    static let controlCorner: CGFloat = 10
    static let panelWidth: CGFloat = 380
    static let preferredPanelHeight: CGFloat = 580
    static let minPanelHeight: CGFloat = 420

    static func panelHeight(visibleScreenHeight: CGFloat = NSScreen.main?.visibleFrame.height ?? 900) -> CGFloat {
        let maxAllowed = max(visibleScreenHeight - 80, minPanelHeight)
        return min(preferredPanelHeight, maxAllowed)
    }

    static func statusColor(_ status: BalanceStatus) -> Color {
        switch status {
        case .healthy: ok
        case .warning: warn
        case .caution: Color(red: 1.0, green: 0.48, blue: 0.12) // 深橙，介于黄与红
        case .critical, .depleted, .error: danger
        case .unknown, .setup: muted
        }
    }

    static func statusLabel(_ status: BalanceStatus) -> String {
        status.titleCN
    }

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? dark : light
        }))
    }
}
