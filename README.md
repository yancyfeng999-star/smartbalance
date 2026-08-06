# 智余 · SmartBalance

| | |
|--|--|
| **中文名** | 智余 |
| **英文名** | SmartBalance |
| **平台** | macOS 15+ 菜单栏 |
| **状态** | V1 代码完成 · 见 [PROJECT_STATUS.md](./PROJECT_STATUS.md) |

## 怎么工作

### 数据源（知道余额）

| 路径 | 适用 | 做法 |
|------|------|------|
| **API 直查** | 大多数平台 | Key / BaseURL 调余额接口（DeepSeek · New-API · OpenRouter） |
| **平台邮件** | 无实时查询的平台 | IMAP 读其**固定发件邮箱**来信并解析金额 |

### 报警通道（通知你）

| 通道 | 说明 |
|------|------|
| **Mac 通知** | 系统通知中心 |
| **邮件报警** | SMTP 发到你的邮箱（推荐 465 + TLS） |

触发：余额偏低 / 危急 / 耗尽；或平台新邮件含报警关键词。

与 [智额](../智额/) 互补：智额看会员额度，智余看 API 余额并报警。

## 文档

- [PRODUCT.md](./PRODUCT.md) — 产品说明与成功标准  
- [docs/USER_GUIDE.md](./docs/USER_GUIDE.md) — 简短用户指南  
- [PROJECT_STATUS.md](./PROJECT_STATUS.md) — 实现状态与手工验收表  
- [RESEARCH.md](./RESEARCH.md)  
- [Apps/Mac/README.md](./Apps/Mac/README.md) — 架构与构建  
- [V1 实现计划](./docs/superpowers/plans/2026-08-06-smartbalance-v1.md)

## 运行

```bash
cd Apps/Mac
# 开发
tuist generate && open SmartBalance.xcworkspace

# 或一键 Release 到桌面
./scripts/build-test-app.sh
open ~/Desktop/智余.app
```

测试：

```bash
cd Apps/Mac && ./scripts/run-tests.sh
```
