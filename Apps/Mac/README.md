# 智余 Mac 工程

## 分层

```text
Domain              Infrastructure                 App
──────              ──────────────                 ───
ProviderKind        *BalanceProvider               MenuRootView（固定壳）
BalanceAccount      BalanceService                 HomeView / BalanceCard
BalanceSnapshot     LocalSecretStore               Settings/*
Alert*              SMTP / Notification            PinnedBalanceWindow
                    HTTPClient · VolcengineSigner
```

弹层尺寸：宽 **380**、高 **580**。

---

## 目录

```text
Sources/Domain/
Sources/Infrastructure/
  Providers/          # 各平台
Sources/App/
  Views/
  Views/Settings/
Tests/
scripts/
  build-test-app.sh
  run-tests.sh
  package-release.sh
Project.swift
```

---

## 构建

```bash
tuist generate
open SmartBalance.xcworkspace

./scripts/build-test-app.sh    # → ~/Desktop/智余.app
./scripts/run-tests.sh
./scripts/package-release.sh 0.1.0
```

---

## 新增平台

1. `ProviderKind` 增加 case  
2. `Infrastructure/Providers/XxxBalanceProvider.swift`  
3. `ProviderRegistry` 注册  
4. `APIAccountsSection` / `BalanceCardView` 图标色  
5. `Tests/InfrastructureTests/XxxProviderTests.swift`  
6. `tuist generate` 并跑测  

---

## 本机路径

- 设置：`~/Library/Application Support/SmartBalance/settings.json`  
- 密钥：`~/Library/Application Support/SmartBalance/secrets.vault`  
