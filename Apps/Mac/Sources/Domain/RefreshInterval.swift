import Foundation

/// 后台同步间隔。
/// 第一行：关闭 · 15 分钟 · 30 分钟 · 60 分钟
/// 第二行：4 小时 · 12 小时 · 24 小时
public enum RefreshInterval: String, Codable, Sendable, Equatable, CaseIterable, Identifiable {
    case off
    case fifteenMinutes
    case thirtyMinutes
    case sixtyMinutes
    case fourHours
    case twelveHours
    case twentyFourHours

    public var id: String { rawValue }

    public static var row1: [RefreshInterval] {
        [.off, .fifteenMinutes, .thirtyMinutes, .sixtyMinutes]
    }

    public static var row2: [RefreshInterval] {
        [.fourHours, .twelveHours, .twentyFourHours]
    }

    public static var pickerCases: [RefreshInterval] {
        row1 + row2
    }

    public var seconds: Int? {
        switch self {
        case .off: nil
        case .fifteenMinutes: 900
        case .thirtyMinutes: 1800
        case .sixtyMinutes: 3600
        case .fourHours: 4 * 3600
        case .twelveHours: 12 * 3600
        case .twentyFourHours: 24 * 3600
        }
    }

    public var isEnabled: Bool { self != .off }

    public var label: String {
        switch self {
        case .off: "关闭"
        case .fifteenMinutes: "15分钟"
        case .thirtyMinutes: "30分钟"
        case .sixtyMinutes: "60分钟"
        case .fourHours: "4H"
        case .twelveHours: "12H"
        case .twentyFourHours: "24H"
        }
    }

    public static func from(seconds: Int) -> RefreshInterval {
        guard seconds > 0 else { return .off }
        // 兼容旧 1H / 6H 映射到最近档
        return pickerCases
            .filter { $0.seconds != nil }
            .min { abs(($0.seconds ?? 0) - seconds) < abs(($1.seconds ?? 0) - seconds) }
            ?? .fifteenMinutes
    }
}
