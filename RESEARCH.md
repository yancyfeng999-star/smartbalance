# 智余 · SmartBalance · 竞品调研与参考仓库

> 调研日期：2026-08-06  
> 产品：**智余（SmartBalance）** — 多平台 API / TokenPlan 余额查询 + 邮件报警  
> 平台 V1：macOS 菜单栏  
> UI 参考：本机已有产品 **智额 (SmartQuota)**

---

## 1. 产品定位：与「智额」的关系

| 维度 | **智额 SmartQuota**（已有） | **本项目 · API 余额查询**（拟做） |
|------|---------------------------|----------------------------------|
| 核心对象 | AI **会员 / 订阅额度**（5H · 7D · 总额） | **API Key / TokenPlan / 预付费余额** |
| 数据来源 | 本机登录态、CLI、Keychain 探针 | API Key、Base URL、中转站账号、订阅 Token |
| 典型场景 | Codex / Kimi / MiniMax / Grok 会员还剩多少 | DeepSeek 还剩 ¥xx、New-API 站余额、OpenRouter 额度 |
| 形态 | Mac 菜单栏 + Windows 托盘 | 待定（建议桌面卡列表，可复用智额视觉） |
| 隐私 | 本机优先、不上传 | 同样建议本机密钥 + 本地缓存 |

**结论**：不是重做智额，而是**补齐「按 Key / 按套餐查钱」**这条线。智额管「会员配额进度条」，本产品管「API 账户余额与 Token 包」。

智额 UI 可直接借鉴：

- 深色玻璃卡片 + 状态色（健康 / 警告 / 危急）
- 首页卡列表 → 设置 Tab
- Provider 图标 + 套餐标签 + 刷新节奏
- 本机密钥存储（Keychain / 凭据管理器）
- 主题可插拔（Dark / Light / CLI…）

源码路径：`../智额/`（Windows React 见 `Apps/Windows/src/`，Mac SwiftUI 见 `Apps/Mac/Sources/App/Views/`）

---

## 2. 已克隆的参考项目

全部在：

```text
API余额查询/references/
├── all-api-hub/      # 中转站余额看板（浏览器扩展）— 最贴近「多账号余额」
├── Rainytoken/       # Android 余额/用量 APP — 最贴近「产品形态」
├── onWatch/          # 多厂商 API 配额守护 + Web 看板
├── openusage/        # 终端统一用量/配额（Go，35+ provider）
├── opencode-quota/   # OpenCode 侧配额插件 + CLI
├── usage-monitor/    # 多 provider 用量监控服务（企业向）
└── openai-balance/   # 早期 OpenAI 余额 CLI（Go，历史参考）
```

### 2.1 [all-api-hub](https://github.com/qixing-jk/all-api-hub) ⭐ 必读

| 项 | 内容 |
|----|------|
| 形态 | Chrome / Edge / Firefox **浏览器扩展** |
| 技术 | TypeScript + React（pnpm） |
| 能力 | New-API / Sub2API 等中转站：余额、用量、签到、凭据库、比价、健康检查、导出到 CherryStudio 等 |
| 余额接口 | 典型 `GET /api/user/self` → `quota` / 消费字段（与 New-API 生态兼容） |
| 可借鉴 | 多站点账号模型、凭据库、余额历史、统一看板信息架构 |

### 2.2 [Rainytoken 雨晴Token](https://github.com/CATMIAOZHI/Rainytoken) ⭐ 产品形态最接近

| 项 | 内容 |
|----|------|
| 形态 | **Android APP** + 桌面小组件 |
| 技术 | Kotlin · Jetpack Compose · Hilt · Room · Retrofit |
| 支持 | DeepSeek 余额(¥)、OpenCode Go、CommandCode Go、Codex/ChatGPT、Ollama Pro |
| 可借鉴 | 仪表盘卡列表、金额大数字、用量图表、下拉刷新、凭证加密、按服务的 Repository 模式 |

### 2.3 [onWatch](https://github.com/onllm-dev/onWatch)

| 项 | 内容 |
|----|------|
| 形态 | 后台 daemon + Material Design 3 **本地 Web 看板** |
| 支持 | Synthetic、Z.ai、Anthropic、Codex、Copilot、MiniMax、Gemini、Cursor、Grok、Kimi… |
| 可借鉴 | 多 provider 并行轮询、SQLite 历史、轻量本地服务架构 |

### 2.4 [openusage](https://github.com/janekbaraniewski/openusage)

| 项 | 内容 |
|----|------|
| 形态 | **终端 TUI**（Go） |
| 能力 | 自动探测本机工具与 API Key；配额 / 花费 / 速率限制；35+ provider |
| 可借鉴 | Provider 抽象层、零配置探测、CLI 报表（daily/weekly/json） |

### 2.5 [opencode-quota](https://github.com/slkiser/opencode-quota)

| 项 | 内容 |
|----|------|
| 形态 | OpenCode 插件 + `opencode-quota show` CLI |
| 支持 | OpenCode Go、Cursor、Copilot、OpenAI、Kimi、阿里 Coding Plan、Z.ai 等 |
| 可借鉴 | TokenPlan / Coding Plan 类额度的探测思路、JSON 输出协议 |

### 2.6 [usage-monitor](https://github.com/The-Focus-AI/usage-monitor)

| 项 | 内容 |
|----|------|
| 形态 | Fastify + React 仪表盘，约 14 家 provider 工厂 |
| 可借鉴 | Provider factory 模式、用量检查表结构、告警钩子 |

### 2.7 [openai-balance](https://github.com/LaoYutang/openai-balance)（历史）

| 项 | 内容 |
|----|------|
| 形态 | Go CLI |
| 注意 | 官方已限制 Key 调 `credit_grants`；用 subscription − usage 估余额的旧思路，**仅作历史参考** |

---

## 3. 生态内其他值得关注（未全量克隆）

| 项目 | 链接 | 备注 |
|------|------|------|
| tokscale | https://github.com/junhoyeo/tokscale | 多 Agent Token 追踪 CLI + 看板，偏本地日志聚合 |
| CodexBar | https://github.com/steipete/CodexBar | macOS 菜单栏，含 OpenAI credit / Admin spend |
| ClaudeMeter | https://github.com/eddmann/ClaudeMeter | Claude 计划用量菜单栏 |
| codexU | https://github.com/shanggqm/codexU | Codex 用量 macOS widget |
| new-api | https://github.com/QuantumNous/new-api | 中转网关本体（余额字段语义来源） |

---

## 4. 余额数据形态（设计域模型时对齐）

不同平台「余额」语义不统一，产品上建议统一成卡片字段：

```text
BalanceCard
├── providerId / displayName / icon
├── authMode          # api_key | oauth | cookie | base_url+token | new_api_session
├── balanceType       # currency | credits | tokens | percent_windows | hybrid
├── amount / unit     # 12.50 / "¥" | "USD" | "credits"
├── used / total      # 可选
├── windows[]         # 5H / 7D / monthly（TokenPlan 类）
├── planLabel / expiresAt
├── status            # healthy | warn | critical | unknown | error
├── updatedAt
└── detail / errorMessage
```

常见数据源类型：

| 类型 | 例子 | 查法 |
|------|------|------|
| 预付货币余额 | DeepSeek、部分国产 API | 官方 balance 接口 + API Key |
| 中转站 quota | New-API / one-api 兼容站 | `/api/user/self` 等 + 站点 token |
| API 平台 credits | OpenRouter、部分聚合 | `/api/v1/credits` 类 |
| TokenPlan / 会员窗 | OpenCode Go、Coding Plan | 订阅用量 API 或 session |
| 仅有 usage 无 balance | 部分 OpenAI 路径 | subscription − usage（脆弱） |

---

## 5. 建议产品形态（基于调研 + 智额 UI）

### 推荐 V1

- **桌面 APP**（优先 Mac 菜单栏 / 跨端 Tauri，风格对齐智额）
- 首页：**余额卡列表**（大数字余额 + 状态色 + 上次刷新）
- 设置：添加账号（Provider 模板 + Key/BaseURL）、刷新间隔、告警阈值
- 密钥：本机安全存储，不上传
- 首批 Provider 建议（按「可 Key 查询」优先）：
  1. DeepSeek 余额  
  2. New-API 兼容中转（BaseURL + Access Token）  
  3. OpenRouter credits  
  4. 1～2 个 TokenPlan（如 OpenCode Go / 常见 Coding Plan）  
  5. 可扩展插件/脚本位（对齐智额 extensions 思路）

### 不建议 V1 做

- 云账号同步、代理充值  
- 完整中转站后台管理（那是 all-api-hub / new-api 的事）  
- 只读本地 CLI 日志的「用量统计」（那是 tokscale / openusage / 智额 的重叠区）

### 与智额的协作

| 用户问题 | 用哪个 |
|----------|--------|
| 我的 ChatGPT Plus / Kimi 会员本周额度还剩多少？ | **智额** |
| 这把 API Key / 这个中转站账号还剩多少钱？ | **本产品** |

可在两款产品设置里互相「了解更多」链接，避免品牌混淆。

---

## 6. 技术路线候选

| 路线 | 优点 | 缺点 |
|------|------|------|
| **A. 复用智额架构**（Mac Swift + Windows Tauri） | UI/工程一致、可共用品牌组件 | 两套代码维护 |
| **B. 纯 Tauri 跨端**（对齐智额 Windows） | 一套 React UI，Mac/Win 同构 | Mac 菜单栏体验需额外打磨 |
| **C. 本地 Web（onWatch 式）** | 开发快 | 不如桌面托盘顺手 |
| **D. 浏览器扩展（all-api-hub 式）** | 中转站场景强 | 与「APP」目标不符 |

**倾向**：V1 用 **B（Tauri + React）** 或 **A 的 Windows 同构再扩 Mac**，视觉直接抄智额 `styles.css` + 卡片体系；探测层参考 Rainytoken Repository + all-api-hub 中转协议 + openusage provider 抽象。

---

## 7. 参考仓库使用方式

```bash
cd "/Users/yancyfeng/Desktop/Mac Dpxx项目/自研软件/API余额查询/references"

# 中转站余额协议 / 账号模型
open all-api-hub/README_CN.md

# Android 余额 APP 信息架构
open Rainytoken/README.md

# 多 provider 轮询 + 看板
open onWatch/README.md

# Provider 探测广度
open openusage/README.md
```

> 说明：`references/` 仅作学习参考，勿直接改子仓库当产品主干；正式代码放在本目录 `Apps/`（待建）。

---

## 8. 下一步（需你确认）

1. **产品名 / 英文名**（例：智钥、TokenBalance、KeyQuota…）  
2. **平台优先级**：仅 Mac / Mac+Windows / 还要 Android？  
3. **首批 4～6 个必须支持的平台清单**  
4. **是否沿用智额视觉体系**（深色玻璃卡、状态色、中文默认）  
5. 确认后出 `PRODUCT.md` + 目录脚手架，再进入实现  

---

## 附录：引用链接速查

- all-api-hub: https://github.com/qixing-jk/all-api-hub  
- Rainytoken: https://github.com/CATMIAOZHI/Rainytoken  
- onWatch: https://github.com/onllm-dev/onWatch  
- openusage: https://github.com/janekbaraniewski/openusage  
- opencode-quota: https://github.com/slkiser/opencode-quota  
- usage-monitor: https://github.com/The-Focus-AI/usage-monitor  
- openai-balance: https://github.com/LaoYutang/openai-balance  
- 智额（UI 参考）: 本机 `../智额/` · https://github.com/yancyfeng999-star/smartquota  
