# 智余 · SmartBalance

macOS 菜单栏应用：查询各平台 **API / Token 余额**，偏低时 **Mac 通知 + 邮件报警**。

| | |
|--|--|
| 平台 | macOS 15+ |
| 形态 | 菜单栏（无 Dock） |
| 版本 | 0.2.0 |

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
| 手录 | 小米 MiMo · MiniMax |

ViralTok 吉米币×7.3、老张 USD×7 → **人民币** 展示与报警。

---

## 构建 / 打包

```bash
cd Apps/Mac
tuist generate
open SmartBalance.xcworkspace

# Release 打包 → DMG + PKG（对齐智额）
./scripts/package-release.sh 0.2.0
```

输出：

| 文件 | 用途 |
|------|------|
| `releases/Mac/v0.2.0/智余-0.2.0.dmg` | **推荐**：打开后拖进 Applications |
| `releases/Mac/v0.2.0/智余-0.2.0.pkg` | 双击安装向导 |
| `SmartBalance-0.2.0.dmg` / `.pkg` | 英文名，适合 GitHub Release |
| `~/Desktop/智余-发布/` | 同上副本 |
| `~/Desktop/智余.app` | 本机立刻试跑 |

测试：`./scripts/run-tests.sh`

---

## 更新（GitHub Releases）

与智额相同思路（**无 Sparkle 静默装**）：

1. 推送代码到 `github.com/yancyfeng999-star/smartbalance`
2. 创建 Release `v0.2.0`，上传 `SmartBalance-0.2.0-macOS.zip`
3. 设置 → **检查更新** → 有新版本则**自动下载到「下载」文件夹 → 打开 → 退出应用**，便于替换安装

---

## 本机数据

| 内容 | 路径 |
|------|------|
| 设置 | `~/Library/Application Support/SmartBalance/settings.json` |
| 密钥 | `…/secrets.vault`（0600，会话指纹解锁） |

---

## 文档

- [PRODUCT.md](./PRODUCT.md)
- [PROJECT_STATUS.md](./PROJECT_STATUS.md)
- [CHANGELOG.md](./CHANGELOG.md)
- [docs/USER_GUIDE.md](./docs/USER_GUIDE.md)
- [Apps/Mac/README.md](./Apps/Mac/README.md)
