import Foundation

public struct AlertEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var accountId: UUID
    public var title: String
    public var message: String
    public var createdAt: Date
    public var emailed: Bool
    public var notified: Bool
    public var source: DataSourceKind

    public init(
        id: UUID = UUID(),
        accountId: UUID,
        title: String,
        message: String,
        createdAt: Date = Date(),
        emailed: Bool = false,
        notified: Bool = false,
        source: DataSourceKind = .api
    ) {
        self.id = id
        self.accountId = accountId
        self.title = title
        self.message = message
        self.createdAt = createdAt
        self.emailed = emailed
        self.notified = notified
        self.source = source
    }
}

/// 从邮箱拉到的一封原始信（供解析）。
public struct FetchedMailMessage: Identifiable, Sendable, Equatable {
    public var id: String
    public var from: String
    public var subject: String
    public var date: Date?
    public var body: String

    public init(id: String, from: String, subject: String, date: Date? = nil, body: String) {
        self.id = id
        self.from = from
        self.subject = subject
        self.date = date
        self.body = body
    }
}
