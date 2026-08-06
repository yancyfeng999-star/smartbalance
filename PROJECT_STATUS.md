# 智余 SmartBalance — 项目状态（V1）

**日期：** 2026-08-06  
**代码阶段：** Tasks 1–14 实现完成（菜单栏 Mac 客户端）  
**HEAD 参考：** 见 git log `docs: V1 acceptance and user guide`

---

## 已实现（代码就绪）

| 能力 | 说明 |
|------|------|
| API 直查 | DeepSeek · New-API 兼容矩阵 · OpenRouter credits |
| 平台邮件 | IMAP FETCH 解析 · 发件人规则 · 粘贴试解析 · 金额/HTML/千分位 |
| Mac 通知 | 权限 UX · 稳定 id · 测试按钮 |
| 邮件报警 | SMTP 465 TLS · 冷却仅成功写入 · 失败 banner |
| 设置 IA | 8 段拆分（数据源→关于） |
| 视觉 | 智额 token · 空态文案 · 来源徽章 |
| 密钥 | Keychain only；settings.json 无明文密钥 |
| 安装 | `Apps/Mac/scripts/build-test-app.sh` → Desktop |

单测：DomainTests + InfrastructureTests（解析、阈值、Provider mock、SMTP 格式、冷却策略等）。

---

## 手动验收清单（需真密钥 / 真邮箱）

下列场景**未**在本机自动化跑通；发布前请人工打勾。

| # | 场景 | 期望 | 状态 |
|---|------|------|------|
| 1 | 添加 DeepSeek 真 key 刷新 | 卡片金额正确，来源 API | ⏳ 待测 |
| 2 | 添加 New-API 中转 | 点数/USD 展示，401 有可读错误 | ⏳ 待测 |
| 3 | OpenRouter key | credits 剩余展示 | ⏳ 待测 |
| 4 | IMAP + 平台邮件源 | 匹配发件人后更新卡片，来源平台邮件 | ⏳ 待测 |
| 5 | 粘贴试解析 | 金额正确或提示失败 | ⏳ 待测 |
| 6 | 阈值压到很高 | Mac 通知弹出 | ⏳ 待测 |
| 7 | 开 SMTP | 收到报警邮件；测试邮件成功 | ⏳ 待测 |
| 8 | 冷却内再次刷新 | 不重复轰炸 | ⏳ 待测 |
| 9 | 关 API 源只留邮件 | 仅邮件卡片 | ⏳ 待测 |
| 10 | Keychain | 重启 app 无需重填密码 | ⏳ 待测 |

---

## 已知限制 / 问题

1. **SMTP 无 STARTTLS（587）** — 仅隐式 TLS 465；设置页有警告。  
2. **LSUIElement** — 无 Dock 图标；菜单栏用 SF Symbol，AppIcon 供 Finder/包。  
3. **无 Sparkle / 云同步** — V1 明确不做。  
4. **未公证** — `build-test-app.sh` 为本地 ad-hoc 签名；外发需另行 notarize。  
5. **IMAP 实现为轻量协议客户端** — 复杂邮件编码边缘 case 依赖试解析与单测矩阵，真站差异需场景 4/5 验证。

---

## 文档入口

- [PRODUCT.md](./PRODUCT.md)  
- [docs/USER_GUIDE.md](./docs/USER_GUIDE.md)  
- [Apps/Mac/README.md](./Apps/Mac/README.md)  
- [docs/superpowers/plans/2026-08-06-smartbalance-v1.md](./docs/superpowers/plans/2026-08-06-smartbalance-v1.md)  
