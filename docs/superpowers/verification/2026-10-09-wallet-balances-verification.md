# MiniMax / APINebula 人民币钱包修复验证

日期：2026-10-09。范围：智余钱包余额、浏览器会话导入及刷新失败状态。

## 根因与修复

- MiniMax 当前中国站使用 `minimax.cn`，旧导入条件未覆盖该域名，余额查询仍指向旧 `minimaxi.com` 地址。导入、接口与后台链接已改用当前中国站。
- APINebula 当前登录在 `apinebula.com`，旧逻辑优先选择过期的 `apinebula.ai` 会话。已优先选择当前域名，过滤过期 Cookie，并通过 `/api/user/self` 查询人民币钱包。
- 导入会枚举 Chrome / Edge 的 Default 和 Profile 目录，按最近使用时间排序；同一浏览器 Safe Storage 获取失败后不再对每个 Profile 重复尝试。
- 刷新失败保留上次成功余额及其更新时间，同时显示本次错误。登录失效和普通查询失败采用不同提示。
- 旧账号保存的两个平台内置接口和后台地址在读取时转换为当前地址；自定义地址保留。
- 查询不依赖会员套餐、Token Plan 或当天调用记录。APINebula `quota / 500000` 转为人民币，与网页钱包金额一致。

## 已验证

排障期间以已登录的 Chrome 网页与当前源码运行结果核对：

| 平台 | 网页钱包 | 源码查询 | 导入 / 重复导入 |
| --- | ---: | ---: | --- |
| MiniMax | ¥394.91 | ¥394.91 | 成功 |
| APINebula | ¥199.47 | ¥199.47 | 成功 |

金额为核对时的快照，验收应以当前网页实时余额为准。

相关 XCTest 使用当前 Xcode Swift 编译器直接生成测试 Bundle，再由 XCTest 执行器运行：**33 tests / 0 failures**。

- MiniMax Provider：7 项，覆盖当前接口、金额解析、分组鉴权、空凭据及登录失效。
- APINebula Provider：9 项，覆盖当前接口、人民币换算、Cookie / 用户 ID 鉴权及登录失效。
- RefreshCoordinator：14 项，覆盖查询失败保留金额和时间、部分失败、取消、并发及用量保存失败。
- 旧账号地址升级：3 项，覆盖两个平台旧默认地址迁移及自定义地址保留。新增迁移测试先复现旧地址问题，修复后通过。

`verify-open-source.sh` 与 `git diff --check` 通过。凭据不进入验证文档或提交文件；测试使用模拟凭据。

用户完成 Xcode 27 许可确认后，复跑项目正式 `run-tests.sh`：**385 passed / 0 failed**（Domain 98 + Infrastructure 251 + App 36），Debug 构建成功。

## 0.4.3 安装包验证

- 通过项目 `release.sh` 生成 **0.4.3 / build 87**；Release 构建成功。
- DMG 镜像完整性检查通过；DMG / PKG 中的 App 版本和构建号均与源码一致。
- 安装包内 App 的 ad-hoc 签名校验通过，包含 `arm64` 与 `x86_64`。未进行 Developer ID 签名或 Apple 公证。
- 四份本地中英文安装包 SHA-256 校验全部通过。GitHub 发布资产为英文 DMG、PKG 与 `SHA256SUMS.txt`。
- 发布说明包含本次钱包修复；发布清理使用 `CLEANUP_PROJECT_ONLY=1`，不修改已安装 App 或系统图标缓存。
- 发布入口：[v0.4.3](https://github.com/yancyfeng999-star/smartbalance/releases/tag/v0.4.3)，实际发布状态以该页面为准。

## 未完成的交付验证

- 用户实际下载、安装和重启后的完整应用内更新流程尚未验证。
- 未强制退出当前浏览器账号再登录第二个真实账号；多 Profile 选择和重复导入已检查，但真实跨账号切换仍需验收。
- 用户自行更新；本次未覆盖当前已安装 App。
