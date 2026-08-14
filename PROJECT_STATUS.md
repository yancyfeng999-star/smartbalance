# 项目状态

**版本：** 0.3.2（build 83，以 `Apps/Mac/Sources/App/Info.plist` 为准）
**阶段：** 可安装使用；通用能力代码已合入本分支，是否作为新 GitHub Release 发布以 tag 为准
**远程：** https://github.com/yancyfeng999-star/smartbalance

| 口径 | 状态 |
|------|------|
| 已实现（本分支代码） | 菜单栏余额、用量、设置信封、诊断、迁移、手动更新确认、安全模式、兼容性/用量健康收口 |
| 本地测试 | 2026-08-14 功能分支 `./scripts/run-tests.sh`：**366 passed / 0 failed**（Domain 94 + Infrastructure 236 + App 36）；合入 0.3.2 后需复跑 |
| Debug / Release 构建 | 功能分支同日 `xcodebuild` 均 **BUILD SUCCEEDED**；Release 含 arm64+x86_64 **切片**，不是第二台机器跑过 |
| 运行时 | **当前机器验证**（Apple M5 / arm64 / macOS 26.6.1）：隔离 Application Support 服务检查已做；**菜单栏弹层未做交互验收** |
| 已发布 | 已推送 tag / Release 以 GitHub 为准（当前线上为 0.3.2）。通用能力尚未作为新版本发布，直到本次发版完成 |
| 真实渠道 | **未执行**（无单独授权，不用真实 Provider Key） |
| 用户已验收 | 否 |

修 bug / 做功能 → **直接** `NOTES="…" ./scripts/release.sh` 上线。
用户只「检查更新」装包，**不**负责升版与 push。

## 当前代码里已有的能力（不是发版声明）

- 菜单栏弹层约 380×580；首页 / 用量 / 设置；外观浅/深/跟随系统
- 多平台余额查询；密钥在本机普通 Keychain（不启用指纹/密码门禁）
- 本地自然天 / ISO 周 / 自然月用量；CNY、USD、未知单位分卡；保留 400 天
- 用量损坏：备份坏文件后重建空结构，诊断与用量页显示「需要恢复」，不当成零用量
- 用量保存失败与余额成功可独立展示
- 设置 schema 信封；旧 settings / 未知渠道 / 未知货币可读取
- 通知未授权不阻止余额刷新；授权只在用户明确动作时请求
- 诊断包 allowlist；设置迁移 v2 不含密钥值
- 检查更新：查看说明 → 用户确认 → 下载 → 校验 → 安装
- Apache-2.0 开源协议、贡献/安全/行为准则、第三方声明与本地开源门禁
- 验证记录：[docs/superpowers/verification/2026-08-14-mac-common-capabilities-verification.md](docs/superpowers/verification/2026-08-14-mac-common-capabilities-verification.md)（代码完成 ≠ 已发布）

- [AGENTS.md](./AGENTS.md)
- [docs/AGENT_RELEASE_WORKFLOW.md](./docs/AGENT_RELEASE_WORKFLOW.md)

## 仓库布局

```text
Apps/Mac/Sources/{Domain,Infrastructure,App}
docs/  Branding/  releases/
AGENTS.md          # Agent 入口
```

## 排障路径

| 内容 | 路径 |
|------|------|
| 日志 | `~/Library/Logs/SmartBalance/app.log` |
| 设置 | `~/Library/Application Support/SmartBalance/settings.json` |
| 密钥 | macOS Keychain（不写入仓库） |
| 用量历史 | `…/usage-history.json`（0600，不含密钥） |

## 开源文档

- [README.md](./README.md) — 用户入口、构建、隐私和项目文档索引
- [CONTRIBUTING.md](./CONTRIBUTING.md) — 开发、测试和 Pull Request 要求
- [SECURITY.md](./SECURITY.md) — 私下安全报告和敏感数据边界
- [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) — 运行时依赖、构建工具和资源归属
- [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) — 当前模块和数据流
- [docs/DATA_AND_PRIVACY.md](./docs/DATA_AND_PRIVACY.md) — 本地数据、联网和备份边界
- [docs/RELEASE_CHECKLIST.md](./docs/RELEASE_CHECKLIST.md) — 发布前验证和证据分层

## 手工验收（当前机器未做交互验收）

| 场景 | 备注 |
|------|------|
| `/Applications/智余.app` 运行 | 正式入口是已发布 0.3.2；**不是**本工作树 Debug/Release |
| 本分支菜单栏弹层 | 当前机器未点：首次启动、取消刷新、用量日/周/月、更新确认、safe mode、VoiceOver |
| 浅色/深色 / 打开后台 | 代码路径仍在；本记录未做现场点按 |
| 真实渠道 / SMTP | 未执行 |
