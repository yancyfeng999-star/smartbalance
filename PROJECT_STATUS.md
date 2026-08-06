# 项目状态

**更新：** 2026-08-06  
**阶段：** 基本功能完成，可供本机日常使用  

---

## 已完成

| 模块 | 内容 |
|------|------|
| 菜单栏弹层 | 固定 380×580；主页 / 设置同壳 |
| 置顶窗 | 图钉常驻 |
| API 平台 | DeepSeek · New-API · OpenRouter · ViralTok · 老张 · DMXAPI · Kimi · **火山引擎** |
| 手录 | MiMo · MiniMax · 每日提醒 |
| 报警 | Mac 通知 · SMTP · 冷却 · 测试按钮 |
| 密钥 | `secrets.vault` + 会话生物识别 |
| 单测 | 阈值、各 Provider mock、SMTP 格式、火山签名 |

---

## 源码布局

```text
Apps/Mac/Sources/
  Domain/                 # 模型与规则
  Infrastructure/
    Providers/            # 各平台 *BalanceProvider
    LocalSecretStore.swift
    BalanceService.swift
    SMTPClient.swift
    …
  App/
    Views/                # 主页、卡片、弹层壳
    Views/Settings/       # 设置
```

---

## 手工验收（真密钥）

| # | 场景 | 状态 |
|---|------|------|
| 1 | DeepSeek / Kimi / OpenRouter | ⏳ |
| 2 | New-API（Base + 令牌 + UID） | ⏳ |
| 3 | 火山 AK/SK | ⏳ |
| 4 | DMXAPI / 老张 | ⏳ |
| 5 | 手录 + 每日通知 | ⏳ |
| 6 | 阈值 → Mac 通知 | ⏳ |
| 7 | SMTP 测试信 | ⏳ |
| 8 | 主页 ↔ 设置不跳窗 | ⏳ |

---

## 已知限制

1. SMTP 仅 465 隐式 TLS（无 587 STARTTLS）  
2. 无 Dock 图标（`LSUIElement`）  
3. 本地 ad-hoc 签名，外发需自行公证  
