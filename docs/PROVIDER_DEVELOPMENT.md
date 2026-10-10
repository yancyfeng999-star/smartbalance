# Provider 开发指南

本文说明如何在智余中增加或维护余额渠道。目标是让每个 Provider 都有清晰的数据边界、可重复的 mock 测试和可维护的用户文档。

## 入口和结构

相关代码位于：

- `Apps/Mac/Sources/Domain/ProviderKind.swift`
- `Apps/Mac/Sources/Domain/BalanceProvider.swift`
- `Apps/Mac/Sources/Infrastructure/Providers/`
- `Apps/Mac/Sources/Infrastructure/Providers/ProviderRegistry.swift`
- `Apps/Mac/Sources/App/Views/Settings/APIAccountsSection.swift`
- `Apps/Mac/Tests/InfrastructureTests/`

新增 Provider 的最小步骤：

1. 为 `ProviderKind` 增加稳定的枚举值、展示名、默认 URL、控制台 URL、默认单位和认证类型。
2. 创建 `*BalanceProvider.swift`，实现已有余额查询协议/工厂约定。
3. 在 `ProviderRegistry` 注册实现，确认启用/禁用和错误映射路径。
4. 如渠道需要凭据，从 `LocalSecretStore` 按现有 `secretRef` 读取；不要在 Provider 中自行创建 Keychain service。
5. 为成功、HTTP 错误、鉴权失败、超时、JSON 字段缺失、单位异常和取消补测试。
6. 更新 README、用户指南、产品说明和第三方/商标说明。

## 请求和响应规则

- 所有请求通过现有 HTTP 抽象，以便测试注入和统一超时/错误处理。
- 不在日志中输出 API Key、Cookie、Authorization、签名原文、完整请求 URL 查询参数或响应正文。
- 只提取余额、累计用量、单位、更新时间和用户可理解的错误分类；未知字段不要臆测为金额。
- 无法确认货币或单位时保留 `unknown`，不要静默换算成 CNY。
- Provider 失败时返回可定位错误，不清空已有快照，也不写入失败用量采样。
- 任何签名算法都要在测试中使用假值，并在注释中注明官方文档来源和访问日期/版本。

## 测试方式

测试放在 `Apps/Mac/Tests/InfrastructureTests/`，复用 `HTTPClientMock`。测试 fixture 只能使用假 token、假 Cookie 和固定的非生产 JSON。

至少覆盖：

- 最小成功响应和多个合法字段排列；
- 401/403、404、429、5xx、超时、取消和空响应；
- 金额为 0、负数、超大数、未知单位和缺失字段；
- 手录 Provider 的更新和每日提醒语义；
- 用量累计值与余额下降估算如何进入现有 Domain 统计链路。

未获得明确授权时，不要用真实渠道账号运行测试，也不要把真实响应保存到 fixture。真实渠道手测必须单独记录为 runtime evidence，不能代替单元测试。

## Logo 和文档

Provider logo 是识别资源，不代表服务商背书。新增资源前在 PR 中说明来源、创作/授权主体、许可证或商标使用依据；不能从未知网页直接复制图片进入仓库。资源变更同步 `THIRD_PARTY_NOTICES.md`。

## Review 清单

- ProviderRegistry 注册和 UI 配置入口已更新；
- secretRef、Keychain 和日志边界没有扩大；
- mock 测试覆盖成功和失败路径；
- 货币/单位和用量统计语义没有被悄悄改变；
- README、USER_GUIDE、PRODUCT 和 CHANGELOG 与代码一致；
- `bash Apps/Mac/scripts/verify-open-source.sh`、`cd Apps/Mac && ./scripts/run-tests.sh` 已运行。

