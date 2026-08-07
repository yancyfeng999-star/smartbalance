#!/usr/bin/env python3
"""从 Branding/ 源文件生成 AppIcon / AppLogo / MenuBarIcon。

产品要求：
- 安装包 / Dock / AppIcon：浅色无背景彩色 Logo
- 状态栏：浅色无背景彩色 Logo（非模板、非深色底）
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
    light_clear = BRAND / "logo-light-clear.png"
    if not light_clear.exists():
        # 中文文件名回退
        alt = BRAND / "智余logo浅色模式无背景.png"
        if alt.exists():
            light_clear = alt
        else:
            raise SystemExit(f"missing light-clear master under {BRAND}")

    # 浅色无背景：透明底 + 彩色 Logo
    master = tight_square(Image.open(light_clear), pad_ratio=0.10)
    master_1024 = master.resize((1024, 1024), Image.Resampling.LANCZOS)

    # App / Dock / 安装包图标
    master_1024.save(BRAND / "app-icon-1024.png", "PNG")
    APP_BRAND.mkdir(parents=True, exist_ok=True)
    shutil.copy2(BRAND / "app-icon-1024.png", APP_BRAND / "app-icon-1024.png")

    for name, px in [
        ("mac_16.png", 16), ("mac_16@2x.png", 32),
        ("mac_32.png", 32), ("mac_32@2x.png", 64),
        ("mac_128.png", 128), ("mac_128@2x.png", 256),
        ("mac_256.png", 256), ("mac_256@2x.png", 512),
        ("mac_512.png", 512), ("mac_512@2x.png", 1024),
    ]:
        master.resize((px, px), Image.Resampling.LANCZOS).save(ICONSET / name, "PNG")

    # 界面 AppLogo
    APP_LOGO.mkdir(parents=True, exist_ok=True)
    for name, px in [("logo_1x.png", 64), ("logo_2x.png", 128), ("logo_3x.png", 192)]:
        master.resize((px, px), Image.Resampling.LANCZOS).save(APP_LOGO / name, "PNG")

    # 状态栏：彩色浅色无背景（非 template）
    menu_src = tight_square(Image.open(light_clear), pad_ratio=0.12)
    menu_src.resize((18, 18), Image.Resampling.LANCZOS).save(MENU / "menu_1x.png", "PNG")
    menu_src.resize((36, 36), Image.Resampling.LANCZOS).save(MENU / "menu_2x.png", "PNG")

    print("branding applied (light-clear color): AppIcon / AppLogo / MenuBarIcon")


if __name__ == "__main__":
    main()
