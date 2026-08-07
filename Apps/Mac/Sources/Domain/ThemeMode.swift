import Foundation

/// 界面外观：浅色 / 深色 / 跟随系统。
public enum ThemeMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case light
    case dark
    case system

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        case .system: "circle.lefthalf.filled"
        }
    }

    public static func resolve(_ raw: String?) -> ThemeMode {
        guard let raw, let m = ThemeMode(rawValue: raw) else { return .system }
        return m
    }
}
