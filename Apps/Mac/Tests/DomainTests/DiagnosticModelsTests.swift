import XCTest
@testable import Domain

final class DiagnosticModelsTests: XCTestCase {
    func testKeychainStatusAllowsOnlyAvailabilityEnum() {
        let allowed = Set(DiagnosticKeychainStatus.allCases.map(\.rawValue))
        XCTAssertEqual(allowed, ["available", "unavailable", "unknown"])
        XCTAssertNil(DiagnosticKeychainStatus(rawValue: "com.smartbalance.zhiyu.plain"))
        XCTAssertNil(DiagnosticKeychainStatus(rawValue: "secret-length-32"))
        XCTAssertNil(DiagnosticKeychainStatus(rawValue: "account:smtp-password"))
    }

    func testProviderSummaryCodingKeysAreAllowlisted() throws {
        let summary = DiagnosticProviderSummary(
            kind: ProviderKind.deepseek.rawValue,
            enabled: true,
            hasCredentialRef: true
        )
        let data = try JSONEncoder().encode(summary)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["kind", "enabled", "hasCredentialRef"])
        XCTAssertFalse(object.keys.contains("secretRef"))
        XCTAssertFalse(object.keys.contains("userId"))
        XCTAssertFalse(object.keys.contains("baseURL"))
        XCTAssertFalse(object.keys.contains("displayName"))
    }

    func testProviderSummaryFromAccountOmitsSecretRefAndAuthMaterial() throws {
        let account = BalanceAccount(
            id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
            kind: .kimi,
            displayName: "Should Not Appear",
            userId: "fixture-user-9",
            secretRef: "sk-test-secret-ref-must-not-export",
            enabled: true
        )
        let summary = DiagnosticProviderSummary(account: account)
        XCTAssertEqual(summary.kind, "kimi")
        XCTAssertTrue(summary.enabled)
        XCTAssertTrue(summary.hasCredentialRef)

        let data = try JSONEncoder().encode(summary)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("sk-test-secret-ref-must-not-export"))
        XCTAssertFalse(json.contains("secretRef"))
        XCTAssertFalse(json.contains("Should Not Appear"))
        XCTAssertFalse(json.contains("fixture-user-9"))
    }

    func testUsageSummaryOmitsAccountPayload() throws {
        let accountID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let document = UsageHistoryDocument(
            dailyRecords: [
                UsageDailyRecord(
                    dayKey: "2026-08-01",
                    timeZoneIdentifier: "UTC",
                    accountId: accountID,
                    providerKind: .deepseek,
                    unit: "USD",
                    providerAmount: 12.5,
                    estimatedAmount: 0,
                    sampleCount: 1,
                    hasBoundaryGap: false
                ),
                UsageDailyRecord(
                    dayKey: "2026-08-10",
                    timeZoneIdentifier: "UTC",
                    accountId: accountID,
                    providerKind: .deepseek,
                    unit: "CNY",
                    providerAmount: 3,
                    estimatedAmount: 1,
                    sampleCount: 2,
                    hasBoundaryGap: false
                ),
            ]
        )
        let summary = DiagnosticUsageSummary(document: document, saveErrorClassification: "save")
        XCTAssertEqual(summary.recordCount, 2)
        XCTAssertEqual(summary.earliestDate, "2026-08-01")
        XCTAssertEqual(summary.latestDate, "2026-08-10")
        XCTAssertEqual(summary.unitCategories, ["CNY", "USD"])
        XCTAssertEqual(summary.saveErrorClassification, "save")

        let data = try JSONEncoder().encode(summary)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains(accountID.uuidString))
        XCTAssertFalse(json.contains("12.5"))
        XCTAssertFalse(json.contains("secret"))
    }

    func testReportEncodingUsesOnlyAllowlistedTopLevelKeys() throws {
        let report = makeReport()
        let data = try DiagnosticReport.encode(report)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertTrue(
            Set(object.keys).isSubset(of: DiagnosticReport.allowedTopLevelKeys),
            "unexpected keys: \(Set(object.keys).subtracting(DiagnosticReport.allowedTopLevelKeys))"
        )
        XCTAssertFalse(object.keys.contains("secretRef"))
        XCTAssertFalse(object.keys.contains("secrets"))
        XCTAssertFalse(object.keys.contains("rawResponse"))
        XCTAssertFalse(object.keys.contains("requestURL"))
        XCTAssertEqual(report.keychainStatus, .available)
        XCTAssertTrue(DiagnosticReport.defaultExcludedFields.contains("Bearer"))
        XCTAssertTrue(DiagnosticReport.defaultExcludedFields.contains("Cookie"))
        XCTAssertTrue(DiagnosticReport.defaultExcludedFields.contains("smtpPassword"))
    }

    func testReportDoesNotHaveRawProviderResponseField() {
        let labels = Mirror(reflecting: makeReport()).children.compactMap(\.label)
        XCTAssertFalse(labels.contains("rawResponse"))
        XCTAssertFalse(labels.contains("providerResponse"))
        XCTAssertFalse(labels.contains("responseBody"))
        XCTAssertFalse(labels.contains("requestURL"))
    }

    func testLatestFailedSnapshotOutcomeOverridesOlderSuccess() {
        let names = [
            "settings-20260814-150405-schema-migration.json",
            "settings-20260814-120000-settings-write.json",
        ]
        let ledger = DiagnosticOutcomeLedger.empty.updated(
            .migration,
            result: .failed,
            at: Date(timeIntervalSince1970: 1_787_100_000)
        ).updated(
            .backup,
            result: .failed,
            at: Date(timeIntervalSince1970: 1_787_100_100)
        )
        let outcomes = DiagnosticSnapshotClassifier.classify(filenames: names, ledger: ledger)
        XCTAssertEqual(outcomes.migration, "failed")
        XCTAssertEqual(outcomes.backup, "failed")
        XCTAssertEqual(outcomes.restore, "none")
    }

    func testLaterSuccessfulOutcomeOverridesEarlierFailure() {
        let names = ["settings-20260814-150405-settings-write.json"]
        let ledger = DiagnosticOutcomeLedger(
            migration: DiagnosticOutcomeEntry(result: .failed, at: Date(timeIntervalSince1970: 1)),
            backup: DiagnosticOutcomeEntry(result: .ok, at: Date(timeIntervalSince1970: 2)),
            restore: DiagnosticOutcomeEntry(result: .none)
        )
        let outcomes = DiagnosticSnapshotClassifier.classify(filenames: names, ledger: ledger)
        XCTAssertEqual(outcomes.backup, "ok")
        XCTAssertEqual(outcomes.migration, "failed")
    }

    func testReadableSummaryIncludesProviderUsageAndLastRefresh() {
        let report = makeReport()
        let providers = DiagnosticReadableSummary.providerLines(report.providers)
        XCTAssertEqual(providers, ["deepseek enabled=true hasCredentialRef=true"])
        XCTAssertEqual(
            DiagnosticReadableSummary.usageLine(report.usage),
            "records=2 range=2026-08-01/2026-08-10 units=CNY saveError=none health=available"
        )
        XCTAssertTrue(
            DiagnosticReadableSummary.refreshLine(report.refresh).contains("lastRefreshAt="),
            DiagnosticReadableSummary.refreshLine(report.refresh)
        )
        XCTAssertTrue(DiagnosticReadableSummary.refreshLine(report.refresh).contains("succeeded"))
    }

    func testRecoverableBannersOfferDiagnostics() {
        XCTAssertTrue(
            DiagnosticBannerPolicy.shouldOfferDiagnostics(
                noticeKey: RefreshMessageKey.usageSaveFailed,
                usageDataError: "save",
                usageRecoveryNotice: false
            )
        )
        XCTAssertTrue(
            DiagnosticBannerPolicy.shouldOfferDiagnostics(
                noticeKey: RefreshMessageKey.failed,
                usageDataError: nil,
                usageRecoveryNotice: false
            )
        )
        XCTAssertTrue(
            DiagnosticBannerPolicy.shouldOfferDiagnostics(
                noticeKey: nil,
                usageDataError: nil,
                usageRecoveryNotice: true
            )
        )
        XCTAssertFalse(
            DiagnosticBannerPolicy.shouldOfferDiagnostics(
                noticeKey: nil,
                usageDataError: nil,
                usageRecoveryNotice: false
            )
        )
    }
}

private extension DiagnosticModelsTests {
    func makeReport() -> DiagnosticReport {
        DiagnosticReport(
            generatedAt: Date(timeIntervalSince1970: 1_787_000_000),
            appVersion: "0.3.1",
            build: "82",
            osVersion: "15.6.0",
            architecture: "appleSilicon",
            launchMode: DiagnosticLaunchMode.menuBar.rawValue,
            schemaVersion: 1,
            checks: [
                DiagnosticCheck(id: .appVersion, status: .ok, detailKey: "diagnostics.detail.appVersion.ok"),
            ],
            keychainStatus: .available,
            notificationAuthorization: NotificationAuthorizationState.authorized.rawValue,
            refresh: DiagnosticRefreshSummary(
                state: "succeeded",
                lastRefreshAt: Date(timeIntervalSince1970: 1_787_000_100),
                succeededCount: 1,
                failedCount: 0
            ),
            providers: [
                DiagnosticProviderSummary(kind: "deepseek", enabled: true, hasCredentialRef: true),
            ],
            usage: DiagnosticUsageSummary(
                recordCount: 2,
                earliestDate: "2026-08-01",
                latestDate: "2026-08-10",
                unitCategories: ["CNY"],
                saveErrorClassification: "none"
            ),
            directories: DiagnosticDirectories(
                applicationSupport: DiagnosticDirectoryProbe(writable: true, posixPermissions: "700", fileSizeBytes: 12),
                logs: DiagnosticDirectoryProbe(writable: true, posixPermissions: "755", fileSizeBytes: 40),
                temporary: DiagnosticDirectoryProbe(writable: true, posixPermissions: "700", fileSizeBytes: 0)
            )
        )
    }
}
