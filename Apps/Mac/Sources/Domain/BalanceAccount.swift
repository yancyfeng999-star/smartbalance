import Foundation

/// 用户配置的一个可查询账号。
public struct BalanceAccount: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: ProviderKind
    /// 用户自定义显示名（可空，空则用 kind.displayName）。
    public var displayName: String
    /// API 请求根地址（如 New-API 中转站）；与「官网/后台」无关。
    public var baseURL: String?
    /// 官网 / 控制台链接：点「打开后台」时跳转；用户可改。
    public var consoleURL: String?
    /// 部分平台管理接口需要的用户 ID（如 DMXAPI 的 Dmx-Api-User）；非密钥，可落盘。
    public var userId: String?
    /// 密钥库引用键；真实密钥在本机 Keychain。
    public var secretRef: String
    public var enabled: Bool
    /// 货币金额阈值（低于则报警）；nil 表示用全局默认。
    public var alertThreshold: Double?
    /// 百分比阈值（0–100），适用于 quota 型；nil 用全局。
    public var alertPercentThreshold: Double?

    // MARK: 手录（MiMo / MiniMax 等）

    /// 用户手录的余额金额。
    public var manualAmount: Double?
    /// 手录单位，默认随 kind。
    public var manualUnit: String?
    /// 上次手录时间。
    public var manualUpdatedAt: Date?
    /// 是否每日提醒录入；nil 时对手录平台默认 true。
    public var dailyReminderEnabled: Bool?

    public init(
        id: UUID = UUID(),
        kind: ProviderKind,
        displayName: String = "",
        baseURL: String? = nil,
        consoleURL: String? = nil,
        userId: String? = nil,
        secretRef: String = UUID().uuidString,
        enabled: Bool = true,
        alertThreshold: Double? = nil,
        alertPercentThreshold: Double? = nil,
        manualAmount: Double? = nil,
        manualUnit: String? = nil,
        manualUpdatedAt: Date? = nil,
        dailyReminderEnabled: Bool? = nil
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName.isEmpty ? kind.displayName : displayName
        self.baseURL = baseURL ?? kind.defaultBaseURL
        let trimmedConsole = consoleURL?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.consoleURL = (trimmedConsole?.isEmpty == false) ? trimmedConsole : kind.defaultConsoleURL
        self.userId = userId.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        self.secretRef = secretRef
        self.enabled = enabled
        self.alertThreshold = alertThreshold
        self.alertPercentThreshold = alertPercentThreshold
        self.manualAmount = manualAmount
        self.manualUnit = manualUnit
        self.manualUpdatedAt = manualUpdatedAt
        self.dailyReminderEnabled = dailyReminderEnabled
    }

    public var title: String {
        displayName.isEmpty ? kind.displayName : displayName
    }

    public var resolvedManualUnit: String {
        let u = manualUnit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return u.isEmpty ? kind.defaultManualUnit : u
    }

    /// 是否开启每日提醒（手录平台默认开）。
    public var wantsDailyReminder: Bool {
        if let dailyReminderEnabled { return dailyReminderEnabled }
        return kind.isManualEntry
    }

    /// 「打开后台」最终跳转地址：用户填写的官网优先，否则平台默认，再回退 API baseURL。
    public var resolvedConsoleURL: String? {
        if let c = Self.normalizedURLString(consoleURL) { return c }
        if let d = Self.normalizedURLString(kind.defaultConsoleURL) { return d }
        // New-API 等：未单独填官网时，用 baseURL 打开
        return Self.normalizedURLString(baseURL)
    }

    /// 补全 scheme，保证能用 `URL(string:)` 打开浏览器。
    public static func normalizedURLString(_ raw: String?) -> String? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return nil
        }
        if !s.contains("://") {
            s = "https://\(s)"
        }
        return s
    }
}
