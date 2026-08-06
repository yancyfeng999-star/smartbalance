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

## 构建

```bash
tuist generate
open SmartBalance.xcworkspace
# Run 智余
```

## 配置提示

1. **API 平台**：设置 → 添加 DeepSeek / New-API  
2. **仅发邮件的平台**：添加「平台邮件源」（发件人包含）+ 配置 **IMAP**  
3. **报警**：打开 Mac 通知 / 邮件报警，填 SMTP，可点测试  

设置文件：`~/Library/Application Support/SmartBalance/settings.json`  
密钥：Keychain `com.smartbalance.app`
