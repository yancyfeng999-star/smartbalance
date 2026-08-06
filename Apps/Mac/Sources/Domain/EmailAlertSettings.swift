import Foundation

/// 出站邮件报警 SMTP 配置（密码经 Keychain）。
public struct EmailAlertSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var smtpHost: String
    public var smtpPort: Int
    public var useTLS: Bool
    public var username: String
    public var passwordRef: String
    public var fromAddress: String
    public var toAddresses: [String]
    /// 保留字段：新逻辑以 AlertChannelSettings 为准，写入时同步。
    public var defaultAmountThreshold: Double
    public var defaultPercentThreshold: Double
    public var cooldownSeconds: Int

    public init(
        enabled: Bool = false,
        smtpHost: String = "",
        smtpPort: Int = 465,
        useTLS: Bool = true,
        username: String = "",
        passwordRef: String = "smtp-password",
        fromAddress: String = "",
        toAddresses: [String] = [],
        defaultAmountThreshold: Double = 10,
        defaultPercentThreshold: Double = 20,
        cooldownSeconds: Int = 3600
    ) {
        self.enabled = enabled
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.useTLS = useTLS
        self.username = username
        self.passwordRef = passwordRef
        self.fromAddress = fromAddress
        self.toAddresses = toAddresses
        self.defaultAmountThreshold = defaultAmountThreshold
        self.defaultPercentThreshold = defaultPercentThreshold
        self.cooldownSeconds = cooldownSeconds
    }

    public var isConfigured: Bool {
        !smtpHost.isEmpty
            && !fromAddress.isEmpty
            && !toAddresses.isEmpty
            && toAddresses.contains(where: { $0.contains("@") })
    }
}
