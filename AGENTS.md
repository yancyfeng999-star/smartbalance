# 智余 · Agent 协作说明

> **给所有 AI / 自动化 Agent 看的入口。**  
> 人类用户不会反复交代「推 GitHub / 我来升版」——默认你做完就发版上线。

详细流程见：[docs/AGENT_RELEASE_WORKFLOW.md](./docs/AGENT_RELEASE_WORKFLOW.md)

---

## 1. 默认行为（铁律）

| 场景 | Agent 必须做 | 不要做 |
|------|----------------|--------|
| 修 bug / 小功能做完 | **直接** `NOTES="…" ./scripts/release.sh` 发版上 GitHub | 问用户「要不要推？」「要不要升版？」 |
| 用户说「上传 / 整理好 / 推送」 | 走完整发版（升版 + 包 + tag + PR） | 只 commit 不发版，把升版甩给用户 |
| 仅改文档 / 无产品变更 | commit + `git push origin main` 即可 | 不必为纯文档升版本号 |
| 用户明确说「不要发版 / 先别推」 | 遵守，本地改完停住 | — |

**用户侧：** 设置 → 检查更新，或从  
https://github.com/yancyfeng999-star/smartbalance/releases  
装新包。**不要**让用户自己跑 `release.sh`、自己填版本，除非用户主动要求。

---

## 2. 仓库与路径

| 项 | 值 |
|----|-----|
| 本地根目录 | `…/自研软件/智余` |
| 远程 | `https://github.com/yancyfeng999-star/smartbalance.git` |
| 默认分支 | `main`（本仓库历史直接在 main 发版，沿用此习惯） |
| Mac 工程 | `Apps/Mac/`（Tuist + Xcode，Scheme `SmartBalance`） |
| 一键发版 | `Apps/Mac/scripts/release.sh` |
| 当前产品版本 | 以 `Apps/Mac/Sources/App/Info.plist` 的 `CFBundleShortVersionString` 为准；README 表头会随发版更新 |

本机数据（排障用，**勿提交**）：

| 内容 | 路径 |
|------|------|
| 设置 | `~/Library/Application Support/SmartBalance/settings.json` |
| 密钥 | macOS Keychain service `com.smartbalance.zhiyu.plain` |
| 日志 | `~/Library/Logs/SmartBalance/app.log` |

---

## 3. 标准交付闭环

```text
查清问题 → 改代码 → 本地编译通过
    → git commit（清晰说明）
    → cd Apps/Mac && NOTES="一句话中文变更" ./scripts/release.sh
    → 回报：版本号 + Release 链接
```

`release.sh` 会自动：

1. patch 升版（`0.2.x` → 下一 patch；可用 `minor` / 指定版本）
2. Tuist generate + Release 打包 dmg/pkg
3. 写 CHANGELOG 段、提交 `release: x.y.z (build n)`
4. `git push` + tag `vX.Y.Z`
5. `gh release create` 上传 `SmartBalance-*.dmg` / `.pkg` / `SHA256SUMS.txt`

发版前若有**未提交的功能修复**，先单独 commit，再跑 `release.sh`（脚本会再提交版本与 notes）。

---

## 4. 常用命令

```bash
# 仓库根
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/智余"

# 编译检查
cd Apps/Mac
xcodebuild -scheme SmartBalance -configuration Debug \
  -derivedDataPath ./build/DerivedData build

# 正式发版（默认 patch，并上 GitHub）
NOTES="修复 xxx" ./scripts/release.sh

# 仅打包、不推远程（调试用）。打完只留 dmg/pkg，不要再装一份 App。
SKIP_PUBLISH=1 NOTES="试包" ./scripts/release.sh

# 测试（测完会清掉 DerivedData 里的 智余.app）
./scripts/run-tests.sh

# 清掉启动台/聚焦里的重复入口，只留 /Applications/智余.app
./scripts/cleanup-duplicate-apps.sh
```

需要 `gh` 已登录（`gh auth status`），且对 `yancyfeng999-star/smartbalance` 有写权限。

---

## 5. 架构速查

```text
Apps/Mac/Sources/
  Domain/           # 模型：账号、快照、主题、SMTP 设置…
  Infrastructure/   # Provider、SMTPClient、密钥、更新检查
  App/              # MenuBarExtra、AppModel、SwiftUI
    AppModel.swift  # 状态中枢
    Views/HomeView / BalanceCardView / MenuRootView
    Views/Settings/ # 外观、语言、账号、报警、SMTP
    Theme.swift     # SBTheme 动态色（依赖 NSApp.appearance）
```

- 入口：`SmartBalanceApp` → `MenuBarExtra` → `MenuRootView`
- 首页卡片顺序 = `settings.accounts` 启用顺序
- 「打开后台」= 当前 `selectedAccountId` 的 `resolvedConsoleURL`
- 外观：`setThemeMode` → `applyAppearancePreference()`（`NSApp` + window appearance）

---

## 6. 已知坑（排障优先看日志）

### 6.1 首页卡片高亮 / 打开后台总是第一个

- **原因（已修于 0.2.17）：** 曾写死 `emphasized: index == 0`，`openDashboard()` 用 `enabledAccounts.first`
- **正确：** `selectedAccountId`；点卡 `selectAccount`；`openDashboard()` 用选中账号

### 6.2 浅色 / 深色点击「没反应」

- **原因（已修于 0.2.18）：** 只设了 `preferredColorScheme`，`SBTheme` 的 `NSColor` 动态色仍跟系统
- **正确：** `setThemeMode` 必须 `NSApp.appearance` + 各 `window.appearance`，并强制壳重绘
- **验证：** `settings.json` 里 `themeMode` 是否为 `light`/`dark`/`system`

### 6.3 邮件发送失败「操作超时（10s）」

- 常见：**代理 Fake-IP**（`smtp.gmail.com` → `198.18.x.x`），SMTP 直连 TLS 挂死
- 配置：Gmail 建议 **465 + TLS** + **应用专用密码**；本版 **不支持 587 STARTTLS**
- 日志：`~/Library/Logs/SmartBalance/app.log` 搜 `SMTP` / `邮件`

### 6.4 密钥 / 密码

- API Key、Cookie、SMTP 密码在 macOS 普通 Keychain，不在 git；旧版明文备份只在用户确认后导入
- 日志出现 `Secret unlock failed` / `缺少 SMTP 密码` → 引导用户在设置里重新保存

---

## 7. 改代码约定

- 少改无关文件；发版脚本会带上 Sources，但 **不要** 把 `build/`、本机密钥提交进库
- 中文用户面向文案优先；代码注释可中英
- Commit message：`fix:` / `feat:` / `chore:` + 一句说清楚
- 发版 NOTES 用**中文短句**，会出现在 CHANGELOG / Release notes

---

## 8. 完成后怎么跟用户说

```text
已发版 0.2.x（build n）
Release: https://github.com/yancyfeng999-star/smartbalance/releases/tag/v0.2.x
应用内「检查更新」或装 dmg 即可。
```

**不要**再写：「请你本地升版 / 请你自己 push / 需要的话我可以帮你发版」。

---

## 9. 相关文档

| 文档 | 内容 |
|------|------|
| [docs/AGENT_RELEASE_WORKFLOW.md](./docs/AGENT_RELEASE_WORKFLOW.md) | 发版逐步流程与检查清单 |
| [docs/USER_GUIDE.md](./docs/USER_GUIDE.md) | 终端用户说明 |
| [README.md](./README.md) | 产品与构建入口 |
| [PRODUCT.md](./PRODUCT.md) | 产品定义 |
| [CHANGELOG.md](./CHANGELOG.md) | 版本历史 |
| [PROJECT_STATUS.md](./PROJECT_STATUS.md) | 阶段状态（发版后可随手更新版本号） |
