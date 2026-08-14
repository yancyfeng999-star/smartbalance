# 智余 Mac 通用能力 · 全量验证记录

> **不是发版声明。** 本文记录 Task 11 在单一工作树上收集到的证据。  
> **工作树：** `.worktrees/mac-common-capabilities`  
> **分支：** `feat/mac-common-capabilities`  
> **代码 HEAD（验证时）：** `416bf3416b814f599a7e1b5b17942a29ffca5909`  
> **基线：** `0067a940bb2231518996d223db1c41ef14c6e936`（`release: 0.3.1 (build 82)`）  
> **验证日：** 2026-08-14  
> **版本源：** `Apps/Mac/Sources/App/Info.plist` → **0.3.1 / 82**（本任务未升版）

契约：`docs/superpowers/specs/2026-08-14-mac-common-capabilities-spec.md`  
计划：`docs/superpowers/plans/2026-08-14-mac-common-capabilities.md`

---

## 1. 证据分层（必须分开读）

| 口径 | 本记录结论 | 不是什么 |
|------|------------|----------|
| 已实现 | P1 代码在本工作树 `0067a94..416bf34` | 不等于用户已装上 |
| 本地测试 | Domain/Infrastructure/App **366 passed, 0 failed** | 不等于菜单栏点过 |
| Debug 构建 | **BUILD SUCCEEDED**（arm64） | 不等于已安装 |
| Release 构建 | **BUILD SUCCEEDED**（universal `x86_64` + `arm64` 切片） | 切片存在 ≠ Intel 机器跑过 |
| 隔离运行时 | 临时 Application Support / Logs 上的服务级检查 | 不等于弹层交互 |
| 当前机器验证 | Apple M5 / arm64 / macOS 26.6.1 (25G76) | **不宣称** Intel + Apple Silicon 双机已证实 |
| 安装包 | **未执行** `package-release.sh` / `release.sh` | 无新 dmg/pkg |
| 已发布 | **未执行** `git push` / tag / GitHub Release | 已发布仍是既有 `v0.3.1` |
| 真实渠道 | **未执行** | 禁止写成「全部渠道通过」 |
| 菜单栏交互 | **当前机器未做交互验收** | `/Applications/智余.app` 是已发布包，不是本工作树 |
| 用户验收 | **否** | 未请用户验收 |

`AGENTS.md` 默认发版在本计划期间被覆盖：Task 11 **没有**跑 `Apps/Mac/scripts/release.sh`，**没有** push，**没有**创建 Release。

---

## 2. 当前机器

| 项 | 值 |
|----|----|
| 架构 | arm64（Apple M5） |
| 系统 | macOS 26.6.1 (25G76) |
| 验证范围 | **当前机器验证** |
| 已运行的已发布应用 | `/Applications/智余.app` 当时在跑；验证未对其发信号、未替换 |
| 本机真实数据 | `~/Library/Application Support/SmartBalance/` 仍是 **v0 根对象**（无 `schemaVersion`）。隔离检查 **没有** 对这份目录做迁移或写入 |

第二架构：Release 可执行文件含 `x86_64` 切片（lipo），这是 **编译证据**，不是 Intel Mac 运行时证据。

---

## 3. 命令与结果

### 3.1 测试

```bash
cd Apps/Mac && ./scripts/run-tests.sh
```

| 项 | 结果 |
|----|------|
| 结束时间 | 2026-08-14 17:02:08 +0800 |
| 结论 | `** TEST SUCCEEDED **` |
| xcresult | `~/Library/Developer/Xcode/DerivedData/SmartBalance-aeavfiqjnerkbegnyemevsvhinsd/Logs/Test/Test-SmartBalance-2026.08.14_17-01-59-+0800.xcresult` |
| 目的地 | `platform=macOS`，xcodebuild 选用本机 **arm64**（同时列出 x86_64 目的地但未跑） |

| 套件 | 通过 | 失败 |
|------|------|------|
| DomainTests | 94 | 0 |
| InfrastructureTests | 236 | 0 |
| AppTests | 36 | 0 |
| **合计** | **366** | **0** |

Task 0 基线 132 绿。本记录 366 绿是后续任务累加后的全量，不是「基线本来就 366」。

**既有失败：** 无。  
**非失败噪音（不计入失败）：** AppTests 连接 `com.apple.linkd.autoShortcut`、StatusBar / `NSHostedViewScene` 系统日志。与 Task 0 起同一类。

未使用真实 Provider Key。Provider 单测走 `HTTPClientMock` / fixture。

### 3.2 `tuist generate --no-open`

```bash
cd Apps/Mac && tuist generate --no-open
```

成功（约 0.4s）。警告：Tuist 提示 outdated dependencies / 可跑 `tuist install`（未执行，以免改锁文件）。

副作用：改写 `Apps/Mac/SmartBalance.xcworkspace/xcshareddata/xcschemes/Generate Project.xcscheme`。已按约定 **checkout 还原**，未提交。

### 3.3 Debug / Release 构建

```bash
xcodebuild build -workspace SmartBalance.xcworkspace -scheme SmartBalance \
  -configuration Debug -destination 'platform=macOS'
xcodebuild build -workspace SmartBalance.xcworkspace -scheme SmartBalance \
  -configuration Release -destination 'platform=macOS'
```

| 配置 | 结论 | 产物 | lipo | Info.plist |
|------|------|------|------|------------|
| Debug | `** BUILD SUCCEEDED **` | `…/Build/Products/Debug/智余.app` | arm64 | 0.3.1 / 82 |
| Release | `** BUILD SUCCEEDED **` | `…/Build/Products/Release/智余.app` | x86_64 + arm64 | 0.3.1 / 82 |

签名：Sign to Run Locally。Release 有「未设 App Category」警告，不视为构建失败。

**未执行：** `scripts/package-release.sh`、`scripts/release.sh`、公证、把 Debug/Release app 拷进 `/Applications`。

### 3.4 `git diff --check` / 工作区

验证命令执行后（还原 Generate scheme）：

- `git diff --check` 通过
- `git status --short` 干净（未把 derived data、诊断 zip、临时下载、真实凭据纳入仓库）
- `.superpowers/` 仍为本地 ignored 目录
- 仓库内既有 `releases/Mac/v0.3.1/SHA256SUMS.txt` 等是历史发布记录，不是本次新产物

---

## 4. 隔离 Application Support / Logs 运行时

**方法：** 用 Debug 产物里的 `Domain.framework` / `Infrastructure.framework` 编译一次性 runner（仅 `/tmp`，不进 git），目录全部指向 `/tmp/sb-task11-isolated/runtime/`。`AppLog.directoryOverride` 指向隔离 Logs。

**刻意没有做：** 启动本工作树 `智余.app`。本机已有 `/Applications/智余.app` 在跑；且真实 `settings.json` 仍是 v0，启动本分支会迁移用户文件。

隔离跑之前后，真实目录 mtime 未变：

- `~/Library/Application Support/SmartBalance/{settings.json,usage-history.json,secrets.vault}`
- `~/Library/Logs/SmartBalance/{app.log,update.log}`

### 4.1 检查矩阵

| 场景 | 证据层 | 结果 |
|------|--------|------|
| 首次启动（空目录） | 隔离服务 | `FirstLaunchStore.load() == missing` 且无账号 → `SessionRoute.onboarding` |
| 已有设置启动 | 隔离服务 | 载入 fixture 账号后 `shouldSeedCompletedState` → `SessionRoute.home` |
| 设置迁移 | 隔离服务 | v0 → `schemaVersion=1` 信封；账号保留；写出 `*-schema-migration` 快照（0600） |
| 未知字段 | 隔离服务 | 读回再保存后 `extensions` 仍在 |
| 导出 v2 | 隔离服务 | `format=smartbalance.portable-settings` / v2；无 `secrets` / `secretRef` / `passwordRef` / Bearer / api_key；文件 0600 |
| 本机恢复包 | 隔离服务 | `format=smartbalance.local-restore` / v2；无 `secrets` / `secretRef` / `passwordRef` |
| 导入恢复 | 隔离服务 | `RestoreOutcome.succeeded`，`credentialsNeedReentry=true`，新 `secretRef` ≠ 旧 fixture 引用 |
| 旧 v1 明文备份 | 隔离服务 | 识别为 legacy；默认 `cancelled`，不导入 secrets |
| 诊断 JSON/TXT/ZIP | 隔离服务 | 0600；Keychain 只报 `available`；providers 仅 kind/enabled/hasCredentialRef |
| Safe mode | 隔离服务 | 两次 unclean 后 `enterSafeMode`；refresh / 凭据读 / 通知授权 / SMTP / 更新安装全部 false；continue 保留 ledger |
| 取消刷新 | 隔离服务 | 假延迟 fetcher（无 Provider 网络）；取消后仍保留 amount=15 |
| 用量 日/周/月 | 隔离服务 | 见 4.2；算法与 fixture 一致 |
| 检查更新 | 脚本化 `UpdateChecker.check()` | GitHub `releases/latest` 返回 **upToDate / 0.3.1**，`downloadURL` 空。**未下载、未安装、未点 UI 确认** |
| 无 Touch ID / 密码门禁 | 源码 + 隔离探测 | 见 §6 |
| 菜单栏弹层点按 | — | **当前机器未做交互验收** |
| VoiceOver / 键盘 / 减弱动态效果 | — | **当前机器未做交互验收** |
| 合盖 sleep/wake / Instruments | — | **未执行** |
| 真实 Provider 余额 / SMTP | — | **未执行** |

### 4.2 用量日/周/月（隔离）

fixture：`2026-08-10` CNY 3.5；`2026-08-09` USD 1.25（周日）。

| 周期 | 锚点（上海） | 结果 |
|------|--------------|------|
| 日 | 2026-08-10 | CNY=3.5 |
| 周 | 2026-08-09 | USD=1.25（含周日所在 ISO 周） |
| 周 | 2026-08-10 | CNY=3.5（周一新周，不含 08-09） |
| 月 | 2026-08-10 | CNY=3.5, USD=1.25 |

这与冻结口径（ISO 周一开始、分币种）一致。用量页分段控件 **未在弹层里点过**。

### 4.3 诊断包扫描（只记位置与类别）

`/tmp/.../exports/diagnostics/smartbalance-diagnostics.{json,txt,zip}` 命中 `Bearer` / `Cookie` / `password` / `secret` / `api_key` 的位置属于 **`excludedFields` 允许名单字段名**，不是凭据值。  
`keychainStatus=available`；无 Keychain service/account/length；无 `secretRef` 值。

隔离生成的 `settings.json` / 内部 `*-schema-migration` 仍含 `secretRef` / `passwordRef` **键**（设置文档允许引用键）。v2 便携包和诊断包不含这些引用字符串。内部快照不是「v2 迁移包」。

---

## 5. 真实渠道 / 更新 / 发布

| 项 | 状态 |
|----|------|
| 真实 Provider Key 自动化 | **未执行** |
| 真实余额请求 | **未执行** |
| 真实 SMTP | **未执行** |
| 脚本化检查更新 | 已执行：公开 GitHub API，当前 latest = 0.3.1，未下载 |
| UI「检查更新 → 说明 → 确认 → 下载 → 安装」 | **当前机器未做交互验收** |
| dmg/pkg 新包 | **未执行** |
| GitHub Release / tag / push | **未执行** |
| 用户验收 | **未执行** |

---

## 6. 无密钥弹窗路径（启动 / 保存 / 诊断 / 迁移 / 恢复 / safe mode）

| 检查 | 证据 | 结论 |
|------|------|------|
| `SecAccessControl` / `kSecAttrAccessControl` / `LAContext` / `evaluatePolicy` | `Apps/Mac/Sources` 无调用 | 源码层无生物识别门禁 |
| `Touch ID` 文本 | 仅 `LocalSecretStore.swift:8`「不使用」注释 | 不是调用 |
| 写入可达性 | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` + 普通 generic password | 与契约 2.2 一致 |
| 隔离探测 | `LocalSecretStore.availabilityStatus()` → `available`（写入后删除 probe 项，值仅为 `"probe"`） | 未观察到授权 API；**不能**代替真人盯着钥匙串对话框 |
| Safe mode | `RecoveryLaunchPolicy` 在 `.safeMode` 关闭 refresh / 凭据读 / 通知授权 / SMTP / 更新安装 | 代码 + 隔离 beginSession |
| 恢复 | `RestoreCoordinator` 文档与实现：不读不写 Keychain；导入换新 ref | 隔离 restore 成功且 `credentialsNeedReentry` |
| 启动本工作树 app | **未执行**（避免迁移用户 v0 设置、避免与已运行实例冲突） | 启动弹窗：**当前机器未做交互验收** |

---

## 7. 隐私扫描（仓库；只记位置）

范围：本计划触及的 Sources / Tests / fixtures / 文档。**不把匹配值写入本文件。**

- 命中 `Bearer` / `Cookie` / `password` / `secret` / `api_key` 的位置主要是：字段名、红actor 禁止表、L10n、测试断言、Provider 组 header 名、Chrome Cookie **路径**、fixture 键名。
- Fixture 占位：`Apps/Mac/Tests/Fixtures/CommonCapabilities/legacy-secret-backup-v1.json` 使用 `REDACTED_TEST_TOKEN` 与 `example.test`。
- 测试里的 `sk-test-…` / `Bearer secret-token` / `fake-*` 为假值，供红actor 与 mock 使用。
- **未发现** 真实 API Key、真实 Cookie、真实 SMTP 密码、诊断 zip、下载安装包进入 git。
- 用户本机 `secrets.vault` / Keychain **不在仓库内**。

---

## 8. P1 任务红灯 / 绿灯

| Task | 实现提交（摘要） | 全量测试（任务报告） | 独立审查 | 停放给 Task 11 的项 |
|------|------------------|----------------------|----------|---------------------|
| 0 契约 | `5537026` docs | 132 绿 | Approved | — |
| 1 迁移 / v2 | `fc05e44` | 报告绿 | Approved | 快照留存等 minor |
| 2 首次启动 | `e8b765f` | 报告绿 | 初审 Needs fixes → rereview **APPROVED** | 弹层交互 |
| 3 刷新 | `f128340` | 报告绿 | 初审 Needs fixes → rereview 代码项 FIXED | 弹层交互仍 OPEN |
| 4 诊断 | `cd95f2b` | 230 绿 | follow-up 后 Important FIXED | 弹层 |
| 5 迁移恢复 | `b7ee9fd` | 252 绿 | rereview-2 **PASS** | 弹层 |
| 6 手动更新 | `b2efd55` | 297 绿 | rereview-1 **PASS** | UI 确认链 |
| 7 安全模式 | `3d78676` | 319 绿 | Accept | AppModel 未 live 实例化 |
| 8 兼容/用量 | `49a29e8` | 335 绿 | Pass，非阻断 | 弹层 |
| 9 帮助/无障碍 | `00c8745` | 350 绿 | rereview-1 **PASS** | 现场 VO/键盘 |
| 10 生命周期 | `416bf34` | 366 绿 | rereview-1 **PASS** | Instruments / 合盖 |
| 11 本记录 | 文档提交（本文件） | **366 绿复跑** | 本地审查见 §10；SDD 父审查待控制器 | 见 §5–§6 未做项 |

「所有 P1 任务代码审查的阻断项已关闭」——按既有 `task-*-review.md` / `task-*-rereview-*.md`。  
「可以进入项目既有发版流程」——**条件未满足**：缺交互验收、缺安装包、缺用户要求发版。本记录 **不授权** 跑 `release.sh`。

---

## 9. Definition of Done 对照

### 功能

| 条 | 代码入口 | 本记录 |
|----|----------|--------|
| 首次启动 / 兼容性 / 取消去重 / 诊断 / 迁移 / 恢复 / 手动更新详情 / 安全模式 / 帮助 / 无障碍 | 有对应 View + 服务 | 入口存在于源码；**弹层未点** |
| 首页 / 用量 / 设置、齿轮与用量语义 | `MenuRootView` / `MenuNavigationTests` | 单测绿；**交互未做** |
| 余额协议 / 通知 / SMTP / 日周月口径 | Provider 与 Usage 测试 + 隔离摘要 | 口径无未记录改写；**真实渠道未执行** |

### 数据安全

| 条 | 本记录 |
|----|--------|
| 新 v2 / 诊断 / 本机恢复不含密钥值 | 隔离导出已扫；内部 settings 快照仍可有 **引用键** |
| 无 Touch ID / 密码授权 API | 源码扫描通过；启动弹窗未做交互 |
| 迁移/恢复/重置先快照；不删 Keychain | 隔离 restore 有 snapshot 文件；reset 路径有单测，未对人机点「重置」 |

### 质量

| 条 | 本记录 |
|----|--------|
| 三套件全绿 | 366 / 0 |
| Debug + Release | 通过 |
| `git diff --check` + 无意外秘密产物 | 通过 |
| 目标环境运行时人工检查 | **当前机器**隔离检查；弹层 / 第二台机器 **未做** |

### 发布边界

本计划执行完 **没有** 自动推送或创建 Release。版本仍以 Info.plist **0.3.1 / 82** 为准。

---

## 10. 本地代码审查（requesting-code-review）

范围：`0067a94..416bf34` 产品代码 + 本验证文档。只读对照契约与既有 task review。未再改产品代码。

### Strengths

1. P1 拆成可测服务（FirstLaunch / RefreshCoordinator / Diagnostics / Transfer / Restore / Update check-only / CrashRecovery / Lifecycle），`AppModel` 仍是状态中心但不再独占这些格式。
2. 密钥边界从备份 v1 收敛到 portable v2；诊断 allowlist；普通 Keychain；测试用 fixture 假值。
3. 检查更新在本树是 check → details → confirm，不再把「检查」直接变成下载安装（相对 0.3.1 基线行为）。
4. 用量口径未重写；日/周/月隔离结果与 fixture 一致。
5. 任务 0–10 阻断审查项都有 fix + rereview 记录。

### Issues

#### Critical

无新发现的必须立刻改代码的缺陷（基于审查记录 + 本次复跑测试/构建）。

#### Important（发布门，不是本任务漏改）

1. **菜单栏弹层仍未在本机点过。** 首次启动、取消刷新、用量切换、帮助/VO、更新确认链、safe mode 卡片都只有单测或隔离服务证据。
2. **未做安装包与用户验收。** 不能把 Debug/Release `BUILD SUCCEEDED` 写成已交付安装。
3. **真实渠道未授权、未跑。**
4. **合盖 sleep / Instruments / 第二架构运行时未做。**

#### Minor

1. 本机用户 `settings.json` 仍是 v0；下次用本分支启动会迁移——需在真正试装前备份。
2. Release fat binary 不能写成「Intel 已验证」。
3. `tuist generate` 仍会脏 `Generate Project.xcscheme`。
4. AppModel 仍未在 AppTests 里 live 实例化（各任务已记录）。

### Assessment

**Ready to merge to main / ship? No.**  
**Ready to close P1 implementation worktree pending controller review? Yes, with the gaps above explicitly unfinished.**

P2（Beta 通道、自动更新、匿名诊断上传）按计划阻断条件 **未立项、未实现**。

---

## 11. 复现

```bash
cd Apps/Mac
./scripts/run-tests.sh
tuist generate --no-open   # 然后还原 Generate Project.xcscheme
xcodebuild build -workspace SmartBalance.xcworkspace -scheme SmartBalance \
  -configuration Debug -destination 'platform=macOS'
xcodebuild build -workspace SmartBalance.xcworkspace -scheme SmartBalance \
  -configuration Release -destination 'platform=macOS'
git diff --check
git status --short
```

隔离 runner 不在仓库内；需要时用 Debug 的 Domain/Infrastructure 静态库对临时目录复跑，**不要**把输出 zip 提交进 git。
