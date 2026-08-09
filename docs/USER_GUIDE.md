# 智余 · 用户指南

菜单栏应用 · 无 Dock · macOS 15+

## 安装运行

```bash
cd Apps/Mac
./scripts/build-test-app.sh
open ~/Desktop/智余.app
```

或 Xcode 打开 `SmartBalance.xcworkspace` 后 Run。  
菜单栏出现 **¥** /「智余」即可点开。

---

## 上手

### 1. 添加账号

**设置 → API 账号 → 点开平台**

| 平台 | 填写 |
|------|------|
| DeepSeek / OpenRouter / Kimi / ViralTok / 老张 | API Key 或系统令牌 |
| New-API | Base URL + 用户 ID + 系统访问令牌 |
| DMXAPI | 用户 ID + 系统访问令牌 |
| 火山引擎 | Access Key ID + Secret Access Key |
| 小米 MiMo | **推荐**：Chrome 登录控制台后点「从 Chrome 导入」；或手贴 `serviceToken`+`userId` |
| MiniMax | **推荐**：Chrome 登录充值页后点「从 Chrome 导入」；或手贴 `_token`+`group_id` |
| apinebula | Chrome 登录后一键导入（自动读 session 查余额） |

回首页点 **刷新**。

### 2. 报警

**设置 → 报警通知**

- 打开 Mac 通知 / 邮件报警  
- 邮件需配置 SMTP（建议 465 + TLS）  
- 可用「测试」验证  

阈值在 **后台同步** 中调整。

### 3. 刷新间隔

**设置 → 后台同步**：仅手动 / 5 / 10 / 15 / 30 分钟。

### 4. 置顶

点图钉打开常驻窗口，切换应用不会自动关闭。

---

## 数据位置

| 内容 | 路径 |
|------|------|
| 设置 | `~/Library/Application Support/SmartBalance/settings.json` |
| 密钥 | `…/secrets.vault`（本机文件，权限 0600，启动即可读） |

---

## FAQ

| 问题 | 处理 |
|------|------|
| 401 / 缺用户 ID | New-API、DMXAPI 必须填用户 ID；用**系统令牌**不是模型 sk- |
| 火山报错 | 检查 AK/SK 与账单查询权限 |
| SMTP 失败 | 用 465 TLS；暂不支持 587 |
| 无通知 | 系统设置 → 通知 → 智余 |
| 窗口尺寸乱跳 | 请使用当前版本（主页与设置固定同宽高） |
