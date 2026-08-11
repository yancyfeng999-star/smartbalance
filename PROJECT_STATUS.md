# 项目状态

**版本：** 0.2.56（build 77）  
**阶段：** 可安装使用；GitHub Releases 发版与应用内检查更新已通  
**远程：** https://github.com/yancyfeng999-star/smartbalance  

## Agent 默认

修 bug / 做功能 → **直接** `NOTES="…" ./scripts/release.sh` 上线。  
用户只「检查更新」装包，**不**负责升版与 push。  

详见：

- [AGENTS.md](./AGENTS.md)
- [docs/AGENT_RELEASE_WORKFLOW.md](./docs/AGENT_RELEASE_WORKFLOW.md)

## 已完成（摘要）

- 菜单栏弹层 380×580；外观浅/深/跟随系统（0.2.18 起 AppKit appearance 同步）
- 多平台余额 + 手录 + 人民币折算报警
- 完全本地的自然天 / ISO 周 / 月渠道用量统计；按币种分卡，历史保留 400 天
- 首页卡片选中 +「打开后台」跟选中账号（0.2.17）
- 本机 Keychain 密钥；Mac 通知 / SMTP 邮件报警
- 多语言设置；平台 logo；GitHub 检查更新
- `release.sh` 一键：升版 → dmg/pkg → tag → Release

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

## 手工验收（可选）

| 场景 | 备注 |
|------|------|
| `/Applications/智余.app` 运行 | 正式入口 |
| 浅色/深色切换立即变色 | ≥ 0.2.18 |
| 点第二张卡再「打开后台」 | ≥ 0.2.17 |
| 齿轮 → 设置；底栏“用量” → 天/周/月 | 用量首次刷新只建基线 |
| 检查更新拉到最新 Release | 需网络 |
