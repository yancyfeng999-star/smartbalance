# 智余架构说明

## 产品边界

智余（SmartBalance）是 macOS 15+ 菜单栏应用，用于查询用户配置的 AI/API 渠道余额，并在本机按自然日、ISO 周和自然月统计渠道消费金额。它不提供云账号、云同步或默认遥测。

## 模块分层

```text
Domain → Infrastructure → App
```

### Domain

位置：`Apps/Mac/Sources/Domain/`

包含账号、Provider 类型、余额快照、状态、报警配置、主题/语言、应用设置和用量模型。`UsageAccumulator` 负责相邻成功采样之间的消费差额规则，`UsageSummaryBuilder` 负责日/周/月汇总。

### Infrastructure

位置：`Apps/Mac/Sources/Infrastructure/`

包含：

- `ProviderRegistry` 和各 `*BalanceProvider`：发起渠道余额请求并转换为 Domain 快照；
- `HTTPClient`：网络请求和测试注入边界；
- `LocalSecretStore`：普通 macOS Keychain，存放 API Key、Cookie 或 SMTP 密码；
- `SettingsStore`：保存非密钥设置 JSON；
- `UsageHistoryStore`：保存本地用量历史；
- `MacNotificationService`、`SMTPClient`：通知和邮件报警；
- `UpdateChecker`、`ReleaseDownloader`、`PackageSilentInstaller`：GitHub Releases 检查、下载和用户确认后的安装流程；
- `AppLog`：本地日志。

Infrastructure 不应把密钥、完整请求头、原始响应正文或密码交给 UI 层。

### App

入口：`Apps/Mac/Sources/App/SmartBalanceApp.swift`

`SmartBalanceApp` 创建菜单栏场景，`AppDelegate` 对接 AppKit 生命周期，`AppModel` 作为 `@MainActor` 状态中心，`MenuRootView` 提供首页、用量和设置三段导航。菜单内容保持约 `380×580` 固定外壳，右上角齿轮进入设置，底部用量入口进入统计。

## 数据流

```text
用户点击刷新/定时刷新
        ↓
AppModel → ProviderRegistry → HTTPClient → Provider API
        ↓                         ↓
BalanceSnapshot              LocalSecretStore
        ↓
UsageAccumulator → UsageHistoryStore → UsageSummaryBuilder → UsageView
```

Provider 返回失败时，已有快照应保留；成功余额与用量历史保存失败可以分别展示。首次成功采样只建立用量 baseline，充值、重置、负差额和失败采样不计为消费。

## 持久化边界

| 数据 | 位置 | 是否包含凭据 |
|---|---|---|
| 设置 | `~/Library/Application Support/SmartBalance/settings.json` | 否；只保存 Keychain 引用和非密钥配置 |
| 用量历史 | `~/Library/Application Support/SmartBalance/usage-history.json` | 否；保存汇总采样和统计元数据 |
| 凭据 | macOS Keychain service `com.smartbalance.zhiyu.plain` | 是；只在运行时按需读取 |
| 日志 | `~/Library/Logs/SmartBalance/app.log` | 不应包含；新增日志必须脱敏 |

## 更新和发布

版本源是 `Apps/Mac/Sources/App/Info.plist`。本地构建使用 Tuist/Xcode；正式发布使用项目既有 `Apps/Mac/scripts/release.sh`，并应先完成测试、开源文档门禁、包校验和发布证据记录。源码、构建、Release 和用户安装是不同状态，不能混为一谈。

## 变更规则

新增共享能力优先放入可测试的 Domain/Infrastructure 类型，不把文件迁移、密钥导入、更新校验和诊断脱敏直接写进 SwiftUI View。任何改变数据格式的变更必须提供旧版本 fixture、迁移失败恢复和回滚验证。

