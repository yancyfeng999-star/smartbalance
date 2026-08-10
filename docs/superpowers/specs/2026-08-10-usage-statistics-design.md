# 智余本地用量统计设计

> 日期：2026-08-10
>
> 状态：设计已确认，等待用户复核本文档后生成实施计划
>
> 工作模式：Standard
>
> 目标平台：macOS 15+，Swift 6，SwiftUI/AppKit，Tuist

## 1. 目标

在智余现有余额查询基础上增加本地用量统计，让用户能按自然天、自然周、自然月查看每个渠道消耗的金额，并能回看历史周期。

该功能只使用智余已经取得的余额快照和累计用量字段，不新增云端服务，不读取 Provider 历史账单，不改变现有密钥、报警、邮件和更新流程。

## 2. 用户结果

用户能够：

1. 在首页右上角通过齿轮进入设置。
2. 从首页底部原“设置”位置进入“用量”。
3. 在“天 / 周 / 月”之间切换。
4. 查看当前或历史自然周期内每个渠道的消费金额。
5. 分别查看人民币和美元总额，不发生跨币种直接相加。
6. 区分“接口统计”“余额估算”和“混合统计”。
7. 在周/月视图中查看按日柱状趋势，并通过鼠标悬停读取日期和金额。

## 3. 当前项目事实

- 应用是固定 `380 × 580` 的 macOS 菜单栏弹层，并支持置顶窗口。
- UI 入口为 `SmartBalanceApp → MenuRootView`，状态由 `AppModel` 管理。
- 当前导航只有 `home` 和 `settings`。
- 首页底部当前为“打开后台 / 设置 / 退出应用”。
- 余额刷新完成后，`AppModel` 接收 `[BalanceSnapshot]`。
- `BalanceSnapshot` 已包含 `amount`、`unit`、`used`、`total`、`fetchedAt` 等字段。
- 设置使用 `Application Support/SmartBalance/settings.json`，通过原子 JSON 写入和 `0600` 权限保护。
- 项目当前没有数据库或第三方图表依赖。
- 设计前基线测试为 89 项全部通过；这些是本地单元/契约测试，不代表真实账号联网验收。

## 4. UI 参考与取舍

主要参考 [CodexBar](https://github.com/steipete/CodexBar) 的以下模式：

- 紧凑 KPI 与 Provider 明细放在同一个信息面板中。
- 每日消费使用短柱图表达。
- 图表支持鼠标选择或悬停详情。
- 刷新失败时保留最后一次成功数据。
- 图表具有可读的无障碍标签。

参考源固定到 CodexBar 提交 [`930b1c4`](https://github.com/steipete/CodexBar/commit/930b1c4d0d43f85b0a167be35e884c4ffa4a151a)：

- [`InlineUsageDashboardContent.swift`](https://github.com/steipete/CodexBar/blob/930b1c4d0d43f85b0a167be35e884c4ffa4a151a/Sources/CodexBar/InlineUsageDashboardContent.swift)
- [`CostHistoryChartMenuView.swift`](https://github.com/steipete/CodexBar/blob/930b1c4d0d43f85b0a167be35e884c4ffa4a151a/Sources/CodexBar/CostHistoryChartMenuView.swift)
- [`UsageProgressBar.swift`](https://github.com/steipete/CodexBar/blob/930b1c4d0d43f85b0a167be35e884c4ffa4a151a/Sources/CodexBar/UsageProgressBar.swift)

智余不照搬 CodexBar 的 Token、请求数、模型明细、多来源扫描、多级子菜单或账号切换结构。图表使用 Apple 原生 [Swift Charts `BarMark`](https://developer.apple.com/documentation/charts/barmark)，不新增第三方依赖。

## 5. 方案比较

### 5.1 混合统计（采用）

- Provider 明确返回累计 `used/total` 时，用累计用量差额。
- Provider 只返回余额时，用余额下降差额估算。
- 覆盖全部内置渠道，并保留统计质量标签。

优点：覆盖完整，能在支持累计用量的渠道上避免充值导致的少算。

代价：需要处理统计模式切换、Provider 重置和 New-API 单位归一化。

### 5.2 全部使用余额差额（不采用）

统一使用 `上次余额 - 本次余额`。

优点：代码最少。

缺点：充值、退款、赠送额度和消费同时发生时只能得到净变化，容易少算。

### 5.3 对接各渠道历史账单（不采用）

为每个 Provider 接入账单或费用历史 API。

优点：理论准确度最高。

缺点：多数渠道没有统一公开接口，认证和 DTO 维护成本高，明显超出本次简单需求。

## 6. 渠道能力矩阵

| 渠道 | 首选统计方法 | 首版质量标签 | 说明 |
| --- | --- | --- | --- |
| OpenRouter | 累计 `used` 差额 | 接口统计 | 当前快照已有 USD `used/total` |
| ViralTok（吉米） | 累计 `used` 差额 | 接口统计 | 统一换算为人民币 |
| 老张 API | 累计 `used` 差额 | 接口统计 | 统一换算为人民币 |
| DMXAPI | 累计 `used` 差额 | 接口统计 | 统一换算为人民币 |
| apinebula | 累计 `used` 差额 | 接口统计 | 无限额度账户不统计 |
| New-API | 累计 `used` 差额 | 接口统计 | 实施前先把 `used/total` 从点数归一化为 USD |
| DeepSeek | 余额下降差额 | 余额估算 | Provider 只返回余额 |
| Kimi | 余额下降差额 | 余额估算 | Provider 只返回余额 |
| 火山引擎 | 余额下降差额 | 余额估算 | Provider 只返回余额 |
| 小米 MiMo | 余额下降差额 | 余额估算 | Provider 只返回余额 |
| MiniMax | 余额下降差额 | 余额估算 | Provider 只返回余额 |

当某个 Provider 原本提供累计用量、某次却缺失这些字段时，不在同一次采样中自动切换为余额估算。系统先重建新模式基线，避免重复计算。

## 7. 自然周期定义

- 天：系统当前时区的 `00:00` 至次日 `00:00`。
- 周：ISO 周，周一 `00:00` 至下一周一 `00:00`，使用系统当前时区。
- 月：自然月 1 日 `00:00` 至下月 1 日 `00:00`。
- 默认锚点为今天。
- 左箭头进入上一个同类周期。
- 右箭头进入下一个同类周期，但不得超过当前周期。
- 当目标周期早于最早保留的每日记录时，左箭头禁用；只有基线而没有每日记录时不开放历史导航。
- 周和月都从每日账本聚合，不保存独立周表或月表。
- 日期键使用本地日历生成的 `yyyy-MM-dd`，同时保存采样时区标识；用户切换系统时区后不重新分配已经形成的历史日记录。

## 8. 统计规则

### 8.1 有效快照

只有同时满足以下条件的快照才参与统计：

- 对应真实配置账号。
- 刷新成功，没有 `errorMessage`。
- 不是 `.unknown`、`.setup` 或 `.error` 状态。
- `unit` 非空。
- 用于计算的数值是有限值。

余额可以为负数，以支持欠费场景；累计 `used` 必须大于等于零。

### 8.2 单位归一化

- `¥`、`￥`、`CNY` 统一为内部单位 `CNY`，显示符号为 `¥`。
- `$`、`USD` 统一为内部单位 `USD`，显示符号为 `$`。
- 未识别单位保持独立分组，不与 CNY 或 USD 合计。
- New-API 的 `amount/used/total` 必须全部是 USD 后才能进入累计统计。

### 8.3 累计用量模式

1. 第一条有效快照只建立基线。
2. `本次 used > 上次 used`：差值记入本次采样所在自然日。
3. `本次 used == 上次 used`：消费为零，只更新时间基线。
4. `本次 used < 上次 used`：视为 Provider 周期或额度重置，消费为零并重建基线。
5. `total` 变化不直接产生消费；消费只由累计 `used` 的正差值决定。

### 8.4 余额估算模式

1. 第一条有效余额只建立基线。
2. `本次余额 < 上次余额`：差值记为估算消费。
3. `本次余额 == 上次余额`：消费为零。
4. `本次余额 > 上次余额`：视为充值、退款或额度调整，消费为零并重建基线。
5. 充值与消费发生在两次采样之间时，只能观察净变化；界面必须保留“余额估算”标签。

### 8.5 基线切换与时间归属

- 账号 ID、Provider、单位或统计方法变化时，只重建基线，不计算跨模式差额。
- 刷新失败不覆盖最后一次成功基线。
- 跨越午夜但中间没有成功采样时，整个差额记入下一次成功采样所在日。
- “接口统计”说明金额来源更可靠，但跨日归属仍受采样频率影响；帮助文案需说明“按刷新采样时间归日”。
- App 默认 15 分钟刷新可提高日期归属准确性，但关闭应用期间无法精确拆分每日消费。

## 9. 数据模型

Domain 层新增以下概念：

### `UsagePeriod`

- `day`
- `week`
- `month`

### `UsageMeasurementMethod`

- `providerCumulative`
- `balanceDeltaEstimate`

### `UsageBaseline`

保存：

- 账号 ID。
- Provider。
- 归一化单位。
- 当前统计方法。
- 上次累计用量或余额。
- 上次成功采样时间。

### `UsageDailyRecord`

保存：

- 本地日期键。
- 采样时区标识。
- 账号 ID。
- Provider。
- 归一化单位。
- 接口统计金额。
- 余额估算金额。
- 样本数量。
- 是否存在跨日采样归属。

### `UsageProviderSummary`

按 `Provider + 单位` 汇总一个周期内的：

- 总金额。
- 接口统计金额。
- 估算金额。
- 账号数量。
- 每日序列。
- 展示质量：接口统计、余额估算或混合统计。

### `UsageCurrencySummary`

按归一化单位汇总：

- 周期总额。
- 渠道列表。
- 每日趋势。

## 10. 本地存储

新增文件：

```text
~/Library/Application Support/SmartBalance/usage-history.json
```

文档结构包含：

- `schemaVersion = 1`。
- `baselines`。
- `dailyRecords`。
- `updatedAt`。

存储规则：

- 使用 actor 串行化加载、写入和清理。
- 使用 ISO 8601 编码日期。
- 使用 pretty-printed、sorted-keys JSON，便于排障。
- 使用原子写入。
- 文件权限设置为 `0600`。
- 解码失败时备份为 `usage-history.corrupt-<timestamp>.json`，随后从空历史重新建立基线。
- 保留最近 400 个自然日，覆盖一个完整年度及边界余量。
- 删除账号时删除活动基线，已经形成的每日历史保留到自然过期。
- 不保存 API Key、Cookie、Access Token、请求头或 Provider 响应正文。

每次采样必须使用事务式内存副本：先在副本上计算新基线和每日记录，原子保存成功后再替换 Store 内状态并发布给 `AppModel`。保存失败时继续保留上一次成功状态，下一次成功采样仍从旧基线计算，避免“内存已前进、磁盘未保存”造成漏记或重启后重复记账。

历史保存失败不能阻断余额刷新。App 保留当前余额结果，记录脱敏日志，并在用量页显示可消失的“用量记录保存失败”提示。

## 11. 数据流

```text
BalanceService 刷新成功
        ↓
AppModel 完成 refresh generation 校验
        ↓
UsageHistoryStore 读取现有历史
        ↓
UsageAccumulator 校验快照、选择统计方法、计算正差值
        ↓
按本地自然日合并 UsageDailyRecord
        ↓
原子保存 usage-history.json
        ↓
UsageSummaryBuilder 按天 / 周 / 月和币种聚合
        ↓
UsageView 展示 KPI、柱图和渠道明细
```

只有通过现有 refresh generation 校验的最新刷新结果可以写入历史，过期异步请求不得产生重复记录。

## 12. 导航与页面设计

### 12.1 首页

- 在现有刷新、置顶按钮右侧新增齿轮按钮。
- 齿轮进入设置，并保留 `⌘,`。
- 首页底部中间按钮从“设置”改成“用量”，使用 `chart.bar.xaxis`。
- “用量”使用 `⌘U`。
- “打开后台”和“退出应用”保持原行为。

### 12.2 用量页

```text
┌──────────────────────────────────────┐
│ ‹ 返回              用量              │
├──────────────────────────────────────┤
│        [ 天 ] [ 周 ] [ 月 ]           │
│      ‹       2026 年 8 月       ›     │
│                                      │
│ ¥ 本月消耗                     128.40 │
│ ▁ ▂ ▃ ▂ ▅ ▄ ▆ ▃ ▂ ▇  每日柱状图       │
│ ViralTok          ¥58.40   接口统计   │
│ DeepSeek          ¥32.10   余额估算   │
│ DMXAPI            ¥37.90   接口统计   │
│                                      │
│ $ 本月消耗                      14.62 │
│ ▁ ▃ ▂ ▆ ▄ ▅ ▇       每日柱状图         │
│ OpenRouter         $9.42   接口统计   │
│ New-API            $5.20   接口统计   │
└──────────────────────────────────────┘
```

- 页面继续使用固定 `380 × 580` 壳和中间滚动区。
- 顶部返回按钮回到首页。
- 周期选择器使用紧凑 segmented control。
- 周期导航标题根据语言本地化。
- 每个币种使用一张平面面板，不嵌套额外卡片。
- 天视图直接显示渠道对比条，不显示只有一个点的趋势图。
- 周视图显示周一至周日的每日柱图。
- 月视图显示 1 日至月末的每日柱图。
- 柱图使用 `SBTheme.accent`；选中柱使用系统黄色强调，不创建随机 Provider 颜色。
- 渠道行显示现有 Provider Logo、Provider 名称、金额和统计质量标签。
- 同一 Provider 的多个账号合并为一个渠道行，并显示“2 个账号”等辅助信息。
- 图表悬停显示日期、金额和是否包含估算。
- 金额使用 monospaced digits，保持刷新时宽度稳定。

### 12.3 状态设计

- 尚无账号：提示“请先在设置中添加 API 账号”，提供设置按钮。
- 只有第一条基线：提示“已开始记录，下一次余额变化后显示用量”。
- 周期内无消费：显示金额 `0.00`，不误报为无数据。
- 刷新失败：保留既有历史，并显示最后更新时间。
- 当前周期含跨日归属：在帮助提示中说明“部分金额按下一次成功刷新归日”。
- 历史文件损坏：提示已重新开始记录，详细路径只写入脱敏日志。

## 13. 本地化与无障碍

- 新增文案覆盖现有 10 种语言：简体中文、英文、日文、韩文、俄文、阿拉伯文、法文、德文、西班牙文、葡萄牙文。
- 阿拉伯语继续使用 RTL 布局。
- 齿轮、返回、周期切换、周期导航和渠道行提供 VoiceOver 标签。
- 图表提供周期、币种、总额和数据点数量的 accessibility value。
- 不依赖颜色区分“接口统计”和“余额估算”，同时显示文字标签。
- 深浅色都使用现有 `SBTheme` token，不新增未经对比度验证的文本颜色。

## 14. 代码边界

### 新增文件

```text
Apps/Mac/Sources/Domain/UsageModels.swift
Apps/Mac/Sources/Domain/UsageAccumulator.swift
Apps/Mac/Sources/Domain/UsageSummaryBuilder.swift
Apps/Mac/Sources/Infrastructure/UsageHistoryStore.swift
Apps/Mac/Sources/App/Views/Usage/UsageView.swift
Apps/Mac/Sources/App/Views/Usage/UsageCurrencyCard.swift
Apps/Mac/Sources/App/Views/Usage/UsageProviderRow.swift
Apps/Mac/Tests/DomainTests/UsageAccumulatorTests.swift
Apps/Mac/Tests/DomainTests/UsageSummaryBuilderTests.swift
Apps/Mac/Tests/InfrastructureTests/UsageHistoryStoreTests.swift
```

### 修改文件

```text
Apps/Mac/Sources/Infrastructure/Providers/NewAPIBalanceProvider.swift
Apps/Mac/Sources/App/AppModel.swift
Apps/Mac/Sources/App/Views/MenuRootView.swift
Apps/Mac/Sources/App/Localization/L10n.swift
Apps/Mac/Sources/App/Theme.swift
Apps/Mac/Tests/InfrastructureTests/*ProviderTests.swift
PRODUCT.md
README.md
docs/USER_GUIDE.md
PROJECT_STATUS.md
```

不修改现有密钥库、账号 Schema、Provider 请求认证、通知、SMTP、更新器、App 权限或状态栏宿主逻辑。

## 15. 测试设计

### 15.1 开工门禁：全部渠道契约

在实现统计引擎和 UI 前，先让现有 11 个 Provider 测试明确断言：

- `amount/used/total/unit` 单位一致。
- 支持累计用量的 Provider 返回可用字段。
- 只支持余额的 Provider 不伪造 `used/total`。
- New-API 的 `used/total` 已换算为 USD。
- 无限额度账户不进入累计统计。
- 请求失败、业务失败和凭证缺失不会产生有效统计快照。

该门禁全部通过后才能继续统计功能。

### 15.2 Domain 测试

- 第一条累计用量只建立基线。
- 累计用量正差值记入当天。
- 累计用量相等记零。
- 累计用量下降重建基线。
- 第一条余额只建立基线。
- 余额下降产生估算消费。
- 余额增加重建基线。
- 负余额仍可正确计算下降差额。
- 刷新错误不覆盖基线。
- Provider、单位和方法切换不跨基线计算。
- 跨午夜差额归入后一次采样日并留下标记。
- 周一边界、月初边界和闰年日期。
- 多账号按 Provider 汇总。
- CNY、USD 和未知单位严格分离。
- 接口统计、余额估算和混合统计标签正确。
- 400 天保留边界正确。

### 15.3 Infrastructure 测试

- 空文件首次加载。
- JSON 编解码往返。
- 原子保存后内容完整。
- POSIX 权限为 `0600`。
- 损坏文件产生备份并返回空历史。
- 多次并发调用由 actor 串行化。
- 删除账号只移除活动基线。
- 保存失败不会损坏上一次完整文件。

### 15.4 App 与运行态验收

- 完整执行 `./scripts/run-tests.sh`。
- Debug 构建成功。
- Release 构建成功。
- 首页齿轮、`⌘,`、用量入口、`⌘U` 和返回行为正确。
- 首页、用量、设置切换时外壳保持 `380 × 580`。
- 菜单栏弹层和置顶窗口分别验证。
- 账号较多时滚动正常。
- 天/周/月和历史前后周期切换正确。
- 周/月图表悬停详情正确。
- 浅色、深色、中文、英文和阿拉伯语 RTL 检查。
- VoiceOver 能读出按钮、金额、统计质量和图表摘要。
- 无账号、只有基线、零消费、刷新失败、历史损坏状态可辨认。

真实 Provider 验收只通过应用正常刷新本机已配置账号，不直接读取或输出任何 secret bytes。未配置的渠道必须单独标记为“真实联网未验证”，不能用 Fixture 通过代替。

## 16. 验收标准

1. 用户能够通过首页“用量”进入固定尺寸统计页。
2. 用户能够查看任意保留期内的自然天、自然周和自然月。
3. 每个渠道显示周期消费金额和统计质量。
4. CNY、USD 和其他单位从不跨币种直接相加。
5. 首次采样、充值、Provider 重置、刷新失败、模式变化不会产生负消费或重复消费。
6. 周/月金额严格等于其每日记录之和。
7. 应用重启后历史仍存在，损坏文件不会静默覆盖。
8. 用量保存失败不影响现有余额查询和报警。
9. 所有本地测试、构建和运行态验收通过后才允许执行项目发布流程。

## 17. 明确不做

首版不包含：

- 云同步或服务端数据库。
- 自动汇率和跨币种总金额。
- Provider 历史账单 API。
- 安装前历史补算。
- 小时级统计。
- CSV、Excel 或 PDF 导出。
- 预算、用量报警或消费预测。
- Token、请求数或模型成本拆分。
- 修改余额报警、Mac 通知、SMTP、凭证存储和自动更新逻辑。
- 修改状态栏图标、宿主窗口或菜单栏权限。

## 18. 发布和证据边界

功能实施完成后按智余项目规则分别记录：

- `local_tests`：本地测试。
- `local_build`：Debug/Release 构建。
- `runtime_verified`：真实 App 菜单栏和置顶窗口验收。
- `local_package`：DMG/PKG 生成。
- `remote_release`：GitHub Release 和资产核验。
- `update_verified`：旧版本应用内检查更新、安装、重启和版本确认。
- `user_installed`：只有用户实际完成安装后才能确认。

文档设计确认不等于功能已实现，也不等于任何真实渠道、远端 Release 或用户安装已经完成。
