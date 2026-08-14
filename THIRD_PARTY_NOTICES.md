# 第三方依赖与归属

本文件记录智余源码或发布流程涉及的第三方代码、工具和资源。版本、来源或分发范围发生变化时，必须在同一个变更中更新本文件，并运行 `bash Apps/Mac/scripts/verify-open-source.sh`。

## 随 App 使用的运行时依赖

### MenuBarExtraAccess

- 版本：`1.3.1`
- 锁定 revision：`e93e3a5b814714bf4d4cea67bf63a6b6a8323968`
- 来源：[orchetect/MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess)
- 许可证：MIT
- 用途：访问 SwiftUI `MenuBarExtra` 底层 `NSStatusItem`，支持智余菜单栏图标和窗口行为。
- 许可文本：以上游仓库该 revision 的 `LICENSE` 为准；本项目不把该依赖的代码重新声明为智余自有代码。

## 仅用于开发或构建的工具

### Tuist

Tuist 用于生成 Xcode workspace/project，是本地开发和构建工具，不随智余 App 分发。使用者应按 Tuist 官方项目的许可证和安装说明获取工具；本仓库只提交项目所需的 `Project.swift`、Tuist package 配置和锁定信息。

### Swift、Xcode 和 Apple 系统框架

Swift toolchain、Xcode、SwiftUI、AppKit、Security、UserNotifications、Swift Charts 等由 Apple/Swift 工具链提供，不随本仓库作为第三方二进制重新分发。使用者应遵守相应平台和工具许可证。

## 品牌、Provider 和资源

智余中的 Provider 名称、logo、控制台链接和服务名称只用于识别用户配置的服务，不表示智余得到相关服务商的赞助、认证或隶属。相关商标归各自所有者所有。

Provider logo 和 App 图像资源属于仓库中的产品资源；新增或替换资源时，贡献者必须在 PR 中说明来源、创作主体、许可证或商标使用依据。来源无法确认、许可证不允许随 App 分发或可能误导用户的资源不得合入发布版本。

### 当前仓库资源审计边界

- 随 App 构建的图像资源位于 `Apps/Mac/Sources/App/Resources/Assets.xcassets`，包括 `AppIcon`、`AppLogo`、`MenuBarIcon` 和 `Provider_*.imageset`。
- 产品与文档用品牌资源位于 `Apps/Mac/Branding` 和根目录 `Branding`；这些目录中的源文件、预览图和营销图不应被默认视为第三方开源资源，也不自动获得 Apache-2.0 授权。
- 当前仓库源代码和上述资源目录未发现嵌入式字体文件；若后续加入字体，必须单独记录字体名称、版本、来源、许可证和随 App 分发方式。
- 现有资源的 Git 历史只能证明其进入仓库的变更记录，不能替代创作主体、授权或商标使用依据的法律证明。维护者在每次发布前必须完成资源来源台账核对；无法核对的资源视为发布阻塞项。

## 外部文档与代码片段

Provider 协议、签名算法和 API 文档可能引用服务商公开文档；代码注释中的外部链接只作为参考，不代表智余拥有相关文档。复制外部代码或示例前必须记录来源和许可证，并确认与 Apache-2.0 项目兼容。

## 项目许可证

智余自身代码和仓库文档按根目录 [Apache License 2.0（Apache-2.0）](./LICENSE) 发布。该许可证不替代上述第三方组件各自的许可证和商标要求。
