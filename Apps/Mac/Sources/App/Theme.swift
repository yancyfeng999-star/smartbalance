import SwiftUI
import Domain

/// 视觉对齐智额 tokens：bg #0F1115 · panel #1A1D24 · accent #2866F7 · ok #30D158 · warn #FF9F0A · danger #FF453A
enum SBTheme {
    static let bg = Color(red: 0x0F / 255, green: 0x11 / 255, blue: 0x15 / 255)
    static let panel = Color(red: 0x1A / 255, green: 0x1D / 255, blue: 0x24 / 255)
    static let text = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let muted = Color(red: 0.60, green: 0.64, blue: 0.70)
    static let accent = Color(red: 0x28 / 255, green: 0x66 / 255, blue: 0xF7 / 255)
    static let stroke = Color.white.opacity(0.08)

    static let ok = Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
    static let warn = Color(red: 0xFF / 255, green: 0x9F / 255, blue: 0x0A / 255)
    static let danger = Color(red: 0xFF / 255, green: 0x45 / 255, blue: 0x3A / 255)

    static func statusColor(_ status: BalanceStatus) -> Color {
        switch status {
        case .healthy: ok
        case .warning: warn
        case .critical, .depleted, .error: danger
        case .unknown, .setup: muted
        }
    }
}
