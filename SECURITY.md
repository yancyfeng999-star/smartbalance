# 智余安全政策

## 报告安全问题

请不要在公开 Issue、Pull Request、讨论区或公开日志中发布漏洞细节、API Key、Session Cookie、SMTP 密码、诊断包或 Keychain 内容。

优先使用 GitHub 仓库的 **Security → Advisories → Report a vulnerability** 私下报告入口。报告至少应包含：

- 受影响的版本或 commit；
- macOS 版本和 Apple Silicon/Intel 架构；
- 可重复的最小步骤；
- 影响范围和可能的缓解方式；
- 不含秘密值的日志或截图。

如果仓库页面暂时没有私下报告入口，请只创建一个不包含漏洞细节的 Issue，说明“需要私下安全联系”，不要在公开内容中继续描述问题。

## 不要提交的内容

- API Key、Access Key、Secret Key、Bearer token、Cookie 或 SMTP 密码；
- `~/Library/Keychains` 内容、Keychain 导出或包含凭据的旧版备份包；
- 原始 Provider 响应、Authorization header、完整请求 URL 查询参数；
- 包含本地路径、邮箱地址或用户账号信息的未脱敏日志/诊断包。

## 当前数据边界

智余的余额和用量功能以本地文件、普通 macOS Keychain 和用户主动配置的 Provider 请求为主。项目当前不提供云同步和默认遥测。具体位置、联网行为和备份排除字段见 [数据与隐私说明](./docs/DATA_AND_PRIVACY.md)。

## 处理原则

维护者会先确认报告是否包含秘密、是否可重复以及影响范围，再决定修复、缓解、版本公告和公开时间。安全修复的公开说明只应包含必要信息；测试数据必须使用假值。

安全政策本身不承诺固定响应时间或自动赏金。请勿利用安全问题访问、修改或删除他人数据。

