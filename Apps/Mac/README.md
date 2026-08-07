# 智余 Mac 工程

> Agent 协作与发版：**仓库根目录 [AGENTS.md](../../AGENTS.md)**、[docs/AGENT_RELEASE_WORKFLOW.md](../../docs/AGENT_RELEASE_WORKFLOW.md)。  
> 默认修完即 `NOTES="…" ./scripts/release.sh`，不要让用户自己升版。

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

`UpdateChecker` + `ReleaseDownloader`：GitHub Releases 拉 zip，设置里检查后下载打开。
