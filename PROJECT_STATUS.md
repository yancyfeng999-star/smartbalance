# 项目状态

**版本源（唯一）：** `Apps/Mac/Sources/App/Info.plist` → **0.3.1（build 82）**
`0.2.56（build 77）` 及更早表头数字作废，不得当作实现或发版依据。

| 口径 | 状态 |
|------|------|
| 已实现（本工作树代码） | 菜单栏余额、用量、设置信封、诊断、迁移、手动更新确认、安全模式、兼容性/用量健康收口 |
| 本地测试 | 2026-08-14 `./scripts/run-tests.sh`：**366 passed / 0 failed**（Domain 94 + Infrastructure 236 + App 36） |
| Debug / Release 构建 | 同日 `xcodebuild` 均 **BUILD SUCCEEDED**；Release 含 arm64+x86_64 **切片**，不是第二台机器跑过 |
| 运行时 | **当前机器验证**（Apple M5 / arm64 / macOS 26.6.1）：隔离 Application Support 服务检查已做；**菜单栏弹层未做交互验收** |
| 已发布 | 以 GitHub 已推送的 tag / Release 为准。**本分支未执行 `release.sh`，未创建新 Release** |
| 真实渠道 | **未执行**（无单独授权，不用真实 Provider Key） |
| 用户已验收 | 否 |

**远程：** https://github.com/yancyfeng999-star/smartbalance
**本计划：** `feat/mac-common-capabilities` 工作树。P1 完成前不发版、不 push（覆盖 `AGENTS.md` 的默认发版）。

## 当前代码里已有的能力（不是发版声明）

- 菜单栏弹层约 380×580；首页 / 用量 / 设置；外观浅/深/跟随系统
- 多平台余额查询；密钥在本机普通 Keychain（不启用指纹/密码门禁）
- 本地自然天 / ISO 周 / 自然月用量；CNY、USD、未知单位分卡；保留 400 天
- 用量损坏：备份坏文件后重建空结构，诊断与用量页显示「需要恢复」，不当成零用量
- 用量保存失败与余额成功可独立展示
- 设置 schema 信封；旧 settings / 未知渠道 / 未知货币可读取
- 通知未授权不阻止余额刷新；授权只在用户明确动作时请求
- 诊断包 allowlist；设置迁移 v2 不含密钥值
- 检查更新：查看说明 → 用户确认 → 下载 → 校验 → 安装（本工作树已实现；**尚未作为新 GitHub Release 发布**）
- 验证记录：[docs/superpowers/verification/2026-08-14-mac-common-capabilities-verification.md](docs/superpowers/verification/2026-08-14-mac-common-capabilities-verification.md)（代码完成 ≠ 已发布）

## 仓库布局

```text
Apps/Mac/Sources/{Domain,Infrastructure,App}
docs/  Branding/  releases/
AGENTS.md          # Agent 入口（本计划期间不按默认发版）
```

## 排障路径

| 内容 | 路径 |
|------|------|
| 日志 | `~/Library/Logs/SmartBalance/app.log` |
| 设置 | `~/Library/Application Support/SmartBalance/settings.json` |
| 密钥 | macOS Keychain（不写入仓库） |
| 用量历史 | `…/usage-history.json`（0600，不含密钥） |

## 手工验收（当前机器未做交互验收）

| 场景 | 备注 |
|------|------|
| `/Applications/智余.app` 运行 | 正式入口是已发布 0.3.1；**不是**本工作树 Debug/Release |
| 本工作树菜单栏弹层 | 当前机器未点：首次启动、取消刷新、用量日/周/月、更新确认、safe mode、VoiceOver |
| 浅色/深色 / 打开后台 | 代码路径仍在；本记录未做现场点按 |
| 真实渠道 / SMTP | 未执行 |
