# 智余 · 用户指南（V1）

菜单栏应用 · 无 Dock 图标 · macOS 15+

## 启动

```bash
cd Apps/Mac
./scripts/build-test-app.sh   # Release → ~/Desktop/智余.app
open ~/Desktop/智余.app
```

或在 Xcode 打开 `SmartBalance.xcworkspace` 后 Run。

菜单栏出现 **¥** 图标（`yensign.circle.fill`）与「智余」标题，点击打开面板。

## 5 分钟上手

### 1. API 查余额（多数平台）

1. 面板 → **设置**
2. 确认「API 查询」开启
3. **添加 API 账号**：选 DeepSeek / New-API / OpenRouter，填密钥（New-API 还需 Base URL）
4. 回 **首页** → **刷新**

卡片显示金额、状态色、来源徽章 **API**。

### 2. 平台邮件（无实时 API 时）

1. 设置 → 打开「平台邮件」
2. **添加平台邮件源**：填显示名、发件人包含（必填）、主题/正则可选
3. **IMAP 收件箱**：主机/端口/TLS/账号，密码存 Keychain；点「保存 IMAP」
4. 可用 **试解析** 粘贴一封历史邮件正文验证正则
5. 首页 **刷新** → 匹配到的卡片来源为 **平台邮件**

### 3. 报警

| 通道 | 设置位置 | 说明 |
|------|----------|------|
| Mac 通知 | 报警通道 | 首次会请求系统权限；可「测试 Mac 通知」 |
| 邮件报警 | 报警通道 + SMTP | 465 + TLS；QQ/163/Gmail 快捷填入；可「测试报警邮件」 |

触发：余额状态为偏低 / 危急 / 耗尽，或平台新邮件含报警关键词。冷却秒数防止刷屏；发送失败不进入冷却。

### 4. 刷新间隔

设置 → 刷新间隔：仅手动 / 5 / 10 / 15 / 30 分钟。

## 数据存放

| 内容 | 位置 |
|------|------|
| 设置 JSON | `~/Library/Application Support/SmartBalance/settings.json` |
| API Key / 邮箱密码 | Keychain，service `com.smartbalance.app` |

密钥**不**写入设置文件、**不**上传。

## 常见问题

- **401 / 密钥错误**：检查 Key 与 Base URL；New-API 路径因站而异。
- **IMAP 无卡片**：确认平台邮件源发件人字符串、IMAP 已启用且密码正确。
- **SMTP 失败**：优先 465 + TLS；当前不支持 587 STARTTLS。失败时首页有可关闭 banner。
- **通知不出现**：系统设置 → 通知 → 智余；设置页查看通知状态文案。

## 与智额

| 应用 | 关注点 |
|------|--------|
| 智额 SmartQuota | 会员额度 |
| 智余 SmartBalance | API / 平台邮件余额 + 双通道报警 |
