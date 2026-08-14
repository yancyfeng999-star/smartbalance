# 智余 · SmartBalance

macOS 菜单栏应用：查询各平台 **API / Token 余额**，在本机按 **天 / 周 / 月**统计各渠道消费金额，偏低时 **Mac 通知 + 邮件报警**。

| | |
|--|--|
| 平台 | macOS 15+ |
| 形态 | 菜单栏（无 Dock） |
| 版本 | 0.4.0 |
| 验证 | 见 [docs/superpowers/verification/2026-08-14-mac-common-capabilities-verification.md](docs/superpowers/verification/2026-08-14-mac-common-capabilities-verification.md)。已实现 ≠ 本地测试 ≠ 运行时验证 ≠ 已发布 ≠ 用户验收 |

---

## 仓库结构（对齐智额）

```text
智余/
├── README.md
├── PRODUCT.md
├── PROJECT_STATUS.md
├── CHANGELOG.md
├── LICENSE
├── Branding/                 # 品牌图
├── docs/USER_GUIDE.md
├── releases/                 # 发布 zip（本地打包输出）
└── Apps/Mac/                 # Tuist + Swift 6
    ├── Sources/
    │   ├── Domain/
    │   ├── Infrastructure/   # Provider、密钥库、SMTP、GitHub 更新
    │   └── App/
    ├── Tests/
    ├── scripts/
    │   ├── package-release.sh
    │   ├── build-test-app.sh
    │   └── run-tests.sh
    └── Project.swift
```

---

## 支持的平台

| 方式 | 平台 |
|------|------|
| API Key | DeepSeek · OpenRouter · Kimi · ViralTok · 老张 API |
| 令牌 + 用户 ID | New-API · DMXAPI |
| AK/SK | 火山引擎 |
| 控制台 Cookie（Chrome 一键导入） | 小米 MiMo · MiniMax · apinebula |

ViralTok 吉米币×7.3、老张 USD×7 → **人民币** 展示与报警。

## 本地用量统计

首页底栏点“用量”，可以查看：

- 本地自然天、ISO 自然周（周一开始）和自然月的渠道金额，并向前查看最多 400 天；
- 接口累计值的精确差额，以及无累计字段渠道的余额下降估算；
- 按 CNY、USD 和未知单位分别生成的总额、趋势图和渠道明细；
- 用量页/诊断显示历史可用、需要恢复或最近保存失败，不把历史文件内容展示给用户。

首次成功刷新只建立基线，因此不会补算安装前或启用前的历史消费。充值、累计值重置、密钥或用户 ID 变化、单位或统计方式变化会重建基线，不会产生负消费；跨日未刷新产生的差额统一归入后一次刷新日期并显示提示。

所有统计只写入本机 `usage-history.json`。文件不保存密钥、Cookie、访问令牌、请求头或 Provider 响应正文。

---

## 构建 / 打包

```bash
cd Apps/Mac
tuist generate
open SmartBalance.xcworkspace

# 一键发版（每次都会升版本再上线）
./scripts/release.sh              # 0.2.0 → 0.2.1，打包 dmg/pkg 并上传 GitHub
./scripts/release.sh minor        # 升次版本
./scripts/release.sh 0.3.0        # 指定版本
NOTES="修复 xxx" ./scripts/release.sh

# 只打包不上传
SKIP_PUBLISH=1 ./scripts/release.sh
```

**维护者发布规则：** 正式版本统一走 `release.sh`，按顺序完成版本、测试、DMG/PKG、SHA256、提交、tag 和 GitHub Release。普通贡献者不需要直接发布或 push 生产版本；请先提交 Pull Request。

产物：

| 文件 | 用途 |
|------|------|
| `releases/Mac/vX.Y.Z/SmartBalance-X.Y.Z.dmg` | GitHub 主资产（拖进 Applications） |
| `…/SmartBalance-X.Y.Z.pkg` | 安装向导 |

发版只上传 GitHub Releases，**不复制到桌面**。需要本机副本时：`COPY_TO_DESKTOP=1 ./scripts/package-release.sh`。

**只认一个入口：** 正式版在 `/Applications/智余.app`（应用程序）。
若启动台/聚焦出现多个「智余」：

```bash
cd Apps/Mac && ./scripts/cleanup-duplicate-apps.sh
```

本地试装也请装到应用程序：`./scripts/build-test-app.sh`（不再放桌面）。

测试：`./scripts/run-tests.sh`（2026-08-14 本工作树复跑 366 passed / 0 failed；不含真实渠道）

---

## 更新（GitHub Releases）

产品版本以 Info.plist 为准（当前 **0.3.2 / 83**）。已发布包以 GitHub Releases 上的 tag 为准。

检查更新流程是手动确认，不会因为启动应用而静默替换：

1. 维护者发布带有版本说明和校验文件的 GitHub Release。
2. 用户进入设置 → **检查更新**，查看版本、说明和校验状态。
3. **用户明确确认**后才下载并安装；校验失败或用户取消时保留当前版本。

历史上部分已发布包曾在发现新版本后直接下载安装。不要把旧行为写成当前目标。

自动更新、Beta 通道和后台安装不属于当前默认能力。发版走 `Apps/Mac/scripts/release.sh`。

---

## 本机数据

| 内容 | 路径 |
|------|------|
| 设置 | `~/Library/Application Support/SmartBalance/settings.json` |
| 密钥 | macOS Keychain（普通条目，不启用指纹/密码门禁） |
| 用量历史 | `…/usage-history.json`（0600，本机记录，最多 400 天） |

---

## 开源、隐私与文档

智余源代码采用 [Apache License 2.0（Apache-2.0）](./LICENSE)。贡献前请阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)、[SECURITY.md](./SECURITY.md) 和 [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)。运行时依赖、图片、商标和外部代码的归属见 [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md)。

余额和用量数据默认留在本机；API Key、Cookie 和 SMTP 密码只进入普通 macOS Keychain，不应提交到仓库。完整数据边界见 [docs/DATA_AND_PRIVACY.md](./docs/DATA_AND_PRIVACY.md)。

## 项目文档

- **[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)** — 分层、数据流、持久化和更新边界
- **[docs/USER_GUIDE.md](./docs/USER_GUIDE.md)** — 安装、设置、报警和用量统计
- **[docs/PROVIDER_DEVELOPMENT.md](./docs/PROVIDER_DEVELOPMENT.md)** — 新增 Provider 的开发和测试要求
- **[docs/RELEASE_CHECKLIST.md](./docs/RELEASE_CHECKLIST.md)** — 开源发布、测试、构建和证据清单
- **[AGENTS.md](./AGENTS.md)** — 本地 Agent / 自动化协作规则
- **[docs/AGENT_RELEASE_WORKFLOW.md](./docs/AGENT_RELEASE_WORKFLOW.md)** — 维护者开发与发版逐步流程
- [PRODUCT.md](./PRODUCT.md)
- [PROJECT_STATUS.md](./PROJECT_STATUS.md)
- [CHANGELOG.md](./CHANGELOG.md)
- [Apps/Mac/README.md](./Apps/Mac/README.md)
- [docs/superpowers/verification/2026-08-14-mac-common-capabilities-verification.md](docs/superpowers/verification/2026-08-14-mac-common-capabilities-verification.md) — P1 验证证据（未发版）
