# 智余 · SmartBalance（Mac）

## 架构

```text
数据源                          报警通道
────────                        ────────
API 直查  ──┐                ┌─→ Mac 通知
            ├→ 统一余额卡片 ─┤
平台邮件  ──┘                └─→ 邮件报警 (SMTP)
  (IMAP 读固定发件人)
```

分层：`Domain`（模型/解析）→ `Infrastructure`（网络/IMAP/SMTP/Keychain）→ `App`（SwiftUI 菜单栏）。

设置页信息架构（`Views/Settings/`）：

1. 数据源开关  
2. API 账号  
3. 平台邮件源 + 试解析  
4. IMAP  
5. 报警通道（Mac / 邮件）  
6. SMTP + 阈值 + 冷却  
7. 刷新间隔  
8. 关于  

## 构建

```bash
tuist generate
open SmartBalance.xcworkspace
# Run 智余（菜单栏，无 Dock）
```

一键测试包：

```bash
./scripts/build-test-app.sh
# → ~/Desktop/智余.app
```

打包 zip（可选）：

```bash
./scripts/package-release.sh 0.1.0
# → dist/SmartBalance-0.1.0-macOS.zip
```

单测：

```bash
./scripts/run-tests.sh
```

## 配置提示

1. **API 平台**：设置 → 添加 DeepSeek / New-API / OpenRouter  
2. **仅发邮件的平台**：添加「平台邮件源」（发件人包含）+ 配置 **IMAP**；可用「试解析」  
3. **报警**：打开 Mac 通知 / 邮件报警，填 SMTP（465 TLS），可点测试  

设置文件：`~/Library/Application Support/SmartBalance/settings.json`  
密钥：Keychain `com.smartbalance.app`  

更多步骤见仓库根 [docs/USER_GUIDE.md](../../docs/USER_GUIDE.md)。
