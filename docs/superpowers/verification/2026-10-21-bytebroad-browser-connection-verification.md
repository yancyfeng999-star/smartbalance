# Bytebroad 钱包与浏览器连接验证

日期：2026-10-21。范围：仅智余。计划见 [连接计划](../plans/2026-10-21-bytebroad-browser-connection.md)。

## 已实现

- Bytebroad 固定官方 HTTPS 钱包接口、人民币余额和累计消费；复用现有阈值与天/周/月统计。
- Chrome / Edge 自动发现，MiMo 会话与 UID 同用户目录配对；Bytebroad UID 从 session 的明确类型字段识别，不用任意数字猜测。
- 已有账号无需展开密钥编辑器即可打开官网登录并重新连接。手动 Cookie 改为折叠备选。
- 浏览器访问被拒绝才进入目录选择；未登录、登录失效、普通查询失败分别显示。
- 导入后先验证钱包，成功才保存；失败保留原账号和草稿。刷新失败保留上次余额与成功时间。
- 已授权通知的登录失效提醒在每次运行内去重；不自动打开网站或后台读取浏览器。

## 本地测试

使用隔离 `.noindex` DerivedData，执行 SmartBalance scheme 的 DomainTests、InfrastructureTests、AppTests。

| 组 | 结果 |
| --- | --- |
| DomainTests | 105 passed / 0 failed |
| InfrastructureTests | 285 passed / 0 failed |
| AppTests | 36 passed / 0 failed |
| 合计 | **426 passed / 0 failed**，`TEST SUCCEEDED` |

先新增渠道配置及目录发现测试，旧代码的 4 项失败对应缺少 Bytebroad 和 Chrome 被拒绝时不能继续发现 Edge；随后实现并全量复跑通过。中途修复一次目录发现测试闭包签名编译错误，并保持 APINebula 原有两阶段鉴权回退行为。

覆盖：正常金额、零余额、无当天调用/无累计字段、负余额、无效金额、401/403、业务鉴权失败、5xx、超时、取消、响应账号不匹配、错误单位、固定请求目标、响应脱敏、同用户目录配对、失败保留旧快照、旧快照兼容解码和提醒去重。测试会话及账号全部虚构。

Xcode 输出本机 CoreSimulator 组件版本警告，macOS 三组测试仍成功；这不是模拟器或多版本系统兼容性验收。

## 真实服务与原生界面

| 验证层 | 证据与边界 |
| --- | --- |
| 官网契约 | 已登录 Chrome 的钱包页及 `/api/user/self`、`/api/status`；CNY 和 500000 换算已核对。未保存真实响应、账号标识或 Cookie |
| 真浏览器与 Provider | 隔离 CLI 调用实际 BrowserSessionImporter 和 BytebroadBalanceProvider，自动从 Chrome 导入并查询成功，金额与官网保留两位小数一致；未写入正式设置或钥匙串 |
| 原生 UI | 用实际 APIAccountsSection、Theme、NestedSettingsCard、ProviderLogoView 编译隔离 SwiftUI 窗口，内存虚构 AppModel。点验已有 MiMo 重新连接、新 Bytebroad 登录引导、连接添加及结果反馈；窄窗口显示正常 |
| 不可替代的边界 | UI 样例只证明原生布局与回调可达，不等于正式 App 的真实凭据保存、重启、系统目录授权或通知投递已经端到端验收 |

临时窗口已退出、注销并改为不可启动的归档后缀；不会安装到应用程序。Chrome 原有标签保留，网络诊断监听已关闭。

## 安全、隐私与开源

- 不新增第三方依赖；沿用 Apple 系统框架和已锁定 MenuBarExtraAccess 1.3.1。
- Bytebroad 不使用自定义 API 根地址、不跟随会话请求重定向；错误不显示原始响应。
- 目录选择仅进程内记忆，不新增书签或全盘访问；不修改系统权限、浏览器文件、签名或现有 Keychain 策略。
- Apache-2.0 未改变；用户指南、数据与隐私、第三方字母标识说明同步更新。
- `verify-open-source.sh`、shell 语法和 `git diff --check` 通过。无 CI、依赖漏洞扫描或独立 Reviewer 配置；本次为 Owner 自检，不声称独立复核或无漏洞。

## 发布状态

版本源已升至 **0.5.0 build 89**；通过项目 `release.sh minor` 完成本地版本与打包，先用 `SKIP_PUBLISH=1` 阻止未经核验的远端发布。最终提示文案校正后重新全量测试并按相同版本重打包，尚未公开的本次产物已统一更新。

| 项目 | 结果 |
| --- | --- |
| Debug / Release | 测试构建和 Release `BUILD SUCCEEDED` |
| DMG / PKG | 两包内版本 0.5.0、build 89；均为 arm64 + x86_64 |
| 包内一致性 | 解包后两个 App 的 Contents 逐文件比对相同 |
| 签名 | 两个 App 严格深度校验通过；`Signature=adhoc`，无 TeamIdentifier，未公证 |
| SHA-256 | 四个中/英文安装包校验全部通过 |
| 原安装和数据 | 已安装 0.4.4 build 88 未覆盖；App 可执行文件、设置和用量历史哈希保持不变 |
| 系统入口 | 本次生成的构建 App 已注销/清理，Spotlight 仅返回正式安装；此前可恢复归档保留 |
| 分支合并 | [PR #12](https://github.com/yancyfeng999-star/smartbalance/pull/12) 已合并 main，merge commit `735f768`；`v0.5.0`（`16be1fd`）为 main 祖先，本机 main 已快进同步 |
| 远端 Release | [v0.5.0](https://github.com/yancyfeng999-star/smartbalance/releases/tag/v0.5.0) 非草稿、非预发布；DMG、PKG、SHA256SUMS 三项资产已上传 |
| 资产回查 | 三项远端资产回下载后与本地逐字节一致；两个英文安装包 SHA-256 通过 |
| 更新发现 | 实际 UpdateChecker 以 `currentVersion=0.4.4` 联网返回 `available`、`latest=0.5.0`、`SmartBalance-0.5.0.pkg`、`checksums=true`。该源码与 0.4.4 未发生变化；这不是用户 App 已安装/重启的证据 |

用户安装不由 Agent 代办。所有命令为本地等价门禁，不代表 CI、正式升级安装或用户验收已通过。

## 仍未验证 / 限制

- 本次没有主动退出用户网站、操作真实第二账号、触发真实登录失效通知或重新授予系统目录权限；对应分支由虚构测试覆盖。
- 没有重新逐一验证其他渠道真实网络、SMTP、VoiceOver、深色模式、多屏幕、Intel 实机或 macOS 15 实机。
- 当前继续 ad-hoc 签名，未公证；升级后若旧 Keychain 条目不可读仍需重新连接一次，未承诺跨签名继承。
- Bytebroad 单位换算是当前官网契约，站点变更时需要重新核对；本地统计不补算初次连接前的历史消费。
