# 项目状态

**版本：** 0.4.3（build 87，以 `Apps/Mac/Sources/App/Info.plist` 为准）
**阶段：** 钱包修复、完整测试和安装包验证完成；远端资产以 GitHub Release 为准
**远程：** https://github.com/yancyfeng999-star/smartbalance

| 口径 | 状态 |
|------|------|
| 已实现（本分支代码） | 菜单栏余额、用量、设置信封、诊断、迁移、手动更新确认、安全模式、兼容性/用量健康收口 |
| 本地测试 | 2026-10-09 `./scripts/run-tests.sh`：**385 passed / 0 failed**（Domain 98 + Infrastructure 251 + App 36） |
| Debug / Release 构建 | 同日 `xcodebuild` 均 **BUILD SUCCEEDED**；Release 含 arm64+x86_64 切片；DMG / PKG 版本、ad-hoc 签名与 SHA-256 已核对 |
| 运行时 | 当前机器的 MiniMax / APINebula 源码查询与 Chrome 网页钱包一致；新安装包的完整菜单栏交互待用户验收 |
| 已发布 | 以 GitHub [v0.4.3 Release](https://github.com/yancyfeng999-star/smartbalance/releases/tag/v0.4.3) 为准；安装包不代表用户已更新 |
| 真实渠道 | 本次授权验证 MiniMax / APINebula 人民币钱包；其余渠道未重新执行真实网络验收 |
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
- 最新验证：[钱包修复与 0.4.3 安装包](docs/superpowers/verification/2026-10-09-wallet-balances-verification.md)；历史通用能力记录仍保留

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
| `/Applications/智余.app` 运行 | 本次保留已安装 0.4.2；用户自行更新至 0.4.3 |
| 本分支菜单栏弹层 | 当前机器未点：首次启动、取消刷新、用量日/周/月、更新确认、safe mode、VoiceOver |
| 浅色/深色 / 打开后台 | 代码路径仍在；本记录未做现场点按 |
| 真实渠道 / SMTP | MiniMax / APINebula 源码查询已核对；真实第二账号切换与 SMTP 未执行 |
