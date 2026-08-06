import Foundation

/// 设置页展示用的能力说明（数据源 + 报警通道）。
public enum CapabilityGroup: String, CaseIterable, Sendable {
    case dataSources
    case alertChannels

    public var titleCN: String {
        switch self {
        case .dataSources: "数据源"
        case .alertChannels: "报警通道"
        }
    }
}
