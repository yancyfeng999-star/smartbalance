# 智余数据与隐私说明

## 默认原则

智余以本地运行和本地统计为默认。应用不会因为打开菜单、查看用量或保存设置而把数据同步到智余服务器；项目当前不提供云账号、云同步或默认遥测。

## 本机数据

| 数据 | 默认位置 | 内容边界 |
|---|---|---|
| 设置 | `~/Library/Application Support/SmartBalance/settings.json` | Provider 类型、显示名、URL、用户 ID、阈值、刷新/主题/语言等非密钥设置 |
| 用量历史 | `~/Library/Application Support/SmartBalance/usage-history.json` | 成功采样、基线、日记录、货币/单位和统计元数据；不保存 Key、Cookie 或响应正文 |
| 凭据 | macOS Keychain service `com.smartbalance.zhiyu.plain` | API Key、Session Cookie、Access/Secret Key、SMTP 密码等运行时凭据 |
| 日志 | `~/Library/Logs/SmartBalance/app.log` | 运行错误和状态；不应写入 Authorization、Cookie、密码或原始响应 |

设置和用量历史文件使用本地权限和原子写入策略。用户备份 Mac 或共享 Application Support 目录时，应把这些文件视为个人数据。

## 网络行为

当用户配置并刷新 Provider 时，智余会按 Provider 实现访问相应的余额/账单接口。使用 Chrome 导入控制台登录态时，凭据仍应落入本机 Keychain；SMTP 报警只在用户启用并配置后连接用户指定的 SMTP 服务。

应用内检查更新会访问项目配置的 GitHub Releases API/页面。更新检查不代表余额数据会被发送到 GitHub。具体 Provider 的域名、请求字段和权限由各 Provider 实现与用户配置决定。

## Keychain 和授权弹窗

当前智余使用普通 Keychain 条目，不调用 Touch ID、生物识别或 `SecAccessControl`。旧版带访问控制的条目不会被自动读取、删除或迁移，因此不会为了升级而弹出系统密码框。用户可以在 macOS Keychain Access 中自行管理条目；应用不会把运行时密钥写入 settings JSON、用量历史或日志。

如果用户在恢复预览页明确确认旧版 v1 数据备份，备份中的明文 secrets 会在内存中按账号 ID 映射到新凭据引用，并写入普通 Keychain；失败会回滚设置和已写入的凭据。原始备份文件不会被删除，当前 v2 设置迁移包和本机备份仍不导出密钥。

## 备份和迁移风险

历史 `DataBackupPackage` v1 包含 `secrets` 字段，旧版备份文件可能含明文密钥。不要把这类备份上传到 Issue、网盘、聊天或公开仓库；导入时只有用户明确确认才会写入普通 Keychain。当前 v2 设置迁移和本机备份只携带非密钥配置，导入后若没有可迁移凭据则需要重新填写。

## 用量统计

用量统计只使用余额/累计值成功采样和本机历史。智余按自然日、ISO 周、自然月展示；CNY、USD 和未知单位分开，不做汇率换算。首次成功采样建立 baseline，不补算安装前消费；跨日未采样的差额归入后一次成功采样日期并显示提示。

## 诊断和支持

提交问题前请先删除 API Key、Cookie、SMTP 密码、邮箱地址、完整 URL 查询参数和原始响应。未来诊断导出应只包含版本、系统、状态摘要和脱敏日志；在此能力完成前，请不要直接上传 `app.log` 或备份文件。

## 数据删除

删除设置或账号不会自动删除 Keychain 中所有条目，也不会替用户删除系统备份。用户应先确认不再需要恢复数据，再使用 macOS Keychain Access 和 Finder 按自己的保留策略删除凭据、设置、用量历史和日志。

## 免责声明

智余显示的是 Provider 接口或余额估算结果，不是财务结算凭证。不同服务商的账单延迟、重置、充值和单位定义可能导致显示与控制台暂时不同；发现异常时请以 Provider 官方账单为准，并提交不含秘密的复现信息。
