# Changelog

## 0.2.1 — 2026-08-06

- 余额四档：充足 / 偏低(100) / 不足(50) / 危急(20)
- 发版脚本强制每次升版本再上线
- 禁止同版本重复打包上线
- 修复 bump-version 解析三位版本号


## 0.2.0 — 2026-08-06

### 新增
- 多平台余额：DeepSeek、New-API、OpenRouter、ViralTok、老张、DMXAPI、Kimi、火山引擎
- 手录：小米 MiMo、MiniMax + 每日提醒
- 报警：Mac 通知、SMTP 邮件
- 置顶窗、固定 380×580 弹层
- 本机 `secrets.vault` + 会话指纹解锁
- 吉米币×7.3、老张 USD×7 折算人民币报警
- GitHub Releases 检查更新（下载 zip 后打开安装）

### 界面
- 平台 logo、深色海军蓝玻璃壳
- 状态栏仅图标；图钉仅置顶窗打开时点亮
- 设置：API 账号默认折叠；关于固定卡片

### 打包
- `Apps/Mac/scripts/package-release.sh` → 桌面 `智余.app` + `SmartBalance-*-macOS.zip`
