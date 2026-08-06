import Foundation

/// 后台同步间隔（对齐智额「后台同步」；额外提供 1H / 6H / 24H）。
public enum RefreshInterval: String, Codable, Sendable, Equatable, CaseIterable, Identifiable {
    case off
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case sixHours
    case twentyFourHours

    public var id: String { rawValue }

    /// 设置页分段/菜单选项。
    public static var pickerCases: [RefreshInterval] {
        [.off, .fifteenMinutes, .thirtyMinutes, .oneHour, .sixHours, .twentyFourHours]
    }

    public var seconds: Int? {
        switch self {
        case .off: nil
        case .fifteenMinutes: 900
        case .thirtyMinutes: 1800
        case .oneHour: 3600
        case .sixHours: 6 * 3600
        case .twentyFourHours: 24 * 3600
        }
    }

    public var isEnabled: Bool { self != .off }

    public var label: String {
        switch self {
        case .off: "关闭"
        case .fifteenMinutes: "15 分钟"
        case .thirtyMinutes: "30 分钟"
        case .oneHour: "1 小时"
        case .sixHours: "6 小时"
        case .twentyFourHours: "24 小时"
        }
    }

    public static func from(seconds: Int) -> RefreshInterval {
        guard seconds > 0 else { return .off }
        return pickerCases
            .filter { $0.seconds != nil }
            .min { abs(($0.seconds ?? 0) - seconds) < abs(($1.seconds ?? 0) - seconds) }
            ?? .fifteenMinutes
    }
}
