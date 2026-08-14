# 智余 Mac 工程

> Agent 协作与发版：仓库根目录 [AGENTS.md](../../AGENTS.md)、[docs/AGENT_RELEASE_WORKFLOW.md](../../docs/AGENT_RELEASE_WORKFLOW.md)。
> 默认修完即 `NOTES="…" ./scripts/release.sh`。
> **`feat/mac-common-capabilities` 计划覆盖该默认：** 未获用户明确发版要求前不跑 `release.sh`、不 push、不建 GitHub Release。验证见 [verification](../../docs/superpowers/verification/2026-08-14-mac-common-capabilities-verification.md)。

## 分层

```text
Domain → Infrastructure → App (SwiftUI MenuBarExtra)
```

## 常用命令

```bash
tuist generate
./scripts/run-tests.sh

# 正式上线（升版 + 包 + GitHub Release）
NOTES="修复 xxx" ./scripts/release.sh

# 仅打包
./scripts/package-release.sh
# 或
SKIP_PUBLISH=1 ./scripts/release.sh
```

## 新增 Provider

1. `ProviderKind` + `*BalanceProvider`
2. `ProviderRegistry`
3. `Provider_<kind>.imageset` logo（可选）
4. 单测

## 更新

本工作树：`UpdateChecker` 只检查并展示说明；用户确认后才 `ReleaseDownloader` 下载，再校验、安装。不是启动后静默替换。
该流程 **已实现 / 有单测**；**未**作为新 GitHub Release 发布，菜单栏确认链 **当前机器未做交互验收**。
