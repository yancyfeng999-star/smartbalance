#!/usr/bin/env python3
"""从 Branding/ 源文件生成 AppIcon / AppLogo / MenuBarIcon。

- AppIcon / 通知：有背景 JPG → 白底 PNG / icns
- 状态栏 / 界面：无背景 PNG，裁内容后缩放（保留透明，外圈强制清空）
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


def force_white_bg(im: Image.Image) -> Image.Image:
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


def zero_clear_rgb(im: Image.Image) -> Image.Image:
    """a==0 时 RGB 置 0，避免缩放渗色。"""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 and (r or g or b):
                px[x, y] = (0, 0, 0, 0)
    return im


def tight_square(im: Image.Image, pad_ratio: float = 0.08) -> Image.Image:
    """按不透明内容裁切后居中到正方形，外圈真透明。"""
    im = zero_clear_rgb(im.convert("RGBA"))
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    w, h = im.size
    side = max(w, h)
    pad = max(1, int(side * pad_ratio))
    out = Image.new("RGBA", (side + 2 * pad, side + 2 * pad), (0, 0, 0, 0))
    out.paste(im, ((out.size[0] - w) // 2, (out.size[1] - h) // 2), im)
    return zero_clear_rgb(out)


def clear_outer(im: Image.Image, px: int = 1) -> Image.Image:
    """外圈强制透明，杜绝缩放抗锯齿在边缘成方框。"""
    im = im.convert("RGBA")
    w, h = im.size
    px = max(1, min(px, w // 4, h // 4))
    data = im.load()
    for y in range(h):
        for x in range(w):
            if x < px or y < px or x >= w - px or y >= h - px:
                data[x, y] = (0, 0, 0, 0)
    return im


def scale_clear(src: Image.Image, px: int, border: int = 1) -> Image.Image:
    out = src.resize((px, px), Image.Resampling.LANCZOS)
    out = zero_clear_rgb(out)
    out = clear_outer(out, border)
    return out


def main() -> None:
    light_clear = resolve("logo-light-clear.png", "智余logo浅色模式无背景.png")
    light_bg = resolve("logo-light-bg.jpg", "智余logo浅色模式有背景.jpg")

    # —— AppIcon：有背景 JPG → 白底 ——
    raw = Image.open(light_bg).convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
    icon = force_white_bg(raw)
    icon.save(BRAND / "app-icon-1024.png", "PNG")
    APP_BRAND.mkdir(parents=True, exist_ok=True)
    shutil.copy2(BRAND / "app-icon-1024.png", APP_BRAND / "app-icon-1024.png")

    ICONSET.mkdir(parents=True, exist_ok=True)
    for old in ICONSET.glob("mac_*.png"):
        old.unlink()
    for name, px in ICON_SLOTS:
        icon.resize((px, px), Image.Resampling.LANCZOS).save(ICONSET / name, "PNG")

    write_iconutil_set(icon, ICNS_OUT)

    # —— 状态栏 / 界面：无背景 PNG，裁内容后缩放 ——
    clear_src = tight_square(Image.open(light_clear), pad_ratio=0.08)

    APP_LOGO.mkdir(parents=True, exist_ok=True)
    for name, px in [("logo_1x.png", 64), ("logo_2x.png", 128), ("logo_3x.png", 192)]:
        scale_clear(clear_src, px, border=1).save(APP_LOGO / name, "PNG")

    MENU.mkdir(parents=True, exist_ok=True)
    for name, px in [("menu_1x.png", 18), ("menu_2x.png", 36), ("menu_3x.png", 54)]:
        border = 2 if px >= 36 else 1
        out = scale_clear(clear_src, px, border=border)
        out.save(MENU / name, "PNG")
        for xy in [(0, 0), (px - 1, 0), (0, px - 1), (px - 1, px - 1)]:
            if out.getpixel(xy)[3] != 0:
                raise SystemExit(f"{name} corner not transparent: {out.getpixel(xy)}")

    corner = icon.getpixel((2, 2))
    if corner[0] < 250 or corner[1] < 250 or corner[2] < 250:
        raise SystemExit(f"AppIcon corner not white: {corner}")
    if not ICNS_OUT.exists() or ICNS_OUT.stat().st_size < 10_000:
        raise SystemExit(f"AppIcon.icns missing or too small: {ICNS_OUT}")

    print(
        f"branding applied: AppIcon=white-bg; "
        f"MenuBar/AppLogo=tight-crop scale of {light_clear.name}; "
        f"icns={ICNS_OUT.stat().st_size}B"
    )


if __name__ == "__main__":
    main()
