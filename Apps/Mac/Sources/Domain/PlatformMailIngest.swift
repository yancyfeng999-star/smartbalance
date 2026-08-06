import Foundation

/// 平台邮件单源摄入结果：快照 + 更新后的源 + 是否应报警。
public struct MailIngestResult: Equatable, Sendable {
    public var snapshot: BalanceSnapshot
    public var updatedSource: PlatformMailSource
    public var shouldAlert: Bool
    /// 平台报警关键词命中时的补充说明（供报警文案）。
    public var alertNote: String?
    /// 当 `shouldAlert` 时，成功投递报警后再写入 `lastMessageId` 用的 Message-ID。
    public var pendingMessageId: String?

    public init(
        snapshot: BalanceSnapshot,
        updatedSource: PlatformMailSource,
        shouldAlert: Bool,
        alertNote: String? = nil,
        pendingMessageId: String? = nil
    ) {
        self.snapshot = snapshot
        self.updatedSource = updatedSource
        self.shouldAlert = shouldAlert
        self.alertNote = alertNote
        self.pendingMessageId = pendingMessageId
    }

    /// 是否应提交 `lastMessageId`：无需报警，或至少一条报警通道成功。
    public static func shouldCommitLastMessageId(
        shouldAlert: Bool,
        notified: Bool,
        emailed: Bool
    ) -> Bool {
        !shouldAlert || notified || emailed
    }
}

/// 纯函数：选信、解析金额、更新 source 字段、判定是否报警。
public enum PlatformMailIngest: Sendable {
    /// 摄入一批 IMAP 邮件，针对单一 `PlatformMailSource` 产出快照与去重后的报警意图。
    /// - Parameters:
    ///   - source: 邮件源（调用方应只传 `enabled` 源）
    ///   - messages: 本次拉取的原始邮件（通常时间升序）
    ///   - thresholds: (金额阈值, 百分比阈值)
    ///   - now: 解析成功时写入 `lastParsedAt` 的时间（可注入便于测试）
    public static func ingest(
        source: PlatformMailSource,
        messages: [FetchedMailMessage],
        thresholds: (amount: Double, percent: Double),
        now: Date = Date()
    ) -> MailIngestResult {
        // 规则 1：未启用源不处理（防御；正常路径由 enabledMailSources 过滤）
        guard source.enabled else {
            return MailIngestResult(
                snapshot: cacheOrUnknownSnapshot(
                    source: source,
                    detail: "已禁用",
                    thresholds: thresholds
                ),
                updatedSource: source,
                shouldAlert: false
            )
        }

        guard let best = newestMatching(messages: messages, source: source) else {
            // 无匹配：展示缓存或 unknown
            return MailIngestResult(
                snapshot: cacheOrUnknownSnapshot(
                    source: source,
                    detail: source.lastParsedAmount != nil
                        ? "暂无新匹配邮件 · 显示上次结果"
                        : "收件箱中未匹配到：发件人含「\(source.fromContains)」",
                    thresholds: thresholds
                ),
                updatedSource: source,
                shouldAlert: false
            )
        }

        let text = best.subject + "\n" + best.body
        let amount = BalanceMailParser.extractAmount(from: text, customRegex: source.amountRegex)
        let platformAlert = BalanceMailParser.looksLikeAlert(subject: best.subject, body: best.body)

        let status: BalanceStatus = {
            if let amount {
                return BalanceSnapshot.resolveStatus(
                    amount: amount,
                    remainingPercent: nil,
                    amountThreshold: thresholds.amount,
                    percentThreshold: thresholds.percent
                )
            }
            return platformAlert ? .warning : .unknown
        }()

        var updated = source
        let isNewMail = source.lastMessageId != best.id
        // 金额缓存始终可写；lastMessageId 仅在无需报警时立即提交。
        // 需报警时由 BalanceService 在至少一条通道成功后再提交，失败则保留旧 ID 以便重试。
        if let amount {
            updated.lastParsedAmount = amount
            updated.lastParsedAt = now
        }

        let snap = BalanceSnapshot(
            accountId: source.id,
            displayName: source.displayName,
            source: .platformEmail,
            amount: amount ?? updated.lastParsedAmount,
            unit: source.unit,
            status: status,
            detail: "来自 \(best.from)",
            fetchedAt: now,
            mailSubject: best.subject
        )

        // 规则 4–5：同 Message-ID 不重复报警；新 ID 且（偏低/危急/耗尽 或 平台报警信）→ 报警
        let should = isNewMail && (statusNeedsAlert(status) || platformAlert)
        let note: String? = platformAlert ? "平台邮件含报警关键词" : nil

        if !should {
            updated.lastMessageId = best.id
        }

        return MailIngestResult(
            snapshot: snap,
            updatedSource: updated,
            shouldAlert: should,
            alertNote: should ? note : nil,
            pendingMessageId: should ? best.id : nil
        )
    }

    /// 规则 6：IMAP 失败时，有缓存金额则卡片展示缓存 + errorMessage。
    public static func snapshotOnIMAPFailure(
        source: PlatformMailSource,
        errorMessage: String
    ) -> BalanceSnapshot {
        BalanceSnapshot(
            accountId: source.id,
            displayName: source.displayName,
            source: .platformEmail,
            amount: source.lastParsedAmount,
            unit: source.unit,
            status: .error,
            detail: source.lastParsedAmount != nil ? "沿用上次解析结果" : "",
            errorMessage: errorMessage
        )
    }

    // MARK: - Selection

    /// 匹配后取时间最新一封；无 date 时取列表末尾（IMAP 通常升序）。
    public static func newestMatching(
        messages: [FetchedMailMessage],
        source: PlatformMailSource
    ) -> FetchedMailMessage? {
        let matched = messages.filter { BalanceMailParser.matches(message: $0, source: source) }
        guard !matched.isEmpty else { return nil }
        if matched.contains(where: { $0.date != nil }) {
            return matched.max(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) })
        }
        return matched.last
    }

    public static func statusNeedsAlert(_ status: BalanceStatus) -> Bool {
        switch status {
        case .warning, .critical, .depleted: true
        default: false
        }
    }

    // MARK: - Private

    private static func cacheOrUnknownSnapshot(
        source: PlatformMailSource,
        detail: String,
        thresholds: (amount: Double, percent: Double)
    ) -> BalanceSnapshot {
        if let amount = source.lastParsedAmount {
            let status = BalanceSnapshot.resolveStatus(
                amount: amount,
                remainingPercent: nil,
                amountThreshold: thresholds.amount,
                percentThreshold: thresholds.percent
            )
            return BalanceSnapshot(
                accountId: source.id,
                displayName: source.displayName,
                source: .platformEmail,
                amount: amount,
                unit: source.unit,
                status: status,
                detail: detail,
                fetchedAt: source.lastParsedAt ?? Date()
            )
        }
        return BalanceSnapshot(
            accountId: source.id,
            displayName: source.displayName,
            source: .platformEmail,
            unit: source.unit,
            status: .unknown,
            detail: detail
        )
    }
}
