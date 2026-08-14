# 参与智余贡献

感谢你为智余（SmartBalance）提交问题、文档、测试或代码。智余是一个 macOS 15+ 菜单栏应用，贡献应优先保持本地优先、隐私最小化和可验证性。

## 开始之前

- 阅读 [README](./README.md)、[架构说明](./docs/ARCHITECTURE.md)、[数据与隐私](./docs/DATA_AND_PRIVACY.md) 和 [安全政策](./SECURITY.md)。
- 需要 macOS 15+、Xcode、Swift 6 和 Tuist。项目使用 SwiftUI/AppKit、Tuist 和 XCTest。
- 不要在仓库、Issue、Pull Request、fixture 或截图中提交 API Key、Cookie、SMTP 密码、Keychain 导出、真实日志或诊断包。
- 新 Provider、更新器、Keychain、持久化和通知相关改动需要同时补测试和文档；不能只改 UI 文案而不核对实际行为。

## 本地构建与测试

```bash
cd Apps/Mac
tuist generate --no-open
./scripts/run-tests.sh
```

需要单独构建时：

```bash
xcodebuild build \
  -workspace SmartBalance.xcworkspace \
  -scheme SmartBalance \
  -configuration Debug \
  -destination 'platform=macOS'
```

开源文档和许可证门禁：

```bash
bash Apps/Mac/scripts/verify-open-source.sh
```

测试应使用 `HTTPClientMock` 和本地 fixture。真实 Provider、SMTP、Chrome 登录态和用户 Key 不属于自动化测试前提；需要真实服务验证时，必须在 PR 中说明授权范围和未验证部分。

## 代码边界

项目保持以下分层：

```text
Domain → Infrastructure → App
```

- `Domain`：余额、账号、用量、设置、统计规则和可序列化模型。
- `Infrastructure`：Provider、HTTP、Keychain、文件持久化、通知、SMTP、更新下载和日志。
- `App`：菜单栏入口、`AppModel`、SwiftUI 页面、窗口和本地化。

修改应尽量放在已有层中，避免把 Provider 网络、Keychain 读取、文件写入或统计规则直接塞进 SwiftUI View。现有 `AppModel` 是界面状态中心，但新的共享能力应优先使用可测试服务，避免继续扩大单文件职责。

## 新增 Provider

请先阅读 [Provider 开发指南](./docs/PROVIDER_DEVELOPMENT.md)，然后完成：

1. 添加或扩展 `ProviderKind` 和余额模型映射。
2. 实现 `*BalanceProvider` 并注册到 `ProviderRegistry`。
3. 为成功、鉴权失败、超时、字段缺失和单位异常补 mock 测试。
4. 如需 logo，记录资源来源、商标使用边界和许可证/授权信息。
5. 更新 README、用户指南、Provider 开发文档和 CHANGELOG。

Provider 不得把 API Key、Cookie、Authorization header 或原始响应正文写入日志、设置 JSON、用量历史、诊断包或测试输出。

## Pull Request 要求

- 一个 PR 尽量只解决一个主题，并说明用户可感知的变化。
- 描述修改范围、数据迁移、隐私影响、兼容性和回滚方式。
- 附上相关测试命令和结果；如果未运行真实渠道、运行时 App、签名或用户安装，明确写“未验证”。
- UI 改动附上必要的截图或录屏，并说明浅色/深色、固定窗口、多语言、键盘和 VoiceOver 影响。
- 许可证、第三方依赖、图片、字体或代码片段发生变化时同步更新 `THIRD_PARTY_NOTICES.md`。
- 不要把构建产物、`DerivedData`、临时日志、诊断包、Keychain dump 或用户数据提交到仓库。

提交前请完成：

```bash
git diff --check
bash Apps/Mac/scripts/verify-open-source.sh
cd Apps/Mac && ./scripts/run-tests.sh
```

## 许可

智余源代码按仓库根目录 [Apache License 2.0（Apache-2.0）](./LICENSE) 发布。提交内容必须由贡献者拥有相应权利，并按 Apache-2.0 的贡献与再分发条款提供。第三方代码和资源仍受其各自许可证约束，详见 [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md)。
