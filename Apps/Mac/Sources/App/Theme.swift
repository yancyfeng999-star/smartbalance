import SwiftUI
import AppKit
import Domain

// MARK: - Adaptive theme (follow system light / dark)

/// 视觉对齐智额 + 系统外观：白天浅色、晚上深色。
/// 使用 `NSColor` 动态 provider，SwiftUI 会在外观切换时自动刷新。
enum SBTheme {

    // MARK: Surfaces

    /// 窗口底：浅 #F4F5F8 · 深 #0F1115
    static let bg = adaptive(
        light: NSColor(srgbRed: 0xF4 / 255, green: 0xF5 / 255, blue: 0xF8 / 255, alpha: 1),
        dark: NSColor(srgbRed: 0x0F / 255, green: 0x11 / 255, blue: 0x15 / 255, alpha: 1)
    )

    /// 卡片/面板：浅白玻璃 · 深 #1A1D24
    static let panel = adaptive(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.92),
        dark: NSColor(srgbRed: 0x1A / 255, green: 0x1D / 255, blue: 0x24 / 255, alpha: 1)
    )

    /// 页脚 / 次级条
    static let panelElevated = adaptive(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.98),
        dark: NSColor(srgbRed: 0x14 / 255, green: 0x16 / 255, blue: 0x1C / 255, alpha: 1)
    )

    // MARK: Typography

    static let text = adaptive(
        light: NSColor(srgbRed: 0.12, green: 0.13, blue: 0.16, alpha: 1),
        dark: NSColor(srgbRed: 0.95, green: 0.96, blue: 0.97, alpha: 1)
    )

    static let muted = adaptive(
        light: NSColor(srgbRed: 0.42, green: 0.45, blue: 0.50, alpha: 1),
        dark: NSColor(srgbRed: 0.60, green: 0.64, blue: 0.70, alpha: 1)
    )

    // MARK: Accents & status（两边共用，略调浅色饱和度）

    /// 智额蓝 #2866F7
    static let accent = Color(red: 0x28 / 255.0, green: 0x66 / 255.0, blue: 0xF7 / 255.0)

    static let ok = Color(red: 0x30 / 255.0, green: 0xD1 / 255.0, blue: 0x58 / 255.0)
    static let warn = Color(red: 0xFF / 255.0, green: 0x9F / 255.0, blue: 0x0A / 255.0)
    static let danger = Color(red: 0xFF / 255.0, green: 0x45 / 255.0, blue: 0x3A / 255.0)

    // MARK: Chrome

    static let stroke = adaptive(
        light: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.08),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.08)
    )

    static let strokeStrong = adaptive(
        light: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.12),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.14)
    )

    static let progressTrack = adaptive(
        light: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.08),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.08)
    )

    static let chipIdle = adaptive(
        light: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.04),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.04)
    )

    static let cardCorner: CGFloat = 14
    static let controlCorner: CGFloat = 10

    static func statusColor(_ status: BalanceStatus) -> Color {
        switch status {
        case .healthy: ok
        case .warning: warn
        case .critical, .depleted, .error: danger
        case .unknown, .setup: muted
        }
    }

    // MARK: Factory

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? dark : light
        }))
    }
}

// MARK: - Shared chrome modifiers

extension View {
    /// 整页壳：跟随系统外观的底色。
    func sbShellBackground() -> some View {
        self.background(SBTheme.bg.ignoresSafeArea())
    }

    /// 标准卡片：面板底 + 细描边。
    func sbCardChrome(border: Color? = nil) -> some View {
        self
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                    .fill(SBTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: SBTheme.cardCorner, style: .continuous)
                            .stroke(border ?? SBTheme.stroke, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
            )
    }
}
