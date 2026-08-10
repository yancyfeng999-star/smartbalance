# 智余本地用量统计 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在智余中增加完全本地的自然天、自然周、自然月渠道金额统计，并将设置入口移到首页右上角、把原底栏设置按钮替换为用量入口。

**Architecture:** Domain 提供纯 Swift 的采样差额和周期聚合；Infrastructure actor 以事务式原子 JSON 持久化 400 天日账本；AppModel 只在最新成功刷新通过 generation 校验后写入账本，SwiftUI 使用原生 Charts 展示按币种分组的 KPI、趋势和渠道明细。支持累计用量的渠道用 `used` 正差值，余额渠道用余额下降估算，币种永不混算。

**Tech Stack:** Swift 6、SwiftUI、AppKit、Swift Charts、Foundation Codable、Tuist、XCTest、macOS 15+

## Global Constraints

- 只修改 `/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/智余`。
- 应用继续支持 macOS 15+，保持 Swift 6 strict concurrency。
- 菜单栏弹层和置顶窗口继续使用固定 `380 × 580` 壳。
- 不新增第三方依赖、数据库、云同步、权限、网络端点或遥测。
- 不读取、打印、迁移或保存 API Key、Cookie、Access Token、请求头和 Provider 响应正文。
- CNY、USD 和未知单位分别聚合，禁止汇率换算或跨币种总计。
- 首次采样只建立基线；充值、累计值重置、单位/方法变化均不产生消费。
- 只有通过 `refreshGeneration` 校验的最新成功刷新可写入历史；保存失败不能影响余额显示和报警。
- 所有行为改动遵循先失败测试、再最小实现、再完整回归。
- Fixture/单测通过不得表述为真实 Provider 联网通过。
- 设计依据：`docs/superpowers/specs/2026-08-10-usage-statistics-design.md`。

---

## File Map

### Create

- `Apps/Mac/Sources/Domain/UsageModels.swift` — Codable/Sendable 模型、单位归一化和质量类型。
- `Apps/Mac/Sources/Domain/UsageAccumulator.swift` — 纯函数采样差额、基线切换、日记录合并和 400 天清理。
- `Apps/Mac/Sources/Domain/UsageSummaryBuilder.swift` — 天/ISO 周/月区间、历史移动、币种/Provider 聚合。
- `Apps/Mac/Sources/Infrastructure/UsageHistoryStore.swift` — actor、事务式副本、原子 JSON、0600 权限和损坏备份。
- `Apps/Mac/Sources/App/Views/Usage/UsageView.swift` — 页面状态、周期切换、历史导航和空状态。
- `Apps/Mac/Sources/App/Views/Usage/UsageCurrencyCard.swift` — 币种 KPI、天视图对比条、周/月 Charts 柱图。
- `Apps/Mac/Sources/App/Views/Usage/UsageProviderRow.swift` — Provider Logo、金额、账号数、质量标签。
- `Apps/Mac/Tests/DomainTests/UsageAccumulatorTests.swift` — 采样规则测试。
- `Apps/Mac/Tests/DomainTests/UsageSummaryBuilderTests.swift` — 周期和聚合测试。
- `Apps/Mac/Tests/InfrastructureTests/UsageHistoryStoreTests.swift` — 持久化测试。

### Modify

- `Apps/Mac/Sources/Infrastructure/Providers/NewAPIBalanceProvider.swift:89-115` — `used/total` 归一化为 USD。
- `Apps/Mac/Tests/InfrastructureTests/NewAPIProviderTests.swift:44-115` — 更新 USD 断言。
- `Apps/Mac/Tests/InfrastructureTests/{Apinebula,DMXAPI,DeepSeek,Kimi,LaoZhang,MiMo,MiniMax,OpenRouter,ViralTok,Volcengine}ProviderTests.swift` — 明确累计/余额能力契约。
- `Apps/Mac/Sources/App/AppModel.swift:8-31,124-155,280-355` — history 状态、启动加载和刷新后写入。
- `Apps/Mac/Sources/App/Views/MenuRootView.swift:24-241` — `.usage` 壳、齿轮和底栏入口。
- `Apps/Mac/Sources/App/Localization/L10n.swift:24-125` — 10 种语言用量文案。
- `Apps/Mac/Sources/App/Theme.swift:47-136` — 图表选中态 token。
- `PRODUCT.md`、`README.md`、`docs/USER_GUIDE.md`、`PROJECT_STATUS.md` — 能力、限制和状态说明。

---

### Task 1: 全渠道统计字段门禁与 New-API 单位修复

**Files:**
- Modify: `Apps/Mac/Sources/Infrastructure/Providers/NewAPIBalanceProvider.swift`
- Modify: `Apps/Mac/Tests/InfrastructureTests/NewAPIProviderTests.swift`
- Modify: `Apps/Mac/Tests/InfrastructureTests/ApinebulaProviderTests.swift`
- Modify: `Apps/Mac/Tests/InfrastructureTests/DMXAPIProviderTests.swift`
- Modify: `Apps/Mac/Tests/InfrastructureTests/DeepSeekProviderTests.swift`
- Modify: `Apps/Mac/Tests/InfrastructureTests/KimiProviderTests.swift`
- Modify: `Apps/Mac/Tests/InfrastructureTests/LaoZhangProviderTests.swift`
- Modify: `Apps/Mac/Tests/InfrastructureTests/MiMoProviderTests.swift`
- Modify: `Apps/Mac/Tests/InfrastructureTests/MiniMaxProviderTests.swift`
- Modify: `Apps/Mac/Tests/InfrastructureTests/OpenRouterProviderTests.swift`
- Modify: `Apps/Mac/Tests/InfrastructureTests/ViralTokProviderTests.swift`
- Modify: `Apps/Mac/Tests/InfrastructureTests/VolcengineProviderTests.swift`

**Interfaces:**
- Consumes: existing `BalanceProvider.fetchBalance(account:credentials:) -> BalanceSnapshot`.
- Produces: every successful Provider fixture has an explicit contract for normalized `amount/used/total/unit`; New-API emits USD for all three monetary values.

- [ ] **Step 1: Change New-API fixture expectations so the current implementation fails**

```swift
XCTAssertEqual(snapshot.amount, 1.0)
XCTAssertEqual(snapshot.unit, "USD")
XCTAssertEqual(snapshot.used, 0.2)
XCTAssertEqual(snapshot.total, 1.2)
```

Also assert `used == nil` and `total == nil` for the unlimited fixture.

- [ ] **Step 2: Run only New-API tests and confirm the unit mismatch**

Run from `Apps/Mac`:

```bash
tuist generate --no-open
xcodebuild test -workspace SmartBalance.xcworkspace -scheme SmartBalance -destination 'platform=macOS' -only-testing:InfrastructureTests/NewAPIProviderTests
```

Expected: FAIL because the current provider returns `100000` and `600000` while declaring `USD`.

- [ ] **Step 3: Normalize New-API cumulative fields with the same quota scale as amount**

```swift
private static let quotaPerUSD: Double = 500_000

let usedUSD = usedQuota.map { $0 / Self.quotaPerUSD }

return BalanceSnapshot(
    accountId: account.id,
    providerKind: .newapi,
    displayName: account.title,
    source: .api,
    amount: amountUSD,
    unit: "USD",
    used: isUnlimited ? nil : usedUSD,
    total: (!isUnlimited && amountUSD != nil && usedUSD != nil) ? amountUSD! + usedUSD! : nil,
    remainingPercent: remainingPercent,
    status: status,
    detail: detailParts.joined(separator: " · ")
)
```

Use `Self.quotaPerUSD` for `amountUSD` too; do not alter authentication, retry or response parsing.

- [ ] **Step 4: Add explicit cumulative contracts to the five other cumulative Providers**

Add exact fixture assertions:

```swift
// DMXAPI: quota 1_000_000, used 250_000
XCTAssertEqual(snapshot.used!, 0.5, accuracy: 0.0001)
XCTAssertEqual(snapshot.total!, 2.5, accuracy: 0.0001)

// LaoZhang
let expectedUsed = (10_027_091.0 / 500_000.0) * LaoZhangBalanceProvider.cnyPerUSD
XCTAssertEqual(snapshot.used!, expectedUsed, accuracy: 0.01)
XCTAssertEqual(snapshot.total!, snapshot.amount! + expectedUsed, accuracy: 0.01)
```

Retain the existing exact assertions in OpenRouter, ViralTok and apinebula.

- [ ] **Step 5: Add explicit balance-only contracts to all five balance Providers**

In each success fixture for DeepSeek, Kimi, Volcengine, MiMo and MiniMax add:

```swift
XCTAssertNil(snapshot.used)
XCTAssertNil(snapshot.total)
```

- [ ] **Step 6: Run all Infrastructure tests**

```bash
xcodebuild test -workspace SmartBalance.xcworkspace -scheme SmartBalance -destination 'platform=macOS' -only-testing:InfrastructureTests
```

Expected: all Infrastructure tests pass; no Provider request/auth behavior changed.

- [ ] **Step 7: Commit the channel gate**

```bash
git add Apps/Mac/Sources/Infrastructure/Providers/NewAPIBalanceProvider.swift Apps/Mac/Tests/InfrastructureTests
git commit -m "fix: normalize provider usage amounts"
```

---

### Task 2: Domain 用量模型与采样累计器

**Files:**
- Create: `Apps/Mac/Sources/Domain/UsageModels.swift`
- Create: `Apps/Mac/Sources/Domain/UsageAccumulator.swift`
- Create: `Apps/Mac/Tests/DomainTests/UsageAccumulatorTests.swift`

**Interfaces:**
- Consumes: `BalanceSnapshot`, `ProviderKind`, configured account IDs and an injected `Calendar`.
- Produces: `UsageHistoryDocument` and `UsageAccumulator.ingest(snapshots:knownAccountIDs:document:now:calendar:retentionDays:) -> UsageHistoryDocument`.

- [ ] **Step 1: Write failing model/accumulator tests**

Define fixed IDs, an ISO calendar in `Asia/Shanghai`, and snapshots with explicit `fetchedAt`. Add these test methods:

```swift
func testFirstCumulativeSampleCreatesBaselineOnly()
func testCumulativeIncreaseAddsProviderAmount()
func testCumulativeDecreaseResetsWithoutConsumption()
func testFirstBalanceSampleCreatesEstimatedBaselineOnly()
func testBalanceDecreaseAddsEstimatedAmount()
func testBalanceIncreaseResetsWithoutNegativeConsumption()
func testNegativeBalanceStillMeasuresDecrease()
func testErrorSnapshotDoesNotReplaceBaseline()
func testUnitProviderAndMethodChangesOnlyResetBaseline()
func testCrossMidnightDeltaUsesLaterDayAndMarksBoundaryGap()
func testUnknownAccountsAreIgnoredAndDeletedAccountsLoseBaselines()
func testPrunesRecordsOlderThanFourHundredDays()
```

The core positive-delta assertion must be exact:

```swift
XCTAssertEqual(next.dailyRecords.count, 1)
XCTAssertEqual(next.dailyRecords[0].providerAmount, 3.25, accuracy: 0.0001)
XCTAssertEqual(next.dailyRecords[0].estimatedAmount, 0, accuracy: 0.0001)
XCTAssertEqual(next.dailyRecords[0].sampleCount, 1)
XCTAssertEqual(next.dailyRecords[0].dayKey, "2026-08-10")
```

- [ ] **Step 2: Run Domain tests and verify missing symbols fail**

```bash
xcodebuild test -workspace SmartBalance.xcworkspace -scheme SmartBalance -destination 'platform=macOS' -only-testing:DomainTests/UsageAccumulatorTests
```

Expected: compile failure because usage types do not exist.

- [ ] **Step 3: Implement focused Codable/Sendable models**

`UsageModels.swift` must define these exact public types:

```swift
public enum UsagePeriod: String, CaseIterable, Codable, Sendable {
    case day, week, month
}

public enum UsageMeasurementMethod: String, Codable, Sendable {
    case providerCumulative
    case balanceDeltaEstimate
}

public enum UsageQuality: String, Codable, Sendable {
    case provider, estimated, mixed
}

public struct UsageBaseline: Codable, Equatable, Sendable {
    public var accountId: UUID
    public var providerKind: ProviderKind
    public var unit: String
    public var method: UsageMeasurementMethod
    public var value: Double
    public var sampledAt: Date
}

public struct UsageDailyRecord: Codable, Equatable, Sendable, Identifiable {
    public var dayKey: String
    public var timeZoneIdentifier: String
    public var accountId: UUID
    public var providerKind: ProviderKind
    public var unit: String
    public var providerAmount: Double
    public var estimatedAmount: Double
    public var sampleCount: Int
    public var hasBoundaryGap: Bool
    public var id: String { "\(dayKey)|\(accountId.uuidString)|\(providerKind.rawValue)|\(unit)" }
}

public struct UsageHistoryDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public var schemaVersion: Int
    public var baselines: [UsageBaseline]
    public var dailyRecords: [UsageDailyRecord]
    public var updatedAt: Date?
}
```

Give every public model an explicit public initializer. `UsageHistoryDocument.init` defaults to `schemaVersion: currentSchemaVersion`, empty baselines/records and `updatedAt: nil`, so App and Infrastructure can construct an empty document. Add `UsageUnit.normalize(_:)` and `UsageUnit.symbol(for:)`; map `¥/￥/CNY → CNY`, `$/USD → USD`, trim all unknown units without merging them.

- [ ] **Step 4: Implement the pure accumulator**

Use this exact signature:

```swift
public enum UsageAccumulator {
    public static func ingest(
        snapshots: [BalanceSnapshot],
        knownAccountIDs: Set<UUID>,
        document: UsageHistoryDocument,
        now: Date,
        calendar: Calendar,
        retentionDays: Int = 400
    ) -> UsageHistoryDocument
}
```

Measurement selection order is cumulative only when finite `used >= 0` and finite `total > 0` both exist; otherwise use finite `amount`. Ignore error/setup/unknown snapshots. Match a baseline only when account ID, Provider, normalized unit and method all match. Merge positive deltas into one record per day/account/Provider/unit. Prune baselines for deleted accounts and records with a day before `startOfDay(now) - 399 days`.

- [ ] **Step 5: Run the focused and complete Domain suites**

```bash
xcodebuild test -workspace SmartBalance.xcworkspace -scheme SmartBalance -destination 'platform=macOS' -only-testing:DomainTests/UsageAccumulatorTests
xcodebuild test -workspace SmartBalance.xcworkspace -scheme SmartBalance -destination 'platform=macOS' -only-testing:DomainTests
```

Expected: all Domain tests pass.

- [ ] **Step 6: Commit the accumulator**

```bash
git add Apps/Mac/Sources/Domain/UsageModels.swift Apps/Mac/Sources/Domain/UsageAccumulator.swift Apps/Mac/Tests/DomainTests/UsageAccumulatorTests.swift
git commit -m "feat: add local usage accumulator"
```

---

### Task 3: 自然周期与渠道/币种汇总

**Files:**
- Create: `Apps/Mac/Sources/Domain/UsageSummaryBuilder.swift`
- Create: `Apps/Mac/Tests/DomainTests/UsageSummaryBuilderTests.swift`
- Modify: `Apps/Mac/Sources/Domain/UsageModels.swift`

**Interfaces:**
- Consumes: `UsageHistoryDocument`, `UsagePeriod`, anchor date and injected calendar.
- Produces: `UsageDashboardSummary`, period navigation and zero-filled daily chart points.

- [ ] **Step 1: Write failing period and aggregation tests**

Add exact tests for:

```swift
func testDayIntervalUsesLocalMidnight()
func testWeekIntervalStartsMonday()
func testMonthIntervalHandlesLeapFebruary()
func testShiftedAnchorMovesOneNaturalPeriod()
func testFutureAnchorIsClampedToCurrentPeriod()
func testGroupsProviderAccountsWithinCurrency()
func testSeparatesCNYUSDAndUnknownUnits()
func testQualityIsProviderEstimatedOrMixed()
func testWeekAndMonthTotalsEqualDailyPointSum()
func testMissingDaysAreZeroFilledForCharts()
func testHistoricalNavigationStopsAtEarliestDay()
```

Use fixture records where CNY totals `10 + 4`, USD totals `3`, and assert two currency groups rather than `17` as one total.

- [ ] **Step 2: Run focused tests and verify missing builder failure**

```bash
xcodebuild test -workspace SmartBalance.xcworkspace -scheme SmartBalance -destination 'platform=macOS' -only-testing:DomainTests/UsageSummaryBuilderTests
```

Expected: compile failure because summary types and builder are absent.

- [ ] **Step 3: Add summary types**

```swift
public struct UsageDailyPoint: Identifiable, Equatable, Sendable {
    public var dayKey: String
    public var date: Date
    public var amount: Double
    public var includesEstimate: Bool
    public var id: String { dayKey }
}

public struct UsageProviderSummary: Identifiable, Equatable, Sendable {
    public var providerKind: ProviderKind
    public var unit: String
    public var totalAmount: Double
    public var providerAmount: Double
    public var estimatedAmount: Double
    public var accountCount: Int
    public var quality: UsageQuality
    public var id: String { "\(providerKind.rawValue)|\(unit)" }
}

public struct UsageCurrencySummary: Identifiable, Equatable, Sendable {
    public var unit: String
    public var totalAmount: Double
    public var providers: [UsageProviderSummary]
    public var dailyPoints: [UsageDailyPoint]
    public var id: String { unit }
}

public struct UsageDashboardSummary: Equatable, Sendable {
    public var period: UsagePeriod
    public var interval: DateInterval
    public var currencies: [UsageCurrencySummary]
    public var hasAnyBaseline: Bool
    public var earliestDayKey: String?
    public var updatedAt: Date?
}
```

Give each summary type an explicit public initializer because App is a separate target and cannot use Domain's internal memberwise initializer.

- [ ] **Step 4: Implement the builder and navigation**

```swift
public enum UsageSummaryBuilder {
    public static func interval(for period: UsagePeriod, anchor: Date, calendar: Calendar) -> DateInterval
    public static func shiftedAnchor(_ anchor: Date, period: UsagePeriod, offset: Int, calendar: Calendar) -> Date
    public static func build(document: UsageHistoryDocument, period: UsagePeriod, anchor: Date, calendar: Calendar) -> UsageDashboardSummary
    public static func canMoveBackward(summary: UsageDashboardSummary, period: UsagePeriod, anchor: Date, calendar: Calendar) -> Bool
    public static func canMoveForward(period: UsagePeriod, anchor: Date, now: Date, calendar: Calendar) -> Bool
}
```

Use ISO week rules with the passed time zone. Fill every day in week/month chart intervals with zero points. Sort currencies `CNY`, `USD`, then lexical unknown units; sort Provider rows by descending amount then display name.

- [ ] **Step 5: Run Domain suites**

```bash
xcodebuild test -workspace SmartBalance.xcworkspace -scheme SmartBalance -destination 'platform=macOS' -only-testing:DomainTests
```

Expected: all accumulator and summary tests pass.

- [ ] **Step 6: Commit summaries**

```bash
git add Apps/Mac/Sources/Domain/UsageModels.swift Apps/Mac/Sources/Domain/UsageSummaryBuilder.swift Apps/Mac/Tests/DomainTests/UsageSummaryBuilderTests.swift
git commit -m "feat: aggregate daily weekly and monthly usage"
```

---

### Task 4: 事务式本地历史存储

**Files:**
- Create: `Apps/Mac/Sources/Infrastructure/UsageHistoryStore.swift`
- Create: `Apps/Mac/Tests/InfrastructureTests/UsageHistoryStoreTests.swift`

**Interfaces:**
- Consumes: Domain `UsageHistoryDocument` and `UsageAccumulator`.
- Produces: actor API `load()` and throwing `record(...)` with commit-after-save semantics.

- [ ] **Step 1: Write failing store tests**

Use a unique `FileManager.default.temporaryDirectory` child for each test. Add:

```swift
func testMissingFileLoadsEmptyDocument() async
func testRecordRoundTripsDocument() async throws
func testSavedFileUsesOwnerReadWritePermissions() async throws
func testCorruptFileIsBackedUpAndReturnsEmptyDocument() async
func testRecordCallsAreSerialized() async throws
func testRemovedAccountDropsBaselineButKeepsDailyHistory() async throws
func testFailedSaveKeepsLastCommittedInMemoryDocument() async throws
```

Permission assertion:

```swift
let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
let permissions = attributes[.posixPermissions] as? NSNumber
XCTAssertEqual(permissions?.intValue, 0o600)
```

- [ ] **Step 2: Run focused tests and verify missing store failure**

```bash
xcodebuild test -workspace SmartBalance.xcworkspace -scheme SmartBalance -destination 'platform=macOS' -only-testing:InfrastructureTests/UsageHistoryStoreTests
```

Expected: compile failure because `UsageHistoryStore` is absent.

- [ ] **Step 3: Implement actor API and deterministic test injection**

```swift
public actor UsageHistoryStore {
    public static let shared = UsageHistoryStore()

    public nonisolated let fileURL: URL

    public init(
        filename: String = "usage-history.json",
        directory: URL? = nil
    )

    init(
        filename: String,
        directory: URL,
        writer: @escaping @Sendable (Data, URL) throws -> Void
    )

    public func load() -> UsageHistoryDocument

    public func record(
        snapshots: [BalanceSnapshot],
        knownAccountIDs: Set<UUID>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> UsageHistoryDocument

    public func currentDocument() -> UsageHistoryDocument
}
```

The public initializer uses the production atomic writer; the internal initializer is available to `@testable import Infrastructure` for deterministic save failures. The actor must calculate into `next`, encode and write `next`, set `0600`, then assign `cached = next`. If writer throws, `cached` remains the previous committed document. A corrupt source is copied atomically to `usage-history.corrupt-<unix>.json` before returning an empty document.

- [ ] **Step 4: Run focused and full Infrastructure suites**

```bash
xcodebuild test -workspace SmartBalance.xcworkspace -scheme SmartBalance -destination 'platform=macOS' -only-testing:InfrastructureTests/UsageHistoryStoreTests
xcodebuild test -workspace SmartBalance.xcworkspace -scheme SmartBalance -destination 'platform=macOS' -only-testing:InfrastructureTests
```

Expected: all tests pass; no secrets appear in generated fixture files or output.

- [ ] **Step 5: Commit storage**

```bash
git add Apps/Mac/Sources/Infrastructure/UsageHistoryStore.swift Apps/Mac/Tests/InfrastructureTests/UsageHistoryStoreTests.swift
git commit -m "feat: persist usage history locally"
```

---

### Task 5: AppModel 刷新链路接入

**Files:**
- Modify: `Apps/Mac/Sources/App/AppModel.swift`

**Interfaces:**
- Consumes: `UsageHistoryStore.shared`, latest accepted snapshots and all configured account IDs.
- Produces: published `usageHistory`, `usageDataError`, `.usage` destination and `usageSummary(period:anchor:)`.

- [ ] **Step 1: Add AppModel state and startup load**

```swift
@Published private(set) var usageHistory = UsageHistoryDocument()
@Published private(set) var usageDataError: String?

enum Tab: String {
    case home
    case usage
    case settings
}

private let usageStore = UsageHistoryStore.shared
```

At the end of `init`, start a main-actor task that awaits `usageStore.load()` and publishes the result without blocking menu-bar startup.

- [ ] **Step 2: Add a pure summary accessor**

```swift
func usageSummary(period: UsagePeriod, anchor: Date, calendar: Calendar = .current) -> UsageDashboardSummary {
    UsageSummaryBuilder.build(
        document: usageHistory,
        period: period,
        anchor: anchor,
        calendar: calendar
    )
}
```

- [ ] **Step 3: Record only accepted refresh results**

Immediately after `self.snapshots = orderedSnapshots(result.snapshots)` and after the generation guard:

```swift
do {
    let history = try await usageStore.record(
        snapshots: self.snapshots,
        knownAccountIDs: Set(self.settings.accounts.map(\.id)),
        now: Date(),
        calendar: .current
    )
    self.usageHistory = history
    self.usageDataError = nil
} catch {
    self.usageDataError = "用量记录保存失败"
    AppLog.error("Usage history save failed: \(error.localizedDescription)")
}
```

Do not throw out of `refresh()`, alter snapshots, alerts or settings saving when history persistence fails.

- [ ] **Step 4: Compile the app target**

```bash
xcodebuild -workspace SmartBalance.xcworkspace -scheme SmartBalance -configuration Debug -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED with Swift 6 concurrency checks.

- [ ] **Step 5: Commit AppModel integration**

```bash
git add Apps/Mac/Sources/App/AppModel.swift
git commit -m "feat: record usage after balance refresh"
```

---

### Task 6: 本地化和图表主题 token

**Files:**
- Modify: `Apps/Mac/Sources/App/Localization/L10n.swift`
- Modify: `Apps/Mac/Sources/App/Theme.swift`

**Interfaces:**
- Consumes: existing `L10n` ten-language table and `SBTheme`.
- Produces: complete usage copy and one reusable chart selection token for Task 7.

- [ ] **Step 1: Add all localization keys in all ten existing languages**

Add complete rows for:

```text
home.usage
usage.title
usage.day
usage.week
usage.month
usage.previous
usage.next
usage.current_day
usage.current_week
usage.current_month
usage.provider_quality
usage.estimated_quality
usage.mixed_quality
usage.accounts_count
usage.no_accounts
usage.open_settings
usage.baseline_only
usage.no_spend
usage.save_failed
usage.boundary_hint
usage.last_updated
```

Every row must contain `.zhHans`, `.en`, `.ja`, `.ko`, `.ru`, `.ar`, `.fr`, `.de`, `.es`, `.pt`; no key may rely on Chinese fallback.

- [ ] **Step 2: Add one chart selection token**

```swift
static let usageSelection = Color(nsColor: .systemYellow)
```

Do not add Provider-specific random colors.

- [ ] **Step 3: Compile the unchanged UI against the extended tables**

```bash
xcodebuild -workspace SmartBalance.xcworkspace -scheme SmartBalance -configuration Debug -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED; existing home/settings rendering remains unchanged.

- [ ] **Step 4: Commit localization and token changes**

```bash
git add Apps/Mac/Sources/App/Localization/L10n.swift Apps/Mac/Sources/App/Theme.swift
git commit -m "feat: localize usage statistics"
```

---

### Task 7: 用量页面与 Swift Charts

**Files:**
- Create: `Apps/Mac/Sources/App/Views/Usage/UsageView.swift`
- Create: `Apps/Mac/Sources/App/Views/Usage/UsageCurrencyCard.swift`
- Create: `Apps/Mac/Sources/App/Views/Usage/UsageProviderRow.swift`
- Modify: `Apps/Mac/Sources/App/Views/MenuRootView.swift`
- Modify: `Apps/Mac/Sources/App/Localization/L10n.swift`
- Modify: `Apps/Mac/Sources/App/Theme.swift`

**Interfaces:**
- Consumes: `AppModel.usageSummary`, `UsageSummaryBuilder` navigation, `UsageCurrencySummary` and existing `ProviderLogoView`/`SBTheme`.
- Produces: fixed-shell day/week/month UI with historical navigation, currency cards, hover selection and accessibility.

- [ ] **Step 1: Add the settings gear, usage footer button and usage shell**

Place the gear after the pin button:

```swift
Button {
    model.selectedTab = .settings
} label: {
    Image(systemName: "gearshape")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(SBTheme.text)
        .frame(width: 28, height: 26)
}
.buttonStyle(.plain)
.help(l10n.t("settings.title"))
.keyboardShortcut(",")
.accessibilityLabel(l10n.t("settings.title"))
```

Replace the footer settings pill:

```swift
footerPill(title: l10n.t("home.usage"), systemName: "chart.bar.xaxis") {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
        model.selectedTab = .usage
    }
}
.keyboardShortcut("u")
```

Change root selection to an exhaustive switch and add `usageShell` with a back header and `ScrollView { UsageView(model: model) }`. Keep the same outer padding and fixed shell behavior as settings.

- [ ] **Step 2: Implement page state and period controls**

```swift
struct UsageView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var l10n = L10n.shared
    @State private var period: UsagePeriod = .day
    @State private var anchor = Date()

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }

    private var summary: UsageDashboardSummary {
        model.usageSummary(period: period, anchor: anchor, calendar: calendar)
    }
}
```

Use a compact three-button segmented control, reset anchor to today when period changes, and use `canMoveBackward/canMoveForward` to disable arrows.

- [ ] **Step 3: Implement explicit empty states**

Render these mutually exclusive states:

```swift
if model.settings.enabledAccounts.isEmpty {
    // localized no-accounts copy + button sets .settings
} else if !summary.hasAnyBaseline {
    // localized baseline-only copy
} else {
    // currency cards; zero totals remain valid data
}
```

Show `model.usageDataError` as a danger-colored, non-blocking line. Never replace historical cards with a refresh error.

- [ ] **Step 4: Implement Provider rows**

`UsageProviderRow` must show `ProviderLogoView(kind:size: 24)`, `providerKind.displayName`, account count when greater than one, monospaced formatted amount, and one of the three localized quality labels. Add VoiceOver value containing Provider, amount, unit and quality.

- [ ] **Step 5: Implement currency KPI and charts**

In `UsageCurrencyCard`:

```swift
import Charts

Chart(summary.dailyPoints) { point in
    BarMark(
        x: .value("Day", point.date, unit: .day),
        y: .value("Amount", point.amount)
    )
    .foregroundStyle(selectedDayKey == point.dayKey ? SBTheme.usageSelection : SBTheme.accent)
}
```

For `.day`, omit the date chart and render Provider rows with a five-point-high relative bar using the maximum Provider amount in that currency. For `.week` and `.month`, render zero-filled daily bars, sparse x-axis labels and a mouse overlay/selection that shows localized date, amount and estimate status. Hide the legend and set an accessibility summary.

- [ ] **Step 6: Build and manually exercise all states with deterministic debug data where necessary**

```bash
xcodebuild -workspace SmartBalance.xcworkspace -scheme SmartBalance -configuration Debug -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED. Use only in-memory debug fixtures or test-created temporary stores for empty/baseline/zero/mixed states; never write fake usage into the user's real Application Support file.

- [ ] **Step 7: Commit the complete compiling UI slice**

```bash
git add Apps/Mac/Sources/App/Views/MenuRootView.swift Apps/Mac/Sources/App/Views/Usage Apps/Mac/Sources/App/Localization/L10n.swift Apps/Mac/Sources/App/Theme.swift
git commit -m "feat: add daily weekly and monthly usage UI"
```

---

### Task 8: 文档、完整验证、运行态复核与发布

**Files:**
- Modify: `PRODUCT.md`
- Modify: `README.md`
- Modify: `docs/USER_GUIDE.md`
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- Consumes: completed feature and project release scripts.
- Produces: user documentation, complete local evidence and—only after all gates pass—the normal SmartBalance Release.

- [ ] **Step 1: Document user-visible behavior and accuracy limits**

Document exactly:

- natural day/week/month, historical navigation and 400-day retention;
- interface statistics versus balance estimates;
- first sample has no historical backfill;
- recharge/reset and app-offline cross-day limitations;
- CNY/USD separation;
- local file path and no secret content.

- [ ] **Step 2: Run formatting/static checks**

```bash
git diff --check
rg -n -i $'\u5f85\u5b9a|\u7a0d\u540e\u5b9e\u73b0|\u4e34\u65f6\u5b9e\u73b0' Apps/Mac/Sources Apps/Mac/Tests PRODUCT.md README.md docs/USER_GUIDE.md PROJECT_STATUS.md
```

Expected: `git diff --check` has no output; content-completeness scan has no new feature gaps.

- [ ] **Step 3: Run the complete test suite**

```bash
cd Apps/Mac
./scripts/run-tests.sh
```

Expected: TEST SUCCEEDED for DomainTests, InfrastructureTests and AppTests with zero failures.

- [ ] **Step 4: Build Debug and Release**

```bash
xcodebuild -workspace SmartBalance.xcworkspace -scheme SmartBalance -configuration Debug -destination 'platform=macOS' build
xcodebuild -workspace SmartBalance.xcworkspace -scheme SmartBalance -configuration Release -destination 'platform=macOS' build
```

Expected: both builds succeed.

- [ ] **Step 5: Runtime-verify the real app without reading secrets**

Verify and capture evidence for:

1. menu popover and pinned window both remain `380 × 580`;
2. gear opens settings, footer usage opens usage, back returns home;
3. day/week/month and previous/next periods work;
4. CNY/USD cards are separate;
5. empty, baseline-only, zero, mixed and save-error states remain legible;
6. light/dark, Chinese/English/Arabic RTL, scrolling and VoiceOver labels;
7. any configured real Provider refreshes through the normal app path without exposing secrets.

Report every unconfigured Provider as real-network unverified.

- [ ] **Step 6: Review the full diff and commit documentation**

```bash
git diff --check
git status --short
git diff --stat
git add PRODUCT.md README.md docs/USER_GUIDE.md PROJECT_STATUS.md
git commit -m "docs: document local usage statistics"
```

- [ ] **Step 7: Confirm clean feature state before release**

```bash
git status --short
git log --oneline --decorate -10
```

Expected: no uncommitted feature files and all task commits are present.

- [ ] **Step 8: Run the project release entrypoint**

From `Apps/Mac`:

```bash
NOTES="新增按天、周、月统计各渠道本地用量" ./scripts/release.sh
```

Expected: patch version/build bump, DMG/PKG/SHA256 assets, `main` push, tag and GitHub Release all succeed. Record the new version and Release URL separately from local tests and user installation.

- [ ] **Step 9: Verify remote assets and updater boundary**

Use the Release page/API to verify tag and assets. If an isolated old app is available, test check → download → open installer → restart → version. Otherwise report `update_verified` as unverified. Never claim `user_installed` until the user confirms installation.

---

## Final Evidence Checklist

- [ ] All 11 Provider fixture contracts pass.
- [ ] Domain accumulator and natural-period tests pass.
- [ ] Transactional JSON store tests pass.
- [ ] Complete test suite passes with exact count recorded.
- [ ] Debug and Release builds pass.
- [ ] Menu popover and pinned window receive runtime UI inspection.
- [ ] No secrets or real usage payloads appear in git or logs.
- [ ] Worktree is clean before release.
- [ ] Remote Release evidence is separate from updater and user-install evidence.
