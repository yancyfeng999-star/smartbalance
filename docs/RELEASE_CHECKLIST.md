# 智余开源发布检查清单

本清单适用于维护者准备本地安装包、GitHub Release 或应用内更新资产时。它不把本地构建、远程发布和用户安装视为同一个证据。

## 代码和文档

- [ ] `git status --short` 已检查，未覆盖其他人的 dirty/untracked 改动。
- [ ] `LICENSE` 是完整 Apache License 2.0 文件，包含 `SPDX-License-Identifier: Apache-2.0`。
- [ ] README、用户指南、架构、隐私、贡献、安全、行为准则、Provider 指南和第三方声明已更新。
- [ ] `CHANGELOG.md` 只记录本次真实完成内容，没有把计划写成已发布功能。
- [ ] 所有随 App 分发的依赖、图片、字体、logo 和代码片段都有来源与许可证记录。
- [ ] `bash Apps/Mac/scripts/verify-open-source.sh` 通过。

## 测试和构建

- [ ] `cd Apps/Mac && ./scripts/run-tests.sh` 通过。
- [ ] Debug 构建通过。
- [ ] Release 构建通过。
- [ ] `git diff --check` 通过。
- [ ] 测试输出没有真实密钥、Cookie、密码或完整敏感响应。
- [ ] Provider 真实网络测试若未授权，明确记录为“未执行”；mock 通过不写成真实渠道通过。

## 本地运行和安装包

- [ ] 首次启动、菜单栏图标、首页/用量/设置导航和固定窗口已检查。
- [ ] 余额刷新失败、用量首次 baseline、日/周/月切换、通知和设置保存已检查。
- [ ] 普通 Keychain 读写不会触发 Touch ID 或密码弹窗。
- [ ] 安装包中的版本与 `Apps/Mac/Sources/App/Info.plist` 一致。
- [ ] DMG/PKG 的文件名、大小、SHA-256 和发布说明一致。
- [ ] 签名、公证和安装行为若未完成，明确写未验证；不要用 ad-hoc 构建宣称 Developer ID 或公证完成。

## GitHub Release

只有在本地测试、构建和运行证据齐全后，维护者才执行项目既有发布入口：

```bash
cd Apps/Mac
NOTES="面向用户的中文变更摘要" ./scripts/release.sh
```

需要只生成本地包时：

```bash
cd Apps/Mac
SKIP_PUBLISH=1 NOTES="本地试包" ./scripts/release.sh
```

远端检查应单独记录：tag、Release 页面、DMG/PKG/SHA256SUMS 资产、Release notes 和源码提交是否一致。远端 Release 成功不等于用户已经安装。

## 版本后证据

分别记录以下状态：

```text
local_review       本地差异和规则检查
local_tests        本地测试
local_build        Debug/Release 构建
local_package      本地安装资产
runtime_verified   真实 App 运行
remote_release     GitHub Release 和资产
update_verified    应用内检查更新并完成安装
user_installed     用户实际安装确认
```
