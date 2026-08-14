import Foundation

/// 出站邮件报警 SMTP 配置（仅发出报警信；密码存本机 Keychain）。
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
    /// 未识别的邮件设置字段。
    public var extensions: [String: JSONValue]

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
        cooldownSeconds: Int = 3600,
        extensions: [String: JSONValue] = [:]
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
        self.extensions = extensions
    }

    public static func makeNewPasswordRef() -> String {
        "smtp-\(UUID().uuidString.lowercased())"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        smtpHost = try c.decodeIfPresent(String.self, forKey: .smtpHost) ?? ""
        smtpPort = try c.decodeIfPresent(Int.self, forKey: .smtpPort) ?? 465
        useTLS = try c.decodeIfPresent(Bool.self, forKey: .useTLS) ?? true
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        passwordRef = try c.decodeIfPresent(String.self, forKey: .passwordRef) ?? "smtp-password"
        fromAddress = try c.decodeIfPresent(String.self, forKey: .fromAddress) ?? ""
        toAddresses = try c.decodeIfPresent([String].self, forKey: .toAddresses) ?? []
        defaultAmountThreshold = try c.decodeIfPresent(Double.self, forKey: .defaultAmountThreshold) ?? 10
        defaultPercentThreshold = try c.decodeIfPresent(Double.self, forKey: .defaultPercentThreshold) ?? 20
        cooldownSeconds = try c.decodeIfPresent(Int.self, forKey: .cooldownSeconds) ?? 3600
        let stored = try c.decodeIfPresent([String: JSONValue].self, forKey: .extensions) ?? [:]
        extensions = try UnknownFields.collect(from: decoder, known: CodingKeys.self, existing: stored)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(smtpHost, forKey: .smtpHost)
        try c.encode(smtpPort, forKey: .smtpPort)
        try c.encode(useTLS, forKey: .useTLS)
        try c.encode(username, forKey: .username)
        try c.encode(passwordRef, forKey: .passwordRef)
        try c.encode(fromAddress, forKey: .fromAddress)
        try c.encode(toAddresses, forKey: .toAddresses)
        try c.encode(defaultAmountThreshold, forKey: .defaultAmountThreshold)
        try c.encode(defaultPercentThreshold, forKey: .defaultPercentThreshold)
        try c.encode(cooldownSeconds, forKey: .cooldownSeconds)
        if !extensions.isEmpty {
            try c.encode(extensions, forKey: .extensions)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, smtpHost, smtpPort, useTLS, username, passwordRef
        case fromAddress, toAddresses
        case defaultAmountThreshold, defaultPercentThreshold, cooldownSeconds
        case extensions
    }

    public var isConfigured: Bool {
        !smtpHost.isEmpty
            && !fromAddress.isEmpty
            && !toAddresses.isEmpty
            && toAddresses.contains(where: { $0.contains("@") })
    }
}
