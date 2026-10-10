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

## 未完成的交付验证

- Xcode 27 尚未接受许可，`tuist generate` 与 `xcodebuild` 构建被拦截。因此完整项目测试、Release App、DMG / PKG、签名及应用内更新尚未确认；直接运行的上述 XCTest 不能替代这些步骤。
- 未强制退出当前浏览器账号再登录第二个真实账号；多 Profile 选择和重复导入已检查，但真实跨账号切换仍需验收。
- 未覆盖当前已安装 App。源码提交不代表新安装包已发布。
