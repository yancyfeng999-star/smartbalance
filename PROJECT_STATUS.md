# 项目状态

**版本：** 0.5.0（build 89，以 `Apps/Mac/Sources/App/Info.plist` 为准）
**阶段：** Bytebroad 钱包与浏览器重新连接已实现；正式安装和未覆盖场景按验证记录单独验收
**远程：** https://github.com/yancyfeng999-star/smartbalance

| 口径 | 状态 |
|------|------|
| 已实现（本分支代码） | 菜单栏余额、用量、设置信封、诊断、迁移、手动更新确认、安全模式、兼容性/用量健康收口 |
| 本地测试 | 2026-10-21 隔离 DerivedData：**426 passed / 0 failed**（Domain 105 + Infrastructure 285 + App 36），非 CI |
| 构建与安装包 | Debug 和 Release 构建通过；DMG/PKG 均为 0.5.0 build 89、arm64 + x86_64，App 内容相同，严格签名校验和 SHA-256 通过。仍为 ad-hoc，未公证 |
| 运行时 | 实际 Chrome 自动发现、会话导入及 Bytebroad Provider 查询与官网人民币钱包一致；原生 UI 使用实际视图与内存虚构模型验收，不冒充正式保存/重启验收 |
| 已发布 | 最近公开版本 [v0.4.4](https://github.com/yancyfeng999-star/smartbalance/releases/tag/v0.4.4)；0.5.0 的远端发布、合并和更新检查待完成后补记 |
| 真实渠道 | 本次验证 Bytebroad；MiniMax / APINebula 旧验证记录保留，其余渠道未重新执行真实网络验收 |
| 用户已验收 | 否 |

修 bug / 做功能 → **直接** `NOTES="…" ./scripts/release.sh` 上线。
用户只「检查更新」装包，**不**负责升版与 push。

## 当前代码里已有的能力（不是发版声明）

- 菜单栏弹层约 380×580；首页 / 用量 / 设置；外观浅/深/跟随系统
- 多平台余额查询；密钥在本机普通 Keychain（不启用指纹/密码门禁）
- Bytebroad 人民币钱包及累计消费；Chrome / Edge 自动发现、打开官网登录与重新连接；失效提示不混淆目录权限/网络错误
- 本地自然天 / ISO 周 / 自然月用量；CNY、USD、未知单位分卡；保留 400 天
- 用量损坏：备份坏文件后重建空结构，诊断与用量页显示「需要恢复」，不当成零用量
- 用量保存失败与余额成功可独立展示
- 设置 schema 信封；旧 settings / 未知渠道 / 未知货币可读取
- 通知未授权不阻止余额刷新；授权只在用户明确动作时请求
- 诊断包 allowlist；设置迁移 v2 不含密钥值
- 检查更新：查看说明 → 用户确认 → 下载 → 校验 → 安装
- Apache-2.0 开源协议、贡献/安全/行为准则、第三方声明与本地开源门禁
- 最新验证：[Bytebroad 钱包与浏览器重新连接](docs/superpowers/verification/2026-10-21-bytebroad-browser-connection-verification.md)；[0.4.4 导入修复](docs/superpowers/verification/2026-10-10-browser-import-verification.md)、[0.4.3 钱包记录](docs/superpowers/verification/2026-10-09-wallet-balances-verification.md)和历史通用能力记录仍保留

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

## 手工验收边界

| 场景 | 备注 |
|------|------|
| `/Applications/智余.app` | 保留已安装 0.4.4 build 88，不覆盖、不代装 |
| 本分支交互 | 原生隔离样例：已有账号重新连接、新渠道登录引导和添加结果。正式 App 的真实保存、重启和系统授权未端到端重测 |
| 浅色/深色 / 无障碍 | 浅色窄窗口检查通过；深色、VoiceOver、多屏幕及 Intel/macOS 15 实机未执行 |
| 真实渠道 / SMTP | Bytebroad 自动导入和钱包已核对；真实第二账号切换、主动退出网页登录、通知实际投递和 SMTP 未执行 |

当前为 ad-hoc 签名。升级后若旧凭据显示待补，需在新版本重新导入或填写一次；本次修复保证主动保存时读回核对，不承诺跨签名自动继承。重新保存保留旧钥匙串条目，不删除或放宽 ACL。
