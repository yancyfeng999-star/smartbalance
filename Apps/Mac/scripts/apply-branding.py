#!/usr/bin/env python3
"""从 Branding/ 源文件生成 AppIcon / AppLogo / MenuBarIcon。

对齐智额：
- 安装包 / Dock / AppIcon / Mac 通知：浅色有背景（白底）Logo
- 状态栏 / 界面 AppLogo：浅色无背景彩色 Logo
- AppIcon 文件名与智额一致：icon_16x16.png …
- 不依赖 NSWorkspace.setIcon（会写自定义 Icon，通知易锁旧图）
"""
from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]  # 智余/
BRAND = ROOT / "Branding"
APP_BRAND = ROOT / "Apps/Mac/Branding"
ICONSET = ROOT / "Apps/Mac/Sources/App/Resources/Assets.xcassets/AppIcon.appiconset"
MENU = ROOT / "Apps/Mac/Sources/App/Resources/Assets.xcassets/MenuBarIcon.imageset"
APP_LOGO = ROOT / "Apps/Mac/Sources/App/Resources/Assets.xcassets/AppLogo.imageset"
RESOURCES = ROOT / "Apps/Mac/Sources/App/Resources"
ICNS_OUT = RESOURCES / "AppIcon.icns"

# 与智额 AppIcon.appiconset 一致
ICON_SLOTS = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


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


def force_white_bg(im: Image.Image) -> Image.Image:
    """保证 AppIcon 不透明白底（对齐智额 logo-light-on-white）。"""
    im = im.convert("RGBA")
    bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
    bg.alpha_composite(im)
    return bg.convert("RGBA")


def write_iconutil_set(icon_1024: Image.Image, dest_icns: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="zhiyu-iconset-") as td:
        iconset = Path(td) / "AppIcon.iconset"
        iconset.mkdir()
        for name, px in ICON_SLOTS:
            icon_1024.resize((px, px), Image.Resampling.LANCZOS).save(iconset / name, "PNG")
        dest_icns.parent.mkdir(parents=True, exist_ok=True)
        tmp_icns = Path(td) / "AppIcon.icns"
        subprocess.run(
            ["iconutil", "-c", "icns", str(iconset), "-o", str(tmp_icns)],
            check=True,
            capture_output=True,
            text=True,
        )
        shutil.copy2(tmp_icns, dest_icns)


def main() -> None:
    light_clear = resolve("logo-light-clear.png", "智余logo浅色模式无背景.png")
    light_bg = resolve("logo-light-bg.jpg", "智余logo浅色模式有背景.jpg")

    raw = Image.open(light_bg).convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
    icon = force_white_bg(raw)
    icon.save(BRAND / "app-icon-1024.png", "PNG")
    APP_BRAND.mkdir(parents=True, exist_ok=True)
    shutil.copy2(BRAND / "app-icon-1024.png", APP_BRAND / "app-icon-1024.png")

    ICONSET.mkdir(parents=True, exist_ok=True)
    # 删掉旧 mac_*.png 命名，避免 asset catalog 残留
    for old in ICONSET.glob("mac_*.png"):
        old.unlink()
    for name, px in ICON_SLOTS:
        icon.resize((px, px), Image.Resampling.LANCZOS).save(ICONSET / name, "PNG")

    write_iconutil_set(icon, ICNS_OUT)

    ui = tight_square(Image.open(light_clear), pad_ratio=0.08)
    APP_LOGO.mkdir(parents=True, exist_ok=True)
    for name, px in [("logo_1x.png", 64), ("logo_2x.png", 128), ("logo_3x.png", 192)]:
        ui.resize((px, px), Image.Resampling.LANCZOS).save(APP_LOGO / name, "PNG")

    menu = tight_square(Image.open(light_clear), pad_ratio=0.12)
    menu.resize((18, 18), Image.Resampling.LANCZOS).save(MENU / "menu_1x.png", "PNG")
    menu.resize((36, 36), Image.Resampling.LANCZOS).save(MENU / "menu_2x.png", "PNG")

    corner = icon.getpixel((2, 2))
    if corner[0] < 250 or corner[1] < 250 or corner[2] < 250:
        raise SystemExit(f"AppIcon corner not white: {corner}")
    if not ICNS_OUT.exists() or ICNS_OUT.stat().st_size < 10_000:
        raise SystemExit(f"AppIcon.icns missing or too small: {ICNS_OUT}")

    print(
        f"branding applied (智额-aligned): AppIcon=white-bg, "
        f"icns={ICNS_OUT.stat().st_size}B, slots={len(ICON_SLOTS)}"
    )


if __name__ == "__main__":
    main()
