import SwiftUI
import Domain

/// 视觉对齐智额：深色底、面板卡、状态色。
enum SBTheme {
    static let bg = Color(red: 0.06, green: 0.07, blue: 0.08)
    static let panel = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let text = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let muted = Color(red: 0.60, green: 0.64, blue: 0.70)
    static let accent = Color(red: 0.16, green: 0.40, blue: 0.97)
    static let stroke = Color.white.opacity(0.08)

    static let ok = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let warn = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let danger = Color(red: 1.0, green: 0.27, blue: 0.23)

    static func statusColor(_ status: BalanceStatus) -> Color {
        switch status {
        case .healthy: ok
        case .warning: warn
        case .critical, .depleted, .error: danger
        case .unknown, .setup: muted
        }
    }
}
