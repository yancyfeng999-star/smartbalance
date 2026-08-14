# 智余 Mac 通用能力契约（Task 0 冻结）

> **状态：** 基线已冻结。本文档是 P1 通用能力的产品/数据契约，不是实现完成声明。
> **冻结日：** 2026-08-14
> **工作树：** `.worktrees/mac-common-capabilities`
> **分支：** `feat/mac-common-capabilities`
> **基线提交：** `0067a940bb2231518996d223db1c41ef14c6e936`（`release: 0.3.1 (build 82)`）

后续任务不得猜测当前行为。若实现与本文冲突，以本文「P1 锁定」为准；若需要改变锁定项，先改本文再改代码。

---

## 1. 版本源

| 项 | 值 | 证据 |
|---|---|---|
| 产品版本 | `0.3.1` | `Apps/Mac/Sources/App/Info.plist` → `CFBundleShortVersionString` |
| 构建号 | `82` | 同上 → `CFBundleVersion` |
| Bundle ID | `com.smartbalance.zhiyu` | `Apps/Mac/Project.swift` |
| 最低系统 | macOS 15.0 | `Project.swift` `MACOSX_DEPLOYMENT_TARGET` / `deploymentTargets` |
| Swift | 6.0，严格并发 | `Project.swift` |
| 形态 | 菜单栏 `LSUIElement` | `Info.plist` |

**唯一版本源是 Info.plist。** `PROJECT_STATUS.md` 顶部仍写 `0.2.56（build 77）`，该数字作废，不得作为实现或发版依据。`README.md` 表头已是 `0.3.1`。

本计划执行期间 **不** 跑 `scripts/release.sh`、**不** 创建 GitHub Release、**不** `git push`，除非用户明确要求。

---

## 2. P1 锁定（不可协商）

### 2.1 本地优先

P1 所有数据留在本机。不新增：

- 遥测、云同步、崩溃上传、远程诊断
- 账号注册、云端登录、后台远程服务
- 任何把设置/用量/日志/密钥送到第三方的通道

允许的出站网络仅限：

1. 用户已配置渠道的余额查询（现有 Provider，协议不改）。
2. 用户已配置的 SMTP 报警（本机直连，当前仅 465 TLS）。
3. 用户明确触发的 GitHub Releases **检查更新 / 下载安装包**。

### 2.2 普通 Keychain only

- 运行时凭据只进入 service `com.smartbalance.zhiyu.plain`。
- 使用 `kSecClassGenericPassword` + `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`。
- **禁止** `SecAccessControl`、`kSecAttrAccessControl`、`LAContext`、Touch ID、生物识别、登录钥匙串授权弹窗。
- **禁止** 自动读取、删除或迁移旧版受保护 Keychain 条目。
- 设置 JSON **不得** 写入 API Key、Cookie、Access Token、SMTP 密码或任何密钥值；只允许 `secretRef` / `passwordRef` 这类引用键。

当前实现证据：`LocalSecretStore.swift` 注释与实现已去掉访问控制；基线提交历史含 `Remove biometric Keychain gate`。

### 2.3 备份 / 迁移 / 诊断 allowlist

新生成的设置迁移包、本机恢复备份、诊断包、日志轮转副本 **不得** 包含下表禁止字段。旧 `smartbalance.backup` v1 只识别、警告、隔离，**不得** 再由新 UI 生成，**不得** 把其中的 `secrets` 写回 Keychain。

### 2.4 用量统计口径不变

继续使用现有 `UsageHistoryStore` / `UsageAccumulator` / `UsageSummaryBuilder`：

- 周期：本地自然天；ISO 周（周一开始）；自然月。
- 单位：CNY、USD、未知单位分卡，不换算、不跨币种合计。
- 保留期：每日记录 400 天。
- 首次成功采样只建 baseline，不补历史消费。
- 充值、累计值重置、负 delta、失败/未知快照不计消费。
- 跨日未刷新的差额归入后一次刷新所在日期（`hasBoundaryGap`）。
- 删除账号：丢掉该账号 baseline，保留已写入的每日记录。

通用能力只做刷新接入、保存失败提示、诊断和备份适配，不重写算法。

### 2.5 手动更新

P1 目标流程：检查更新 → 查看版本说明 → 用户明确确认 → 下载 → 校验 → 安装。

**禁止（P1）：** 启动时自动下载/安装、后台静默替换、Beta 通道、匿名崩溃上传。

> **当前代码差距（必须在 Task 6 收敛，不得当成已完成）：**
> `AppModel.checkForUpdates()` 在发现新版本后会立刻 `downloadAndInstallUpdate`；`.pkg` 走 `PackageSilentInstaller.scheduleReplace` 后 `NSApp.terminate`，中间不弹确认。`UpdateChecker` 文案为「发现新版本 …，正在下载安装…」。这是基线事实，不是 P1 目标。

### 2.6 无远程上传

诊断、备份、迁移、崩溃标记全部本地。没有后端地址、隐私政策、同意记录之前，不得实现上传。

### 2.7 固定菜单窗口

菜单栏弹层与置顶窗外框锁定约 **380×580**。

| 常量 | 值 | 位置 |
|---|---|---|
| `SBTheme.panelWidth` | 380 | `Theme.swift` |
| `SBTheme.preferredPanelHeight` | 580 | `Theme.swift` |
| `SBTheme.minPanelHeight` | 420 | 仅当可见屏高不够时缩小 |
| 置顶窗默认 | 380×580 | `PinnedBalanceWindow.swift` |

导航仍是首页 / 用量 / 设置三段。右上角齿轮 → 设置；底栏「用量」→ 用量。新页面必须适配窄窗，不得复制智额布局或品牌文案。

---

## 3. 数据路径与权限

| 数据 | 路径 | 当前写入 | P1 规则 |
|---|---|---|---|
| 设置 | `~/Library/Application Support/SmartBalance/settings.json` | `SettingsStore` 原子写，`0600` | 增加 schema envelope；仍 `0600`；不含密钥值 |
| 用量历史 | `~/Library/Application Support/SmartBalance/usage-history.json` | `UsageHistoryStore` mkstemp + `0600` + rename | 口径不变；损坏先备份再空文档 |
| 损坏设置备份 | 同目录 `settings.corrupt-<epoch>.json` | 解码失败时写出后返回默认设置 | 不得静默当「没有账号」而不留痕迹 |
| 损坏用量备份 | 同目录 `usage-history.corrupt-<epoch>.json` | 解码失败时备份，返回空文档 + `corruptFileBackedUp` | UI/诊断必须暴露 recovery，不得当「零用量」 |
| 密钥 | Keychain service `com.smartbalance.zhiyu.plain` | `LocalSecretStore` | 不导出、不上传、不弹生物识别 |
| 日志 | `~/Library/Logs/SmartBalance/app.log` | `AppLog` 追加，无轮转 | Task 4 增加脱敏与轮转；导出前必须 redacted |
| 崩溃/恢复标记 | Application Support 下新文件（尚未存在） | 无 | 只记启动状态和失败分类 |
| 诊断包 | 用户选择的位置 | 无 | allowlist + `0600` |

---

## 4. 当前设置文档（v0 根对象）

`settings.json` **现在没有** `schemaVersion` envelope。根对象直接 decode 为 `AppSettings`。

### 4.1 已知字段（当前 encode）

`accounts` · `email` · `alertChannels` · `apiQueryEnabled` · `refreshIntervalSecs` · `lastAlertAtByAccount` · `windowPinned` · `themeMode` · `appLanguage`

默认值（字段缺失时）：

| 字段 | 默认 |
|---|---|
| `accounts` | `[]` |
| `email` | `EmailAlertSettings()`（SMTP 关，端口 465，TLS 开，`passwordRef = "smtp-password"`） |
| `alertChannels` | 见 4.3 |
| `apiQueryEnabled` | `true`（刷新时若为 `false` 会被强制改回 `true`） |
| `refreshIntervalSecs` | `900` |
| `lastAlertAtByAccount` | `{}` |
| `windowPinned` | `false` |
| `themeMode` | `system` |
| `appLanguage` | `zh-Hans` |

### 4.2 旧字段读取语义（必须保持）

| 旧键 | 当前行为 |
|---|---|
| `emailAlertModeEnabled` | 仅当 **没有** `alertChannels` 时，映射到 `alertChannels.outboundEmailEnabled`；缺省 `true` |
| `mailSources` / `inboundMailbox` / `platformMailEnabled` | 解码忽略 |
| `alertChannels.defaultAmountThreshold` | 无 `warningAmount` 时使用；若旧值 `≤ 10` 或 `== 200`，改成新默认 `100` |
| `alertChannels.defaultPercentThreshold` | 无 `warningPercent` 时使用 |

### 4.3 报警分档默认

`BalanceTierDefaults`：金额 100 / 50 / 20；百分比 30 / 15 / 10；冷却 3600 秒。

### 4.4 账号字段（`BalanceAccount`）

可落盘：`id`、`kind`、`displayName`、`baseURL`、`consoleURL`、`userId`、`secretRef`、`enabled`、阈值、手录金额/单位/时间/每日提醒。

`userId` 是非密钥管理 ID（如 DMXAPI 用户号、MiMo userId），可以出现在设置和迁移包中。
`secretRef` 只是 Keychain 账户名，**值**不得出现在设置文件里。

### 4.5 当前未知字段策略（缺口）

`AppSettings` 自定义 `Codable` **丢弃**未声明键。读入再写出后，未知顶层字段和未知账号字段会消失。P1 Task 1 必须改为 `extensions`（或等价容器）保留未知字段，且未知字段不得影响已知字段校验。

### 4.6 损坏与空账号保护

- 文件不存在 → 默认 `AppSettings()`。
- JSON 损坏 → 备份坏文件，返回空默认（当前 **没有** 首次启动/兼容性页解释这一点）。
- `save`：若内存 `accounts` 为空而磁盘上已有非空账号，拒绝覆盖账号列表（保留旧 accounts，其余字段仍写入）。

---

## 5. 当前备份 v1（安全债务）

`DataBackupService` / `DataBackupPackage`：

```text
format          = "smartbalance.backup"
formatVersion   = 1
exportedAt      = ISO-8601
appVersion      = Info.plist 短版本
settings        = 完整 AppSettings（含 secretRef / passwordRef / 邮箱地址）
secrets         = [String: String]   // 明文 API Key / Cookie / SMTP 密码
```

写入权限 `0600`。UI：`AppModel.exportDataBackup` / `importDataBackup`。导入会 `LocalSecretStore.replaceAll`，settings 失败则回滚密钥内存快照。

**P1 目标格式**（Task 1/5 实现，名称可微调、语义不可改）：

```text
format          = "smartbalance.portable-settings"
formatVersion   = 2
```

只允许非敏感字段。导入后为账号和 SMTP **生成新的凭据引用**，结果带 `credentialsNeedReentry`，不读旧 Keychain，不导入 v1 `secrets`。

`LocalSecretStore.exportAll()` 当前只导出 **进程内 memory 缓存**，不是完整 Keychain dump。新备份路径不得依赖这个 API 输出密钥值。

---

## 6. 禁止导出字段（诊断 / 迁移 / 新备份 / 日志）

以下键、头和值不得出现在新生成的用户可见文件中（包括 JSON、TXT、ZIP）。检测时只记录路径，不把真实值写入仓库或报告。

**绝对禁止**

- `secrets` 对象及其任意值
- API Key / Access Token / Session Cookie / SMTP 密码的明文
- HTTP `Authorization` / `Cookie` / `Bearer` 头或值
- URL 查询参数中的 token / key / session
- Provider 请求体、响应体、原始错误 payload
- Keychain service 名以外的条目内容；诊断里 Keychain 只允许 `available` / `unavailable` / `unknown`
- `secretRef` / `passwordRef` 的 **值**（连引用字符串也不进入 v2 迁移包）
- 完整原始 `app.log`

**允许（allowlist）**

- app version / build、macOS、架构、运行方式、schema version
- 目录可写性、权限、文件大小
- 账号：Provider 类型、显示名、是否启用、是否「存在凭据」（布尔）、手录金额与单位
- 邮件：主机、端口、TLS、是否已配置；**不含** 用户名/地址以外需脱敏的内容时，诊断应对邮箱做 redaction
- 刷新状态摘要：成功/失败数、最近刷新时间；不含 URL
- 用量：记录数、最早/最新日期、单位类别、保存错误分类
- 通知授权枚举（未决定 / 已授权 / 已拒绝 / 受限）

**v1 旧包处理**

识别 `smartbalance.backup` v1 后必须提示文件含明文密钥。允许预览非敏感设置；默认不导入。用户明确确认后，按稳定账号 ID 把 secrets 映射到新 ref 并写入普通 Keychain；失败回滚设置和已写入凭据，不自动删除用户文件。

---

## 7. 用量历史文档（保持）

`UsageHistoryDocument.currentSchemaVersion = 1`

字段：`schemaVersion`、`baselines`、`dailyRecords`、`updatedAt`。

有效快照条件（`UsageAccumulator`）：账号仍存在；`errorMessage == nil`；状态不是 `error` / `setup` / `unknown`；单位非空；能得到测量值。

测量选择：

1. 同时有有限的 `used ≥ 0` 且 `total > 0` → `providerCumulative`（用 `used`）。
2. 否则有有限 `amount` → `balanceDeltaEstimate`。
3. 方法/单位/Provider 变化 → 重建 baseline，不计该次 delta。

---

## 8. 刷新、通知、更新接入点（当前）

这些符号是后续任务的挂载点，不是授权去改 Provider 协议。

| 能力 | 当前位置 |
|---|---|
| 活动刷新任务 | `AppModel.activeRefreshTask`；取消后 `refreshGeneration` 丢弃旧结果 |
| 定时刷新 | `AppModel.refreshTask` + `startAutoRefreshIfNeeded()`；间隔 `refreshIntervalSecs`（0 = 仅启动后刷一次） |
| 用量写入 | `AppModel` → `UsageHistoryStore.record`；失败设 `usageDataError`，**不回滚**余额快照 |
| 通知授权 | 启动时 `requestAuthorizationIfNeeded()`；开启 Mac 通知时再请求；手录每日提醒也会请求 |
| 备份包 | `DataBackupPackage` / `DataBackupService` |
| 更新检查 | `UpdateChecker`（GitHub `yancyfeng999-star/smartbalance`） |
| 静默安装 | `PackageSilentInstaller` |
| 日志 | `AppLog` |

P1 要求（尚未实现）：同一 scope 去重；取消/sleep 保留快照；用量保存失败独立提示；通知授权改到明确用户动作。

---

## 9. 界面与产品边界

已存在且必须复用：

- 入口：`SmartBalanceApp` → `MenuBarExtra` → `MenuRootView`
- 状态中心：`AppModel`（`@MainActor`）
- 导航：`home` / `usage` / `settings`
- 渠道：`ProviderKind` 现有 case（deepseek、newapi、openrouter、viraltok、laozhang、dmxapi、kimi、volcengine、mimo、minimax、apinebula）
- 测试替身：`HTTPClientMock`；默认禁止真实 Provider 网络作为通用能力测试

明确不做（P1）：Windows、云账号、IMAP、官方公证流水线、复制智额产品模型。

---

## 10. Fixture（仅结构与假值）

目录：`Apps/Mac/Tests/Fixtures/CommonCapabilities/`

| 文件 | 用途 |
|---|---|
| `legacy-settings-v0.json` | 旧根对象：无 schemaVersion、无 `alertChannels`、含 `emailAlertModeEnabled` 与已忽略入站邮件字段 |
| `legacy-settings-with-unknown-fields.json` | 当前根对象 + 未知顶层/账号字段（供 Task 1 证明读回不丢） |
| `corrupt-settings.json` | 故意损坏的 JSON |
| `legacy-secret-backup-v1.json` | `smartbalance.backup` v1 外形；`secrets` 值仅为 `REDACTED_TEST_TOKEN` |

约束：禁止真实凭据、真实 Cookie、真实 Provider 响应、真实邮箱以外的 `example.test` / `REDACTED_*` 占位。

---

## 11. 基线测试

命令：`cd Apps/Mac && ./scripts/run-tests.sh`

工作树初次执行时 `tuist generate` 因缺少 `Apps/Mac/Tuist/.build/checkouts/MenuBarExtraAccess` 失败。该目录不在 git 中。在 **不改产品代码** 的前提下于 `Apps/Mac/Tuist` 执行 `swift package resolve` 后复跑成功。

| 套件 | 结果 |
|---|---|
| DomainTests | 37 passed, 0 failed |
| InfrastructureTests | 89 passed, 0 failed |
| AppTests | 6 passed, 0 failed |
| **合计** | **132 passed, 0 failed** |

`** TEST SUCCEEDED **`（2026-08-14，本机 arm64）。无既有失败。

日志噪音（非失败）：AppTests 连接 `com.apple.linkd.autoShortcut` / StatusBar scene 的系统报错。

后续任务若测试失败，不得把本基线 132 绿归因于「本来就红」。

---

## 12. 只读文档差异

| 文件 | 相对 0.3.1 基线 |
|---|---|
| `Info.plist` | 权威：0.3.1 / 82 |
| `README.md` | 版本 0.3.1，能力描述可用 |
| `PRODUCT.md` | 窗口 380×580、本地 Keychain、不做云同步 — 与 P1 一致 |
| `PROJECT_STATUS.md` | 版本过期（0.2.56 / 77）；数据路径表仍有参考价值 |
| `AGENTS.md` | 默认「做完就发版」；**本计划覆盖该条**，P1 完成前不发版 |
| `Project.swift` | macOS 15 / Swift 6 / 三测试 target |

---

## 13. 扫描摘要（只记位置）

完整命中见 Task 0 报告。结论：

- 源码中 **没有** `SecAccessControl` / `kSecAttrAccessControl` / `LAContext` 调用。`Touch ID` 仅出现在 `LocalSecretStore.swift:8` 的「不使用」注释。
- `secrets` 明文进出集中在 `DataBackupService` 与 `AppModel` 导出/导入。
- `requestAuthorization` 发生在启动、打开 Mac 通知、手录提醒、测试通知。
- hook 正则也会误中 `AppLogo`（`HomeView` / `MenuRootView` / `BackgroundSystemSection` / `MenuBarStatusItemDriver`），那些不是 `AppLog` 接入点。

---

## 14. 后续任务不得破坏的验收句

1. 旧 `settings.json` 能读出账号、主题、语言、刷新间隔；缺失字段用上表默认值。
2. 新写入不得因空账号列表抹掉已有账号。
3. 新导出包搜索 `secrets` / `Bearer` / `Cookie` / `password` / `api_key` 不得命中真实值或密钥引用值。
4. 日/周/月金额与 400 天裁剪与 0.3.1 测试一致。
5. 菜单弹层仍约 380×580，三段导航语义不变。
6. 启动与常规设置不出现 Touch ID / 钥匙串密码门禁。
7. P1 更新必须用户确认；不得再把「检查更新」直接变成静默安装（Task 6 之前保持现状，但不得把现状写成目标）。
