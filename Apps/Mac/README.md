# 智余 Mac 工程

这是智余 macOS 菜单栏 App 的工程目录。用户和贡献者入口在仓库根目录 [README.md](../../README.md)；贡献、隐私、第三方和发布规则分别见 [CONTRIBUTING.md](../../CONTRIBUTING.md)、[docs/DATA_AND_PRIVACY.md](../../docs/DATA_AND_PRIVACY.md)、[THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md) 和 [docs/RELEASE_CHECKLIST.md](../../docs/RELEASE_CHECKLIST.md)。

Agent 协作与发版：仓库根目录 [AGENTS.md](../../AGENTS.md)、[docs/AGENT_RELEASE_WORKFLOW.md](../../docs/AGENT_RELEASE_WORKFLOW.md)。默认修完即 `NOTES="…" ./scripts/release.sh`。验证见 [verification](../../docs/superpowers/verification/2026-08-14-mac-common-capabilities-verification.md)。

## 分层

```text
Domain → Infrastructure → App (SwiftUI MenuBarExtra)
```

## 常用命令

```bash
tuist generate
./scripts/run-tests.sh

# 开源文档、许可证和敏感文件门禁
bash ./scripts/verify-open-source.sh

# 维护者正式上线（升版 + 包 + GitHub Release）
NOTES="修复 xxx" ./scripts/release.sh

# 仅打包
./scripts/package-release.sh
# 或
SKIP_PUBLISH=1 ./scripts/release.sh
```

## 新增 Provider

具体流程见仓库根目录 [docs/PROVIDER_DEVELOPMENT.md](../../docs/PROVIDER_DEVELOPMENT.md)。最小步骤：

1. `ProviderKind` + `*BalanceProvider`
2. `ProviderRegistry`
3. `Provider_<kind>.imageset` logo（可选，必须记录来源/许可证）
4. 成功、失败、取消和单位异常单测
5. README、用户指南和 CHANGELOG

## 更新

`UpdateChecker` 只检查并展示说明；用户确认后才 `ReleaseDownloader` 下载，再校验、安装。不是启动后静默替换。
