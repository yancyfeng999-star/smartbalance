# 智余 · 品牌素材

源文件来自设计稿，请用这里的文件再生成 App 资源，勿直接改 Assets 里的小图后覆盖源文件。

| 文件 | 用途 |
|------|------|
| `logo-light-bg.jpg` / `智余logo浅色模式有背景.jpg` | **安装包 / Dock / Mac 通知 AppIcon**（**必须白底**，禁止黑底） |
| `logo-light-clear.png` / `智余logo浅色模式无背景.png` | 状态栏 + 界面彩色 Logo |
| `logo-dark-clear.png` / `智余logo深色模式无背景.png` | 备用（勿用于 AppIcon） |
| `logo-dark-bg.jpg` / `智余logo深色模式有背景.jpg` | 备用（勿用于 AppIcon） |
| `logo-source.ai` / `智余logo.ai` | 矢量源文件 |
| `app-icon-1024.png` | 由白底 Logo 导出的 1024 图标 |

重新生成资源：

```bash
python3 Apps/Mac/scripts/apply-branding.py
```

脚本会写出：

- `Apps/Mac/.../AppIcon.appiconset/*.png`（白底，来自有背景 JPG）
- `Apps/Mac/Sources/App/Resources/AppIcon.icns`（完整尺寸，通知中心用）
- `AppLogo`：界面彩色 Logo（由浅色无背景缩放）
- `MenuBarIcon`：状态栏用，**对齐智额 AppLogo 规格**（128/256/384 + light/dark），代码里烘焙为 18pt
