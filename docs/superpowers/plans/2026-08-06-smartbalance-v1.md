# 智余 · SmartBalance V1 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将已有 Mac 菜单栏骨架打磨成可日常使用的 V1：API 直查 + 平台邮件入站 + Mac 通知 + 邮件报警，本机密钥、可测、可分发。

**Architecture:** 三层（Domain / Infrastructure / App）。数据源统一产出 `BalanceSnapshot`；`BalanceService` 编排刷新与报警；密钥仅 Keychain；设置 JSON 落盘。UI 对齐智额深色卡片。

**Tech Stack:** Swift 6 · SwiftUI MenuBarExtra · Tuist · macOS 15+ · Network.framework（IMAP/SMTP）· UserNotifications · XCTest

**Spec:** [`PRODUCT.md`](../../../PRODUCT.md) · 竞品参考 [`RESEARCH.md`](../../../RESEARCH.md)

**工程根目录:**  
`/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/API余额查询/Apps/Mac`

## Global Constraints

- 产品名固定：**智余 / SmartBalance**；Bundle ID：`com.smartbalance.app`
- 平台仅 **macOS 15.0+**；菜单栏应用（`LSUIElement=YES`）
- 密钥与 SMTP/IMAP 密码 **只进 Keychain**，禁止写入 `settings.json` 或日志
- 两种数据源：`api` · `platformEmail`；两种报警：`macNotification` · `outboundEmail`
- 视觉参考智额：深色底 `#0f1115` 系、状态色绿/橙/红、卡片圆角 14
- 默认语言简体中文
- 不建云账号、不上传用量与密钥
- SMTP/IMAP 优先 **465/993 隐式 TLS**；不依赖第三方邮件 SDK
- 每个 Task 结束后：`xcodebuild … build` 必须通过；有单测的 Task 必须单测通过
- 提交信息用中文或英文均可，前缀 `feat:` / `fix:` / `test:` / `docs:`

---

## 现状快照（已完成，勿重复造轮子）

| 区域 | 路径 | 状态 |
|------|------|------|
| Tuist 工程 | `Project.swift` · `Tuist/` | ✅ 可 generate + build |
| Domain 模型 | `Sources/Domain/*` | ✅ 骨架齐 |
| DeepSeek / New-API | `Sources/Infrastructure/Providers/*` | ✅ 基础实现 |
| IMAP / SMTP / 通知 | `IMAPClient` · `SMTPClient` · `MacNotificationService` | ⚠️ 可用但需加固 |
| BalanceService 编排 | `BalanceService.swift` | ⚠️ 主路径在，缺边界与假数据测试 |
| UI | `HomeView` · `SettingsView` · 卡片 | ⚠️ 功能在，设置过长需拆分 |
| 单测 | `Tests/DomainTests/*` | ⚠️ 少；scheme 未挂 test action |
| 图标 / 分发 | AppIcon 空 · 无 dmg 脚本 | ❌ |

---

## 文件结构（目标）

```text
Apps/Mac/
├── Project.swift                          # Tuist：补 test scheme、通知权限
├── Sources/
│   ├── Domain/                            # 纯模型 + 解析（无网络）
│   │   ├── BalanceMailParser.swift        # 金额/报警词
│   │   ├── BalanceSnapshot.swift
│   │   ├── AppSettings.swift
│   │   └── ...
│   ├── Infrastructure/
│   │   ├── BalanceService.swift           # 编排唯一入口
│   │   ├── IMAPClient.swift               # 加固 + 可注入连接
│   │   ├── SMTPClient.swift
│   │   ├── MacNotificationService.swift
│   │   ├── KeychainStore.swift
│   │   ├── SettingsStore.swift
│   │   └── Providers/
│   │       ├── DeepSeekBalanceProvider.swift
│   │       ├── NewAPIBalanceProvider.swift
│   │       ├── OpenRouterBalanceProvider.swift   # Task 新增
│   │       └── ProviderRegistry.swift
│   └── App/
│       ├── AppModel.swift
│       ├── SmartBalanceApp.swift
│       ├── Theme.swift
│       └── Views/
│           ├── MenuRootView.swift
│           ├── HomeView.swift
│           ├── BalanceCardView.swift
│           ├── Settings/
│           │   ├── SettingsRootView.swift
│           │   ├── DataSourceSettingsSection.swift
│           │   ├── APIAccountsSection.swift
│           │   ├── PlatformMailSection.swift
│           │   ├── IMAPSection.swift
│           │   ├── AlertChannelsSection.swift
│           │   └── SMTPSection.swift
│           └── PasteMailParseSheet.swift   # 粘贴试解析
├── Tests/
│   ├── DomainTests/
│   └── InfrastructureTests/
├── scripts/
│   ├── build-test-app.sh
│   └── package-release.sh
└── README.md
```

---

## 阶段总览

| 阶段 | Task | 交付 |
|------|------|------|
| A 质量底座 | 1–2 | 单测 scheme、解析/状态纯函数稳 |
| B 数据源 API | 3–5 | Provider 契约 + DeepSeek/New-API 加固 + OpenRouter |
| C 平台邮件 | 6–8 | IMAP 加固、规则 UI、粘贴试解析 |
| D 双通道报警 | 9–10 | 通知权限与冷却、SMTP 发出可靠 |
| E 体验与设置 | 11–12 | 设置拆分、空态/错误态、首页信息密度 |
| F 发布 | 13–14 | 图标、本地安装脚本、PRODUCT 勾选成功标准 |

---

### Task 1: 单测基础设施与 Domain 状态机

**Files:**
- Modify: `Project.swift`（确保 DomainTests / InfrastructureTests 挂在 scheme）
- Modify: `Tests/DomainTests/BalanceSnapshotTests.swift`
- Create: `Tests/DomainTests/AlertThresholdTests.swift`
- Create: `scripts/run-tests.sh`

**Interfaces:**
- Consumes: `BalanceSnapshot.resolveStatus(amount:remainingPercent:amountThreshold:percentThreshold:) -> BalanceStatus`
- Produces: 可重复执行的测试脚本；阈值表锁定

- [ ] **Step 1: 写阈值表单测（先失败或先绿均可，以锁定行为）**

```swift
// Tests/DomainTests/AlertThresholdTests.swift
import XCTest
@testable import Domain

final class AlertThresholdTests: XCTestCase {
    func testAmountMatrix() {
        let cases: [(Double, BalanceStatus)] = [
            (100, .healthy),
            (10, .warning),   // == threshold → warning
            (5, .critical),   // <= threshold*0.5
            (0, .depleted),
        ]
        for (amount, expected) in cases {
            let s = BalanceSnapshot.resolveStatus(
                amount: amount, remainingPercent: nil,
                amountThreshold: 10, percentThreshold: 20
            )
            XCTAssertEqual(s, expected, "amount \(amount)")
        }
    }

    func testPercentMatrix() {
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 50, amountThreshold: 10, percentThreshold: 20),
            .healthy
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 20, amountThreshold: 10, percentThreshold: 20),
            .warning
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 10, amountThreshold: 10, percentThreshold: 20),
            .critical
        )
        XCTAssertEqual(
            BalanceSnapshot.resolveStatus(amount: nil, remainingPercent: 0, amountThreshold: 10, percentThreshold: 20),
            .depleted
        )
    }
}
```

- [ ] **Step 2: 若 `== threshold` 与实现不一致，改 `resolveStatus` 使测试通过（以测试为真源）**

规则锁定：
- `amount <= 0` → depleted  
- `amount <= threshold * 0.5` → critical  
- `amount <= threshold` → warning  
- 否则 healthy  
- percent 同理  

- [ ] **Step 3: 配置可测 scheme**

在 `Project.swift` 的 SmartBalance target 旁确认 tests 依赖正确。添加：

```bash
# scripts/run-tests.sh
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tuist generate --no-open
xcodebuild test \
  -workspace SmartBalance.xcworkspace \
  -scheme SmartBalance \
  -destination 'platform=macOS' \
  -only-testing:DomainTests \
  -only-testing:InfrastructureTests
```

若 scheme 无 test action：用 Tuist `schemes:` 显式声明，或 `xcodebuild -list` 后对 `DomainTests` 单独 test。

- [ ] **Step 4: 跑测**

```bash
chmod +x scripts/run-tests.sh
./scripts/run-tests.sh
```

Expected: DomainTests PASS

- [ ] **Step 5: Commit**

```bash
git add Apps/Mac/Tests Apps/Mac/scripts Apps/Mac/Project.swift Apps/Mac/Sources/Domain
git commit -m "test: lock balance status thresholds and test runner"
```

---

### Task 2: 邮件金额解析器完备化

**Files:**
- Modify: `Sources/Domain/BalanceMailParser.swift`
- Modify: `Tests/DomainTests/BalanceMailParserTests.swift`

**Interfaces:**
- Consumes: `FetchedMailMessage`, `PlatformMailSource`
- Produces:
  - `BalanceMailParser.extractAmount(from:customRegex:) -> Double?`
  - `BalanceMailParser.looksLikeAlert(subject:body:) -> Bool`
  - `BalanceMailParser.matches(message:source:) -> Bool`

- [ ] **Step 1: 扩展失败用例（真邮件风格）**

```swift
func testMultilineChineseVendorMail() {
    let body = """
    尊敬的用户：
    您的 Token 套餐剩余额度：￥36.80
    请及时充值以免影响调用。
    """
    XCTAssertEqual(BalanceMailParser.extractAmount(from: body, customRegex: nil), 36.80)
}

func testHTMLStrippedStillParses() {
    let body = "<html><body><p>balance: <b>$12.3</b></p></body></html>"
    // 实现侧可先 strip tags 再匹配
    XCTAssertEqual(BalanceMailParser.extractAmount(from: body, customRegex: nil), 12.3)
}

func testThousandsSeparator() {
    let body = "余额：1,234.56 元"
    XCTAssertEqual(BalanceMailParser.extractAmount(from: body, customRegex: nil), 1234.56)
}
```

- [ ] **Step 2: 实现最小增强**

在 `BalanceMailParser` 内：
1. `stripHTML(_:)` 去掉 `<…>`  
2. 金额捕获后 `replacingOccurrences(of: ",", with: "")`  
3. 增加模式：`剩余额度[：:]\s*￥?([0-9,…]+)`  

- [ ] **Step 3: 跑测通过**

```bash
./scripts/run-tests.sh
```

- [ ] **Step 4: Commit**

```bash
git commit -am "feat: harden mail balance parser for HTML and thousands"
```

---

### Task 3: Provider 契约与 URLSession 可注入

**Files:**
- Modify: `Sources/Domain/BalanceProvider.swift`
- Create: `Sources/Infrastructure/HTTPClient.swift`
- Modify: 所有 Provider 使用 `HTTPClient`
- Create: `Tests/InfrastructureTests/HTTPClientMock.swift`（或同文件 Mock）
- Create: `Tests/InfrastructureTests/DeepSeekProviderTests.swift`

**Interfaces:**
- Produces:

```swift
public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPClient: HTTPClient {
    public init(session: URLSession = .shared)
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

// Provider 构造：
public struct DeepSeekBalanceProvider: BalanceProvider {
    public init(http: any HTTPClient = URLSessionHTTPClient())
}
```

- [ ] **Step 1: 写 DeepSeek 解码单测（Mock HTTP 返回固定 JSON）**

```swift
// fixture
let json = """
{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"18.5","granted_balance":"0","topped_up_balance":"18.5"}]}
"""
// mock returns 200 + json
// assert snapshot.amount == 18.5, unit == "¥", source == .api
```

- [ ] **Step 2: 实现 `HTTPClient` + 改造 `DeepSeekBalanceProvider` / `NewAPIBalanceProvider`**

- [ ] **Step 3: 错误路径单测**

- 401 → `BalanceProviderError.httpStatus`  
- 空 key → `missingCredential`  
- `is_available: false` → status error  

- [ ] **Step 4: 跑测 + build**

```bash
./scripts/run-tests.sh
xcodebuild -workspace SmartBalance.xcworkspace -scheme SmartBalance -destination 'platform=macOS' build
```

- [ ] **Step 5: Commit**

```bash
git commit -am "feat: inject HTTPClient for provider unit tests"
```

---

### Task 4: New-API 响应兼容矩阵

**Files:**
- Modify: `Sources/Infrastructure/Providers/NewAPIBalanceProvider.swift`
- Create: `Tests/InfrastructureTests/NewAPIProviderTests.swift`

**Interfaces:**
- 兼容字段（按优先级）：
  - `data.quota` / `data.used_quota` / `data.unlimited_quota`
  - `data.username` / `display_name`
  - 金额展示：`quota / 500_000` → USD（与 all-api-hub 常见换算一致；在 detail 中同时显示原始点数）
- Authorization：先 `Bearer <token>`，401/403 再裸 token

- [ ] **Step 1: Fixture 三份 JSON 单测**

1. 标准 New-API `{"data":{"quota":500000,"used_quota":100000,"username":"u1"}}` → amount ≈ 1.0 USD  
2. 无限额度 `unlimited_quota: true` → status healthy，detail 含「无限」  
3. 顶层无 `data` 包装的变体  

- [ ] **Step 2: 实现到测试绿**

- [ ] **Step 3: Commit**

```bash
git commit -am "feat: New-API balance response compatibility matrix"
```

---

### Task 5: 新增 OpenRouter Provider（第三个 API 源）

**Files:**
- Modify: `Sources/Domain/ProviderKind.swift`（加 `openrouter`）
- Create: `Sources/Infrastructure/Providers/OpenRouterBalanceProvider.swift`
- Modify: `ProviderRegistry.swift`
- Modify: 设置页 Picker（Task 11 若未拆分则此处改 `SettingsView`）
- Create: `Tests/InfrastructureTests/OpenRouterProviderTests.swift`

**Interfaces:**
- `GET https://openrouter.ai/api/v1/credits`  
- Header: `Authorization: Bearer <key>`  
- 响应常见：`{ "data": { "total_credits": number, "total_usage": number } }`  
- `amount = total_credits - total_usage`（若字段为剩余则直接用文档实际字段；以官方文档为准，单测用录制 fixture）

- [ ] **Step 1: 查官方 credits 字段并写 fixture 测试**

- [ ] **Step 2: 实现 Provider + registry + UI 枚举显示名「OpenRouter」**

- [ ] **Step 3: build + test**

- [ ] **Step 4: Commit**

```bash
git commit -am "feat: add OpenRouter credits provider"
```

---

### Task 6: IMAP 客户端加固与可测解析

**Files:**
- Modify: `Sources/Infrastructure/IMAPClient.swift`
- Create: `Sources/Infrastructure/IMAPFetchParser.swift`（纯函数解析 FETCH 文本）
- Create: `Tests/InfrastructureTests/IMAPFetchParserTests.swift`

**Interfaces:**
- Produces:

```swift
enum IMAPFetchParser {
    static func parseFetchResponse(_ blob: String) -> [FetchedMailMessage]
    static func parseExists(from selectOrUntagged: String) -> Int?
}
```

- [ ] **Step 1: 用录制的 IMAP FETCH 样本文本写解析测试**

样本需覆盖：
- `BODY[TEXT] {n}` 字面量  
- `Message-ID: <abc@x>`  
- 多封连续 FETCH  
- UTF-8 Base64 Subject（`=?UTF-8?B?...?=`）  

- [ ] **Step 2: 从 `IMAPClient` 抽出 parser，客户端只负责网络会话**

- [ ] **Step 3: 错误映射文案**

| 情况 | 用户可见 |
|------|----------|
| 登录失败 | 「IMAP 登录失败，请检查邮箱与授权码」 |
| 超时 | 「IMAP 连接超时」 |
| 文件夹不存在 | 「文件夹不存在：INBOX」 |

- [ ] **Step 4: 测试通过 + Commit**

```bash
git commit -am "feat: extract testable IMAP FETCH parser"
```

---

### Task 7: 平台邮件刷新逻辑与去重报警

**Files:**
- Modify: `Sources/Infrastructure/BalanceService.swift`（`refreshPlatformMail`）
- Create: `Tests/InfrastructureTests/PlatformMailRefreshTests.swift`（对 service 用 mock IMAP 若难测则测纯函数编排）

**Interfaces:**
- 规则（写进测试）：
  1. 仅 `enabled` 的 `PlatformMailSource`  
  2. `matches(from/subject)` 后取**时间最新**一封  
  3. 解析金额成功 → 更新 `lastParsedAmount` / `lastParsedAt` / `lastMessageId`  
  4. `lastMessageId` 相同 → **不重复报警**  
  5. 新 Message-ID 且（status 为 warning/critical/depleted **或** `looksLikeAlert`）→ 走双通道报警  
  6. IMAP 失败但有缓存金额 → 卡片展示缓存 + `errorMessage` 说明网络失败  

- [ ] **Step 1: 把「选信 + 更新 source + 是否报警」抽成 Domain 或 Infrastructure 纯函数便于测**

```swift
struct MailIngestResult: Equatable {
    var snapshot: BalanceSnapshot
    var updatedSource: PlatformMailSource
    var shouldAlert: Bool
}

enum PlatformMailIngest {
    static func ingest(
        source: PlatformMailSource,
        messages: [FetchedMailMessage],
        thresholds: (amount: Double, percent: Double)
    ) -> MailIngestResult
}
```

- [ ] **Step 2: 单测覆盖 1–6**

- [ ] **Step 3: `BalanceService.refreshPlatformMail` 改为调用 `PlatformMailIngest`**

- [ ] **Step 4: Commit**

```bash
git commit -am "feat: deterministic platform-mail ingest and alert dedupe"
```

---

### Task 8: 粘贴邮件试解析 UI

**Files:**
- Create: `Sources/App/Views/PasteMailParseSheet.swift`
- Modify: 平台邮件设置区增加「试解析」按钮
- Uses: `BalanceService.parsePastedMail(source:subject:body:settings:)`

**Interfaces:**
- Sheet 输入：主题、正文  
- 输出：解析金额、状态、失败提示  
- 可选「写入为该源的上次金额」（更新 `lastParsedAmount` 并 persist）

- [ ] **Step 1: 实现 Sheet UI（深色主题组件复用 `SBTheme` / `SBButtonStyle`）**

- [ ] **Step 2: 从设置中每个邮件源行进入试解析**

- [ ] **Step 3: 手动验收清单**

1. 粘贴含「余额：¥12」正文 → 显示 ¥12.00  
2. 无数字 → 提示调整正则  
3. 写入缓存后首页刷新可见  

- [ ] **Step 4: Commit**

```bash
git commit -am "feat: paste-mail parse sheet for platform sources"
```

---

### Task 9: Mac 通知权限与通道可靠性

**Files:**
- Modify: `Sources/Infrastructure/MacNotificationService.swift`
- Modify: `Sources/App/SmartBalanceApp.swift` / `AppModel.swift`
- Modify: `Info.plist`（已有 usage 描述则核对）

**Interfaces:**
- Produces:

```swift
public final class MacNotificationService: Sendable {
    @MainActor public func requestAuthorizationIfNeeded() async -> Bool
    public func authorizationStatus() async -> UNAuthorizationStatus
    public func post(title:String, body:String, id:String) async
}
```

- [ ] **Step 1: 启动时请求权限；设置页显示当前状态文案**

- 未决定：`系统未授权通知 · 点测试可再次请求`  
- 已授权：`通知已开启`  
- 已拒绝：`请在 系统设置 → 通知 → 智余 中打开`  

- [ ] **Step 2: 报警时 `id` 使用稳定 key（`api-{uuid}` / `mail-{uuid}`），避免通知中心刷屏合并异常**

- [ ] **Step 3: 测试按钮必达（哪怕余额正常）**

- [ ] **Step 4: 手动验收 + Commit**

```bash
git commit -am "feat: mac notification permission UX and stable ids"
```

---

### Task 10: SMTP 发出加固与失败可见

**Files:**
- Modify: `Sources/Infrastructure/SMTPClient.swift`
- Modify: `BalanceService.dispatchAlerts`
- Create: `Tests/InfrastructureTests/SMTPProtocolFormattingTests.swift`（主题 RFC2047、DATA 终结符）

**Interfaces:**
- 约束：
  - 端口 **465 + useTLS** 为推荐路径（隐式 TLS）  
  - 587 STARTTLS：若未实现，设置页明文提示「请改用 465」  
  - 发送失败：首页 banner + `AlertEvent.emailed=false` + 不更新 cooldown（可重试）  
  - 发送成功：更新 `lastAlertAtByAccount`  

- [ ] **Step 1: 单测 `encodeSubject` 与 DATA payload 含 `\r\n.\r\n` 终结**

- [ ] **Step 2: 修复 cooldown：仅 `emailed || notified` 成功之一才写 lastAlert（或：通知成功也算冷却；邮件失败单独 banner）**

建议行为（写入测试）：
- Mac 通知成功 **或** 邮件成功 → 进入冷却  
- 两者都失败 → 不进冷却  

- [ ] **Step 3: 设置页预置常见 SMTP（QQ/163/Gmail）主机端口快捷填入（可选按钮）**

- [ ] **Step 4: Commit**

```bash
git commit -am "fix: SMTP alert reliability and cooldown rules"
```

---

### Task 11: 设置页拆分与信息架构

**Files:**
- Create: `Sources/App/Views/Settings/*.swift`（见文件结构）
- Modify: `MenuRootView` 使用 `SettingsRootView`
- Delete or thin: 巨型 `SettingsView.swift`

**Interfaces:**
- 区块顺序（产品固定）：
  1. 数据源开关  
  2. API 账号 + 添加  
  3. 平台邮件源 + 添加 + 试解析  
  4. IMAP  
  5. 报警通道（Mac / 邮件）+ 测试按钮  
  6. SMTP + 阈值 + 冷却  
  7. 刷新间隔  
  8. 关于  

- [ ] **Step 1: 机械拆分，行为零变化（纯重构）**

- [ ] **Step 2: build 通过**

- [ ] **Step 3: Commit**

```bash
git commit -am "refactor: split settings into sections"
```

---

### Task 12: 首页体验与空态/错误态

**Files:**
- Modify: `HomeView.swift` · `BalanceCardView.swift` · `MenuRootView.swift` · `Theme.swift`

**Interfaces:**
- 首页顶栏 chips 四态：API / 平台邮件 / Mac 通知 / 邮件报警（已有则打磨）  
- 卡片：来源徽章、状态胶囊、主金额、次要 detail、时间  
- 空态文案（最终版）：

```text
还没有余额卡片
· 能 API 查的：设置 → 添加 API 账号
· 只能收邮件的：设置 → 平台邮件源 + IMAP
· 报警：打开 Mac 通知和/或邮件报警
```

- 刷新中：按钮 disabled + 顶栏「刷新中…」  
- 全局 banner：SMTP/IMAP 错误一行展示，可点消失（可选）

- [ ] **Step 1: 按智额 Windows `styles.css` token 对齐 `SBTheme` 色值**

```swift
// 与智额一致
bg:      #0F1115
panel:   #1A1D24
accent:  #2866F7
ok:      #30D158
warn:    #FF9F0A
danger:  #FF453A
```

- [ ] **Step 2: 卡片来源色：API=accent，平台邮件=warn 系**

- [ ] **Step 3: 手动走查首页密度（宽度 380 不变或调到 400）**

- [ ] **Step 4: Commit**

```bash
git commit -am "feat: polish home empty states and theme tokens"
```

---

### Task 13: 品牌图标与本地安装脚本

**Files:**
- Create: `Branding/`（可选，从简单 SF Symbol 导出或纯色 AppIcon）
- Fill: `Sources/App/Resources/Assets.xcassets/AppIcon.appiconset/`
- Create: `scripts/build-test-app.sh`
- Create: `scripts/package-release.sh`（可先只产出 .app zip）

**Interfaces:**
- `build-test-app.sh`：`tuist generate` → `xcodebuild` → 复制 `智余.app` 到 `~/Desktop/智余-test.app`  
- 菜单栏无自定义图标时可用 `yensign.circle.fill`（已有）；Dock 不显示（LSUIElement）

- [ ] **Step 1: 生成最小 AppIcon（可用 1024 单色「余」字 PNG 缩放）**

- [ ] **Step 2: 脚本一键出测试包**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
tuist generate --no-open
xcodebuild -workspace SmartBalance.xcworkspace -scheme SmartBalance \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData build
APP=$(find build/DerivedData -name '智余.app' -type d | head -1)
cp -R "$APP" "$HOME/Desktop/智余.app"
echo "Installed: ~/Desktop/智余.app"
```

- [ ] **Step 3: Commit**

```bash
git commit -am "chore: app icon and local install script"
```

---

### Task 14: V1 验收清单与文档收口

**Files:**
- Modify: `PRODUCT.md` 成功标准勾选  
- Modify: `Apps/Mac/README.md`  
- Modify: 根 `README.md`  
- Create: `docs/USER_GUIDE.md`（简短）

**验收（全部手动打勾）：**

| # | 场景 | 期望 |
|---|------|------|
| 1 | 添加 DeepSeek 真 key 刷新 | 卡片金额正确，来源 API |
| 2 | 添加 New-API 中转 | 点数/USD 展示，401 有可读错误 |
| 3 | OpenRouter key | credits 剩余展示 |
| 4 | IMAP + 平台邮件源 | 匹配发件人后更新卡片，来源平台邮件 |
| 5 | 粘贴试解析 | 金额正确或提示失败 |
| 6 | 阈值压到很高 | Mac 通知弹出 |
| 7 | 开 SMTP | 收到报警邮件；测试邮件成功 |
| 8 | 冷却内再次刷新 | 不重复轰炸 |
| 9 | 关 API 源只留邮件 | 仅邮件卡片 |
| 10 | Keychain | 重启 app 无需重填密码 |

- [ ] **Step 1: 按表验收，缺陷建 list 并修（修不完则写入 `PROJECT_STATUS.md` 已知问题）**

- [ ] **Step 2: 更新 PRODUCT 成功标准为 `[x]`**

- [ ] **Step 3: Commit**

```bash
git commit -am "docs: V1 acceptance and user guide"
```

---

## 依赖关系图

```text
Task1 ─┬─→ Task2 ─→ Task7 ─→ Task8
       │
       ├─→ Task3 ─→ Task4 ─→ Task5
       │
       └─→ Task6 ─→ Task7

Task7 + Task9 + Task10 ─→ Task11 ─→ Task12 ─→ Task13 ─→ Task14
```

可并行：
- A：Task2 ∥ Task3  
- B：Task9 ∥ Task10（在 Task7 后更佳）  
- C：Task11 仅依赖功能稳定，可与 Task12 串行  

---

## 明确不做（防范围蔓延）

- Windows / Android  
- 云同步、账号体系  
- Sparkle 静默更新  
- 完整邮件客户端、多邮箱账号轮询集群  
- 与智额进程合并  
- 自动充值 / 支付  

后续 V1.1 候选：更多 Provider、邮件规则模板市场、菜单栏紧凑金额、导出 CSV。

---

## Self-Review（对照 PRODUCT）

| 需求 | Task |
|------|------|
| API 直查 | 3,4,5 |
| 平台固定邮件 IMAP | 6,7,8 |
| Mac 通知 | 9 |
| 邮件报警 SMTP | 10 |
| 统一卡片 + 来源 | 12 |
| Keychain | 已有；3/10 不落盘复核 |
| 设置信息架构 | 11 |
| 成功标准 | 14 |
| 粘贴试解析 | 8 |
| 冷却 | 10 |
| 视觉参考智额 | 12 |

占位符扫描：无 TBD；关键类型名与现有代码一致（`BalanceSnapshot`、`PlatformMailSource`、`AlertChannelSettings`）。

---

## 执行方式（完成后选择）

Plan 路径：

`docs/superpowers/plans/2026-08-06-smartbalance-v1.md`

**1. Subagent-Driven（推荐）** — 每 Task 新子代理 + 你我复核  
**2. Inline Execution** — 本会话按 Task 连续做，设检查点  

你更想用哪一种？
