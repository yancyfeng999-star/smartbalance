# 项目状态

**版本：** 0.2.0  
**阶段：** 基本功能完成，可本地安装与 GitHub 发版  

## 已完成

- 菜单栏弹层 380×580；深色海军蓝玻璃
- 多平台余额 + 手录 + 人民币折算报警
- 本机 vault 密钥（直读，无指纹）；Mac / SMTP 报警
- 平台 logo；状态栏仅图标
- GitHub Releases 检查更新（下载 zip → 打开 → 退出）
- 打包脚本 → 桌面 app + `releases/` zip

## 仓库布局

```text
Apps/Mac/Sources/{Domain,Infrastructure,App}
docs/  Branding/  releases/
```

## 手工验收

| 场景 | 状态 |
|------|------|
| 桌面 智余.app 安装运行 | ⏳ |
| 真密钥刷新 | ⏳ |
| 检查更新（需先有 Release） | ⏳ |
