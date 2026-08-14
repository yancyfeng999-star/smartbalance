import Foundation

public enum HelpTopicID: String, CaseIterable, Sendable, Equatable {
    case gettingStarted
    case refreshFailed
    case credentials
    case usageHistory
    case diagnostics
    case backupRestore
    case updates
    case notifications
    case safeMode
    case narrowWindow
}

public struct HelpTopic: Equatable, Sendable, Identifiable {
    public var id: HelpTopicID
    public var titleKey: String
    public var bodyKeys: [String]

    public init(id: HelpTopicID, titleKey: String, bodyKeys: [String]) {
        self.id = id
        self.titleKey = titleKey
        self.bodyKeys = bodyKeys
    }
}

public enum HelpCenterCatalog: Sendable {
    public static let forbiddenPhrases = [
        "云端支持",
        "云同步",
        "自动修复",
        "保证成功",
        "cloud support",
        "auto-fix",
        "automatically fix",
        "guaranteed success",
        "guaranteed live",
    ]

    public static let topics: [HelpTopic] = HelpTopicID.allCases.map(topic)

    public static func topic(_ id: HelpTopicID) -> HelpTopic {
        HelpTopic(
            id: id,
            titleKey: "help.topic.\(id.rawValue).title",
            bodyKeys: [
                "help.topic.\(id.rawValue).body1",
                "help.topic.\(id.rawValue).body2",
            ]
        )
    }
}
