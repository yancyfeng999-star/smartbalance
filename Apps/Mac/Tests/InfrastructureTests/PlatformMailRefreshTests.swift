import XCTest
@testable import Domain

/// 规则 1–6：平台邮件摄入与去重报警（纯函数 `PlatformMailIngest`）。
final class PlatformMailRefreshTests: XCTestCase {
    private let vendor = "noreply@vendor.com"
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    private let thresholds = (amount: 10.0, percent: 20.0)

    private func source(
        enabled: Bool = true,
        lastMessageId: String? = nil,
        lastParsedAmount: Double? = nil,
        lastParsedAt: Date? = nil,
        alertThreshold: Double? = nil
    ) -> PlatformMailSource {
        PlatformMailSource(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            displayName: "Vendor",
            enabled: enabled,
            fromContains: vendor,
            subjectContains: "余额",
            unit: "¥",
            alertThreshold: alertThreshold,
            lastMessageId: lastMessageId,
            lastParsedAmount: lastParsedAmount,
            lastParsedAt: lastParsedAt
        )
    }

    private func msg(
        id: String,
        from: String? = nil,
        subject: String = "余额通知",
        date: Date? = nil,
        body: String
    ) -> FetchedMailMessage {
        FetchedMailMessage(
            id: id,
            from: from ?? "Team <\(vendor)>",
            subject: subject,
            date: date,
            body: body
        )
    }

    // MARK: - Rule 1: only enabled sources

    func testRule1_onlyEnabledMailSources() {
        let enabled = source(enabled: true)
        let disabled = PlatformMailSource(
            displayName: "Off",
            enabled: false,
            fromContains: "other@x.com"
        )
        var settings = AppSettings(mailSources: [enabled, disabled])
        XCTAssertEqual(settings.enabledMailSources.map(\.id), [enabled.id])

        let messages = [msg(id: "m1", body: "余额 5")]
        let off = PlatformMailIngest.ingest(
            source: disabled,
            messages: messages,
            thresholds: thresholds,
            now: fixedNow
        )
        XCTAssertFalse(off.shouldAlert)
        XCTAssertEqual(off.updatedSource.lastMessageId, nil)
        XCTAssertEqual(off.snapshot.detail, "已禁用")
    }

    // MARK: - Rule 2: newest matching mail

    func testRule2_picksNewestByDate() {
        let src = source()
        let older = msg(
            id: "old",
            date: Date(timeIntervalSince1970: 100),
            body: "余额 100"
        )
        let newer = msg(
            id: "new",
            date: Date(timeIntervalSince1970: 200),
            body: "余额 3"
        )
        let unrelated = msg(
            id: "other",
            from: "spam@x.com",
            date: Date(timeIntervalSince1970: 300),
            body: "余额 1"
        )
        let result = PlatformMailIngest.ingest(
            source: src,
            messages: [older, newer, unrelated],
            thresholds: thresholds,
            now: fixedNow
        )
        // amount 3 → critical → shouldAlert; lastMessageId deferred (pending)
        XCTAssertTrue(result.shouldAlert)
        XCTAssertNil(result.updatedSource.lastMessageId)
        XCTAssertEqual(result.pendingMessageId, "new")
        XCTAssertEqual(result.snapshot.amount, 3)
        XCTAssertEqual(result.snapshot.mailSubject, "余额通知")
    }

    func testRule2_withoutDatesUsesLastInList() {
        let src = source()
        let first = msg(id: "a", body: "余额 50")
        let second = msg(id: "b", body: "余额 7")
        let result = PlatformMailIngest.ingest(
            source: src,
            messages: [first, second],
            thresholds: thresholds,
            now: fixedNow
        )
        // amount 7 → warning → shouldAlert; lastMessageId deferred
        XCTAssertTrue(result.shouldAlert)
        XCTAssertNil(result.updatedSource.lastMessageId)
        XCTAssertEqual(result.pendingMessageId, "b")
        XCTAssertEqual(result.snapshot.amount, 7)
    }

    // MARK: - Rule 3: parse updates lastParsed*

    func testRule3_successfulParseUpdatesSourceFields() {
        let src = source()
        let result = PlatformMailIngest.ingest(
            source: src,
            messages: [msg(id: "mid-1", body: "您的账户余额为 ¥42.5")],
            thresholds: thresholds,
            now: fixedNow
        )
        XCTAssertEqual(result.updatedSource.lastParsedAmount, 42.5)
        XCTAssertEqual(result.updatedSource.lastParsedAt, fixedNow)
        XCTAssertEqual(result.updatedSource.lastMessageId, "mid-1")
        XCTAssertEqual(result.snapshot.amount, 42.5)
        XCTAssertEqual(result.snapshot.status, .healthy) // 42.5 > threshold 10
    }

    // MARK: - Rule 4: same messageId no re-alert

    func testRule4_sameMessageIdDoesNotReAlert() {
        let src = source(lastMessageId: "same-id", lastParsedAmount: 2)
        let result = PlatformMailIngest.ingest(
            source: src,
            messages: [msg(id: "same-id", body: "余额 2")],
            thresholds: thresholds,
            now: fixedNow
        )
        // still critical by amount, but same Message-ID → no alert
        XCTAssertEqual(result.snapshot.status, .critical)
        XCTAssertFalse(result.shouldAlert)
        XCTAssertEqual(result.updatedSource.lastMessageId, "same-id")
    }

    // MARK: - Rule 5: new id + (warn/crit/depleted OR looksLikeAlert)

    func testRule5_newIdLowBalanceAlerts() {
        let src = source(lastMessageId: "old-id")
        let result = PlatformMailIngest.ingest(
            source: src,
            messages: [msg(id: "new-id", body: "余额 8")],
            thresholds: thresholds,
            now: fixedNow
        )
        XCTAssertEqual(result.snapshot.status, .warning)
        XCTAssertTrue(result.shouldAlert)
    }

    func testRule5_newIdCriticalAlerts() {
        let src = source()
        let result = PlatformMailIngest.ingest(
            source: src,
            messages: [msg(id: "c1", body: "余额 3")],
            thresholds: thresholds,
            now: fixedNow
        )
        XCTAssertEqual(result.snapshot.status, .critical)
        XCTAssertTrue(result.shouldAlert)
    }

    func testRule5_newIdDepletedAlerts() {
        let src = source()
        let result = PlatformMailIngest.ingest(
            source: src,
            messages: [msg(id: "d1", body: "余额 0")],
            thresholds: thresholds,
            now: fixedNow
        )
        XCTAssertEqual(result.snapshot.status, .depleted)
        XCTAssertTrue(result.shouldAlert)
    }

    func testRule5_newIdLooksLikeAlertEvenWithoutAmount() {
        let src = source()
        let result = PlatformMailIngest.ingest(
            source: src,
            messages: [msg(id: "a1", subject: "余额不足提醒", body: "请尽快充值以免停服")],
            thresholds: thresholds,
            now: fixedNow
        )
        XCTAssertTrue(result.shouldAlert)
        XCTAssertEqual(result.snapshot.status, .warning)
        XCTAssertEqual(result.alertNote, "平台邮件含报警关键词")
        // I2: shouldAlert → do not advance lastMessageId until channel success
        XCTAssertNil(result.updatedSource.lastMessageId)
        XCTAssertEqual(result.pendingMessageId, "a1")
    }

    func testRule5_newIdHealthyWithoutAlertKeywordsNoAlert() {
        let src = source()
        let result = PlatformMailIngest.ingest(
            source: src,
            messages: [msg(id: "h1", body: "余额 99.0")],
            thresholds: thresholds,
            now: fixedNow
        )
        XCTAssertEqual(result.snapshot.status, .healthy)
        XCTAssertFalse(result.shouldAlert)
        XCTAssertNil(result.alertNote)
        // no alert → commit lastMessageId immediately
        XCTAssertEqual(result.updatedSource.lastMessageId, "h1")
        XCTAssertNil(result.pendingMessageId)
    }

    // MARK: - I2: lastMessageId commit policy

    func testI2_shouldAlertKeepsPreviousLastMessageIdAndExposesPending() {
        let src = source(lastMessageId: "old-id")
        let result = PlatformMailIngest.ingest(
            source: src,
            messages: [msg(id: "new-low", body: "余额 2")],
            thresholds: thresholds,
            now: fixedNow
        )
        XCTAssertTrue(result.shouldAlert)
        XCTAssertEqual(result.updatedSource.lastMessageId, "old-id")
        XCTAssertEqual(result.pendingMessageId, "new-low")
        // amount cache still updates
        XCTAssertEqual(result.updatedSource.lastParsedAmount, 2)
    }

    func testI2_shouldCommitLastMessageIdPolicy() {
        XCTAssertTrue(MailIngestResult.shouldCommitLastMessageId(
            shouldAlert: false, notified: false, emailed: false
        ))
        XCTAssertTrue(MailIngestResult.shouldCommitLastMessageId(
            shouldAlert: true, notified: true, emailed: false
        ))
        XCTAssertTrue(MailIngestResult.shouldCommitLastMessageId(
            shouldAlert: true, notified: false, emailed: true
        ))
        XCTAssertTrue(MailIngestResult.shouldCommitLastMessageId(
            shouldAlert: true, notified: true, emailed: true
        ))
        // both channels failed → do not mark seen
        XCTAssertFalse(MailIngestResult.shouldCommitLastMessageId(
            shouldAlert: true, notified: false, emailed: false
        ))
    }

    // MARK: - Rule 6: IMAP failure keeps cache + errorMessage

    func testRule6_imapFailureWithCacheShowsAmountAndError() {
        let src = source(lastParsedAmount: 55.5, lastParsedAt: fixedNow)
        let snap = PlatformMailIngest.snapshotOnIMAPFailure(
            source: src,
            errorMessage: "IMAP 连接超时"
        )
        XCTAssertEqual(snap.amount, 55.5)
        XCTAssertEqual(snap.status, .error)
        XCTAssertEqual(snap.detail, "沿用上次解析结果")
        XCTAssertEqual(snap.errorMessage, "IMAP 连接超时")
        XCTAssertEqual(snap.source, .platformEmail)
    }

    func testRule6_imapFailureWithoutCacheNoAmount() {
        let src = source(lastParsedAmount: nil)
        let snap = PlatformMailIngest.snapshotOnIMAPFailure(
            source: src,
            errorMessage: "network down"
        )
        XCTAssertNil(snap.amount)
        XCTAssertEqual(snap.status, .error)
        XCTAssertEqual(snap.detail, "")
        XCTAssertEqual(snap.errorMessage, "network down")
    }

    // MARK: - No match shows cache

    func testNoMatchShowsCachedAmount() {
        let src = source(lastParsedAmount: 12, lastParsedAt: fixedNow)
        let result = PlatformMailIngest.ingest(
            source: src,
            messages: [msg(id: "x", from: "other@y.com", body: "余额 1")],
            thresholds: thresholds,
            now: fixedNow
        )
        XCTAssertEqual(result.snapshot.amount, 12)
        XCTAssertFalse(result.shouldAlert)
        XCTAssertTrue(result.snapshot.detail.contains("暂无新匹配"))
        XCTAssertEqual(result.updatedSource.lastMessageId, nil)
    }
}
