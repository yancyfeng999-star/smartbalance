# 智余 · SmartBalance

macOS 菜单栏应用：查询各平台 **API / Token 余额**，偏低时 **Mac 通知 + 邮件报警**。

| | |
|--|--|
| 平台 | macOS 15+ |
| 形态 | 菜单栏（无 Dock） |
| 对照 | [智额 SmartQuota](../智额/) 看会员额度；智余看 API 余额 |

---

## 仓库结构

```text
.
├── README.md                 # 本文件
├── PRODUCT.md                # 产品说明
├── PROJECT_STATUS.md         # 实现状态
├── docs/USER_GUIDE.md        # 用户指南
└── Apps/Mac/                 # 全部源码（Tuist + Swift 6）
    ├── Sources/
    │   ├── Domain/           # 模型、阈值、ProviderKind
    │   ├── Infrastructure/   # 网络、密钥库、SMTP、各平台 Provider
    │   └── App/              # SwiftUI 主页 / 设置 / 置顶窗
    ├── Tests/
    ├── scripts/
    └── Project.swift
```

---

## 支持的平台

| 方式 | 平台 |
|------|------|
| API Key | DeepSeek · OpenRouter · Kimi · ViralTok · 老张 API |
| 系统令牌 + 用户 ID | New-API 中转 · DMXAPI |
| AK / SK 签名 | 火山引擎（费用中心 QueryBalanceAcct） |
| 手录 + 每日提醒 | 小米 MiMo · MiniMax |

---

## 构建与运行

```bash
cd Apps/Mac
tuist generate
open SmartBalance.xcworkspace
# Xcode 选择 SmartBalance → Run

# 或一键打 Release 到桌面
./scripts/build-test-app.sh
open ~/Desktop/智余.app
```

测试：

```bash
cd Apps/Mac && ./scripts/run-tests.sh
```

---

## 本机数据

| 内容 | 路径 |
|------|------|
| 设置 | `~/Library/Application Support/SmartBalance/settings.json` |
| 密钥 | `~/Library/Application Support/SmartBalance/secrets.vault`（0600） |

密钥不写入设置文件、不上传。首次读密钥时可用指纹 / 本机密码解锁会话。

---

## 文档

- [PRODUCT.md](./PRODUCT.md) — 产品定位与范围  
- [PROJECT_STATUS.md](./PROJECT_STATUS.md) — 功能清单与验收  
- [docs/USER_GUIDE.md](./docs/USER_GUIDE.md) — 上手与 FAQ  
- [Apps/Mac/README.md](./Apps/Mac/README.md) — 架构与扩展 Provider  
