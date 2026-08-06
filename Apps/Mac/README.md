# 智余 Mac 工程

## 分层

```text
Domain → Infrastructure → App (SwiftUI MenuBarExtra)
```

## 常用命令

```bash
tuist generate
./scripts/run-tests.sh
./scripts/package-release.sh 0.2.0
```

## 新增 Provider

1. `ProviderKind` + `*BalanceProvider`
2. `ProviderRegistry`
3. `Provider_<kind>.imageset` logo（可选）
4. 单测

## 更新

`UpdateChecker` + `ReleaseDownloader`：GitHub Releases 拉 zip，设置里检查后下载打开。
