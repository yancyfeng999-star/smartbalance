# 智余 · Agent 开发与发版流程

本文写给**重新打开会话的 Agent**：按此流程即可独立交付，**无需用户重复说明「推 GitHub / 我来更新」**。

配套入口：[AGENTS.md](../AGENTS.md)

---

## 一、协作默认（必读）

### 用户期望

1. Agent **修完问题就上线**，用户只负责在 Mac 上**检查更新 / 装新包**。
2. **不要**让用户自己：
   - 改版本号
   - 跑打包脚本
   - `git push` / 建 GitHub Release
3. 除非用户明确说「先别发版」「只改本地」「不要推远程」。

### Agent 默认动作

| 完成度 | 动作 |
|--------|------|
| 产品代码变更（fix/feat） | **完整发版** → GitHub Release |
| 仅文档 / 注释 / Agent 说明 | `git commit` + `git push origin main`（可不升版本） |
| 编译都不过 | 禁止发版；修到能编过 |

**覆盖（`docs/superpowers/plans/2026-08-14-mac-common-capabilities.md`）：** 该计划执行期间（工作树 `.worktrees/mac-common-capabilities`，分支 `feat/mac-common-capabilities`）**不**跑 `release.sh`、**不** `git push`、**不**创建 GitHub Release，除非用户明确要求上传/发版。版本源仍是 `Apps/Mac/Sources/App/Info.plist`。验证证据见 `docs/superpowers/verification/2026-08-14-mac-common-capabilities-verification.md`。代码存在 ≠ 已发布。

---

## 二、环境前提

```bash
# 仓库
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/智余"
git remote -v   # origin → github.com/yancyfeng999-star/smartbalance.git
git branch      # 工作在 main

# GitHub CLI（发 Release 需要）
gh auth status
```

| 工具 | 用途 |
|------|------|
| Xcode / xcodebuild | 编译 |
| Tuist | `release.sh` 内会 `tuist generate` |
| `gh` | 创建 GitHub Release |
| git | 提交与 push |

本仓库发版习惯：**直接在 `main` 上 release 提交 + tag**（与历史一致）。不要为每次小修强制开 PR，除非用户要求。

---

## 三、开发循环

### 1. 定位问题

```bash
# 应用日志
tail -100 ~/Library/Logs/SmartBalance/app.log
rg -n "ERROR|SMTP|theme|邮件" ~/Library/Logs/SmartBalance/app.log | tail -40

# 用户设置（脱敏查看）
# ~/Library/Application Support/SmartBalance/settings.json
```

代码入口优先：

| 问题类型 | 优先文件 |
|----------|----------|
| 首页卡片 / 高亮 / 打开后台 | `HomeView` · `BalanceCardView` · `AppModel`（`selectedAccountId` / `openDashboard`） |
| 外观浅色深色 | `AppearanceSettingsCard` · `AppModel.setThemeMode` / `applyAppearancePreference` · `Theme.swift` · `MenuRootView` |
| 邮件报警 | `SMTPClient` · `BalanceService` · `SMTPSection` · `settings.email` |
| 余额 Provider | `Infrastructure/Providers/*` · `ProviderRegistry` |
| 菜单壳 / 尺寸 | `MenuRootView` · `PinnedOrPopoverChrome` · `PinnedBalanceWindow` |

### 2. 修改与验证

```bash
cd Apps/Mac
xcodebuild -scheme SmartBalance -configuration Debug \
  -derivedDataPath ./build/DerivedData build
# 或：./scripts/run-tests.sh
```

本地可直接跑 Debug 产物验证；**不要**把 `build/` 提交进 git。

### 3. 提交功能修复（发版前）

```bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/智余"
git add Apps/Mac/Sources/...   # 只加相关源码
git commit -m "fix: 一句话说明"
```

---

## 四、一键发版（主路径）

在 **`Apps/Mac`** 目录执行：

```bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/智余/Apps/Mac"

# 默认：patch 升版 + 打包 + push + 创建 PR
NOTES="修复……（中文，给用户看的）" ./scripts/release.sh

# 次版本
NOTES="……" ./scripts/release.sh minor

# 指定版本
NOTES="……" ./scripts/release.sh 0.3.0

# 只打包不上传（自测）
SKIP_PUBLISH=1 NOTES="试包" ./scripts/release.sh
```

### `release.sh` 内部顺序

```text
1) bump-version.sh     → Info.plist 版本 + build
2) package-release.sh  → Release 构建 → dmg/pkg → releases/Mac/vX.Y.Z/
3) 更新 CHANGELOG.md 头段（用 NOTES）
4) git commit "release: X.Y.Z (build N)"
5) git push origin release/X.Y.Z
6) git tag vX.Y.Z && push tag
7) gh pr create → 创建 PR 到 main
```

### 产物位置

```text
releases/Mac/vX.Y.Z/
  SmartBalance-X.Y.Z.dmg    ← GitHub 主资产（英文名）
  SmartBalance-X.Y.Z.pkg
  智余-X.Y.Z.dmg            ← 本地中文名副本
  智余-X.Y.Z.pkg
  RELEASE_NOTES.md
  SHA256SUMS.txt
```

默认**不复制到桌面**。正式安装路径：`/Applications/智余.app`。

### 后续步骤

```bash
# 1. 在 GitHub 上 Review 并 Merge PR
# 2. 运行 publish-release.sh 创建 GitHub Release
./scripts/publish-release.sh <version>
```

### 超时

完整发版常需 **1–3 分钟**（Release 编译 + 打 dmg）。Agent 侧命令超时建议 **≥ 10 分钟**。

---

## 五、发版检查清单

发版前：

- [ ] 功能/修复已 commit，或将由 `release.sh` 一并纳入 Sources
- [ ] Debug 或 Release 能编过
- [ ] `NOTES` 写清楚用户能看懂的变更
- [ ] 无密钥 / `settings.json` / 本机运行数据被 `git add`

发版后：

- [ ] `git status` 干净（或仅剩无关本地文件）
- [ ] 远程存在 tag `vX.Y.Z`
- [ ] https://github.com/yancyfeng999-star/smartbalance/releases/tag/vX.Y.Z 有 dmg/pkg
- [ ] 向用户回报：**版本号 + Release 链接**

---

## 六、用户如何更新（你只需告知，无需代劳）

1. 打开智余 → 设置 → **检查更新**（有新版本会下载并引导安装）  
2. 或打开 Release 页下载 `SmartBalance-X.Y.Z.dmg`，拖进「应用程序」

Agent **不需要**远程操控用户本机安装。

---

## 七、异常处理

| 现象 | 处理 |
|------|------|
| `gh` 未登录 | `gh auth login`；无法登录则 commit+push 后说明需人工建 Release |
| tag 已存在 | `release.sh` 会对同 tag force push tag 并删旧 Release 重建（脚本已有逻辑） |
| 打包失败 | 读 xcodebuild 日志；`SKIP_PUBLISH=1` 先修到打包成功再发 |
| 代理导致 SMTP 测不通 | 属环境问题，文档/回复说明 Fake-IP；勿当成代码必坏 |
| 工作区有 Tuist/pbxproj 噪声 | 能编过可随 release 提交；无关大 diff 勿强行塞进无关 fix |

---

## 八、会话交接模板（下一位 Agent 可复制）

```markdown
## 智余会话交接
- 仓库：github.com/yancyfeng999-star/smartbalance （main）
- 本地：…/自研软件/智余
- 当前版本：见 Info.plist / 最新 tag
- 默认：修完直接 NOTES=… ./scripts/release.sh，不要让用户升版
- 日志：~/Library/Logs/SmartBalance/app.log
- 设置：~/Library/Application Support/SmartBalance/settings.json
- 详见 AGENTS.md + docs/AGENT_RELEASE_WORKFLOW.md
- 未完成：
- 刚发版：
```

---

## 九、版本策略建议

| 变更 | 升版方式 |
|------|----------|
| bugfix、文案、小体验 | `./scripts/release.sh`（patch） |
| 明显功能块（新 Provider、新设置页） | `./scripts/release.sh minor` 或指定版本 |
| 纯 Agent/文档 | push main，**可不**升应用版本 |

保持 **CHANGELOG** 与 **Release notes** 同步（`NOTES` 会写入）。

---

## 十、相关脚本一览

| 脚本 | 作用 |
|------|------|
| `scripts/release.sh` | **唯一推荐上线入口** |
| `scripts/bump-version.sh` | 升版本（release 调用） |
| `scripts/package-release.sh` | 只打包 |
| `scripts/run-tests.sh` | 单测 |
| `scripts/build-test-app.sh` | 本地试装到 /Applications |
| `scripts/cleanup-duplicate-apps.sh` | 清理多余「智余」入口 |

---

**一句话：改完代码 → `NOTES="…" ./scripts/release.sh` → 把 Release 链接发给用户。**
