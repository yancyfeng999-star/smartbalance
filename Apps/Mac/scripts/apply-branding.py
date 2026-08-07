#!/usr/bin/env python3
"""从 Branding/ 源文件生成 AppIcon / AppLogo / MenuBarIcon。"""
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

def to_template(im: Image.Image, px: int) -> Image.Image:
    im = tight_square(im, pad_ratio=0.14).resize((px * 4, px * 4), Image.Resampling.LANCZOS)
    a = im.split()[3]
    bw = Image.new("RGBA", im.size, (0, 0, 0, 0))
    pxd, ad = bw.load(), a.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            if ad[x, y] > 100:
                pxd[x, y] = (0, 0, 0, 255)
    return bw.resize((px, px), Image.Resampling.LANCZOS)

def main() -> None:
    dark_bg = BRAND / "logo-dark-bg.jpg"
    light_clear = BRAND / "logo-light-clear.png"
    if not dark_bg.exists() or not light_clear.exists():
        raise SystemExit(f"missing masters under {BRAND}")

    icon = Image.open(dark_bg).convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
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

    logo = tight_square(Image.open(light_clear), 0.08)
    APP_LOGO.mkdir(parents=True, exist_ok=True)
    for name, px in [("logo_1x.png", 64), ("logo_2x.png", 128), ("logo_3x.png", 192)]:
        logo.resize((px, px), Image.Resampling.LANCZOS).save(APP_LOGO / name, "PNG")

    src = Image.open(light_clear)
    to_template(src, 18).save(MENU / "menu_1x.png", "PNG")
    to_template(src, 36).save(MENU / "menu_2x.png", "PNG")
    print("branding applied → AppIcon / AppLogo / MenuBarIcon")

if __name__ == "__main__":
    main()
