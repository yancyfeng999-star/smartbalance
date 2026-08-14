# 智余 · SmartBalance

macOS 菜单栏应用：查询各平台 **API / Token 余额**，在本机按 **天 / 周 / 月**统计各渠道消费金额，偏低时 **Mac 通知 + 邮件报警**。

| | |
|--|--|
| 平台 | macOS 15+ |
| 形态 | 菜单栏（无 Dock） |
| 版本 | 0.3.1（Info.plist / build 82；本工作树未另发 GitHub Release） |

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

**规则：每次上线必须走 `release.sh`，自动：升版本 → 打 dmg/pkg → 提交 → tag → GitHub Release。**

**Agent 默认：** 功能/修复做完后直接发版上 GitHub，**不要**让用户自己升版或 push。详见 [AGENTS.md](./AGENTS.md)。

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

测试：`./scripts/run-tests.sh`

---

## 更新（GitHub Releases）

产品版本以 Info.plist 为准（当前 **0.3.1 / 82**）。已发布包以 GitHub Releases 上的 tag 为准。

**当前代码（本工作树，尚未作为新 Release 发布）** 的检查更新流程是：

1. 设置 → **检查更新**
2. 查看版本说明
3. **用户明确确认**后才下载
4. 校验校验和 / 包
5. 再安装（不是启动后静默替换）

历史上部分已发布包曾在发现新版本后直接下载安装。不要把旧行为写成当前目标。

发版仍走 `Apps/Mac/scripts/release.sh`。**本通用能力计划执行期间默认不发版、不 push。**

---

## 本机数据

| 内容 | 路径 |
|------|------|
| 设置 | `~/Library/Application Support/SmartBalance/settings.json` |
| 密钥 | macOS Keychain（普通条目，不启用指纹/密码门禁） |
| 用量历史 | `…/usage-history.json`（0600，本机记录，最多 400 天） |

---

## 文档

- **[AGENTS.md](./AGENTS.md)** — AI / 自动化协作入口（默认修完即发版上 GitHub）
- **[docs/AGENT_RELEASE_WORKFLOW.md](./docs/AGENT_RELEASE_WORKFLOW.md)** — 开发与发版逐步流程
- [PRODUCT.md](./PRODUCT.md)
- [PROJECT_STATUS.md](./PROJECT_STATUS.md)
- [CHANGELOG.md](./CHANGELOG.md)
- [docs/USER_GUIDE.md](./docs/USER_GUIDE.md)
- [Apps/Mac/README.md](./Apps/Mac/README.md)
