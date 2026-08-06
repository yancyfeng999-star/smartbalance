import Foundation

/// 不支持实时 API 的平台：靠其「固定发件邮箱」来的信确认余额。
public struct PlatformMailSource: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var displayName: String
    public var enabled: Bool
    /// 发件人包含（如 noreply@vendor.com），不区分大小写。
    public var fromContains: String
    /// 主题包含（可选，空则不限制）。
    public var subjectContains: String
    /// 提取金额的正则；需含一个捕获组。空则用内置多模式。
    public var amountRegex: String
    public var unit: String
    public var alertThreshold: Double?
    /// 已处理的 Message-ID，避免重复报警。
    public var lastMessageId: String?
    public var lastParsedAmount: Double?
    public var lastParsedAt: Date?

    public init(
        id: UUID = UUID(),
        displayName: String,
        enabled: Bool = true,
        fromContains: String,
        subjectContains: String = "",
        amountRegex: String = "",
        unit: String = "¥",
        alertThreshold: Double? = nil,
        lastMessageId: String? = nil,
        lastParsedAmount: Double? = nil,
        lastParsedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.enabled = enabled
        self.fromContains = fromContains
        self.subjectContains = subjectContains
        self.amountRegex = amountRegex
        self.unit = unit
        self.alertThreshold = alertThreshold
        self.lastMessageId = lastMessageId
        self.lastParsedAmount = lastParsedAmount
        self.lastParsedAt = lastParsedAt
    }
}

/// 读取平台邮件用的 IMAP 收件箱。
public struct InboundMailboxSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var imapHost: String
    public var imapPort: Int
    public var useTLS: Bool
    public var username: String
    public var passwordRef: String
    public var folder: String
    /// 每次最多扫描最近多少封。
    public var maxMessages: Int

    public init(
        enabled: Bool = false,
        imapHost: String = "",
        imapPort: Int = 993,
        useTLS: Bool = true,
        username: String = "",
        passwordRef: String = "imap-password",
        folder: String = "INBOX",
        maxMessages: Int = 40
    ) {
        self.enabled = enabled
        self.imapHost = imapHost
        self.imapPort = imapPort
        self.useTLS = useTLS
        self.username = username
        self.passwordRef = passwordRef
        self.folder = folder
        self.maxMessages = maxMessages
    }

    public var isConfigured: Bool {
        enabled && !imapHost.isEmpty && !username.isEmpty
    }
}
