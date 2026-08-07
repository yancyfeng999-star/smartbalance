#!/usr/bin/env python3
"""从 Branding/ 源文件生成 AppIcon / AppLogo / MenuBarIcon。

产品要求：
- 安装包 / Dock / AppIcon：浅色有背景（白底）Logo
- 状态栏：浅色无背景彩色 Logo
- 界面 AppLogo：浅色无背景彩色 Logo
"""
from pathlib import Path
from PIL import Image
import shutil

ROOT = Path(__file__).resolve().parents[3]  # 智余/
BRAND = ROOT / "Branding"
APP_BRAND = ROOT / "Apps/Mac/Branding"
ICONSET = ROOT / "Apps/Mac/Sources/App/Resources/Assets.xcassets/AppIcon.appiconset"
MENU = ROOT / "Apps/Mac/Sources/App/Resources/Assets.xcassets/MenuBarIcon.imageset"
APP_LOGO = ROOT / "Apps/Mac/Sources/App/Resources/Assets.xcassets/AppLogo.imageset"


def resolve(*names: str) -> Path:
    for n in names:
        p = BRAND / n
        if p.exists():
            return p
    raise SystemExit(f"missing under {BRAND}: {names}")


def tight_square(im: Image.Image, pad_ratio: float = 0.10) -> Image.Image:
    im = im.convert("RGBA")
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    w, h = im.size
    side = max(w, h)
    pad = int(side * pad_ratio)
    out = Image.new("RGBA", (side + 2 * pad, side + 2 * pad), (0, 0, 0, 0))
    out.paste(im, ((out.size[0] - w) // 2, (out.size[1] - h) // 2), im)
    return out


def main() -> None:
    light_clear = resolve("logo-light-clear.png", "智余logo浅色模式无背景.png")
    light_bg = resolve("logo-light-bg.jpg", "智余logo浅色模式有背景.jpg")

    # —— 安装包 / Dock：白底彩色 ——
    icon = Image.open(light_bg).convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
    icon.save(BRAND / "app-icon-1024.png", "PNG")
    APP_BRAND.mkdir(parents=True, exist_ok=True)
    shutil.copy2(BRAND / "app-icon-1024.png", APP_BRAND / "app-icon-1024.png")

    for name, px in [
        ("mac_16.png", 16), ("mac_16@2x.png", 32),
        ("mac_32.png", 32), ("mac_32@2x.png", 64),
        ("mac_128.png", 128), ("mac_128@2x.png", 256),
        ("mac_256.png", 256), ("mac_256@2x.png", 512),
        ("mac_512.png", 512), ("mac_512@2x.png", 1024),
    ]:
        icon.resize((px, px), Image.Resampling.LANCZOS).save(ICONSET / name, "PNG")

    # —— 界面 / 状态栏：浅色无背景彩色 ——
    ui = tight_square(Image.open(light_clear), pad_ratio=0.08)
    APP_LOGO.mkdir(parents=True, exist_ok=True)
    for name, px in [("logo_1x.png", 64), ("logo_2x.png", 128), ("logo_3x.png", 192)]:
        ui.resize((px, px), Image.Resampling.LANCZOS).save(APP_LOGO / name, "PNG")

    menu = tight_square(Image.open(light_clear), pad_ratio=0.12)
    menu.resize((18, 18), Image.Resampling.LANCZOS).save(MENU / "menu_1x.png", "PNG")
    menu.resize((36, 36), Image.Resampling.LANCZOS).save(MENU / "menu_2x.png", "PNG")

    print("branding applied: AppIcon=white-bg, AppLogo/MenuBar=light-clear")


if __name__ == "__main__":
    main()
