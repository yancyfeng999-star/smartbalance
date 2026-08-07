#!/usr/bin/env python3
"""从 Branding/ 源文件生成 AppIcon / AppLogo / MenuBarIcon。

产品要求：
- 安装包 / Dock / AppIcon / **Mac 通知**：浅色有背景（白底）Logo
- 状态栏：浅色无背景彩色 Logo
- 界面 AppLogo：浅色无背景彩色 Logo

通知中心读的是包内 AppIcon.icns + Launch Services 图标缓存；
因此这里额外用 iconutil 打出完整 .icns，避免 actool 子集导致旧图残留。
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
    """保证 AppIcon 不透明白底（通知/Finder 不会把透明当黑底）。"""
    im = im.convert("RGBA")
    bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
    bg.alpha_composite(im)
    return bg.convert("RGBA")


def write_iconutil_set(icon_1024: Image.Image, dest_icns: Path) -> None:
    """生成完整 macOS iconset → AppIcon.icns。"""
    # iconutil 需要的文件名与尺寸
    slots = [
        ("icon_16x16.png", 16),
        ("diana.k@example.org", 32),
        ("icon_32x32.png", 32),
        ("ivan.p@example.net", 64),
        ("icon_128x128.png", 128),
        ("wendy.h@example.net", 256),
        ("icon_256x256.png", 256),
        ("wendy.h@example.net", 512),
        ("icon_512x512.png", 512),
        ("walt.e@example.net", 1024),
    ]
    with tempfile.TemporaryDirectory(prefix="zhiyu-iconset-") as td:
        iconset = Path(td) / "AppIcon.iconset"
        iconset.mkdir()
        for name, px in slots:
            icon_1024.resize((px, px), Image.Resampling.LANCZOS).save(iconset / name, "PNG")
        dest_icns.parent.mkdir(parents=True, exist_ok=True)
        # 先写临时文件再替换，避免半成品
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

    # —— 安装包 / Dock / 通知：不透明白底彩色 ——
    raw = Image.open(light_bg).convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
    icon = force_white_bg(raw)
    icon.save(BRAND / "app-icon-1024.png", "PNG")
    APP_BRAND.mkdir(parents=True, exist_ok=True)
    shutil.copy2(BRAND / "app-icon-1024.png", APP_BRAND / "app-icon-1024.png")

    for name, px in [
        ("mac_16.png", 16),
        ("mac_16@2x.png", 32),
        ("mac_32.png", 32),
        ("mac_32@2x.png", 64),
        ("mac_128.png", 128),
        ("mac_128@2x.png", 256),
        ("mac_256.png", 256),
        ("mac_256@2x.png", 512),
        ("mac_512.png", 512),
        ("mac_512@2x.png", 1024),
    ]:
        icon.resize((px, px), Image.Resampling.LANCZOS).save(ICONSET / name, "PNG")

    # 完整 icns（通知中心 / Finder 主路径）
    write_iconutil_set(icon, ICNS_OUT)

    # —— 界面 / 状态栏：浅色无背景彩色 ——
    ui = tight_square(Image.open(light_clear), pad_ratio=0.08)
    APP_LOGO.mkdir(parents=True, exist_ok=True)
    for name, px in [("logo_1x.png", 64), ("logo_2x.png", 128), ("logo_3x.png", 192)]:
        ui.resize((px, px), Image.Resampling.LANCZOS).save(APP_LOGO / name, "PNG")

    menu = tight_square(Image.open(light_clear), pad_ratio=0.12)
    menu.resize((18, 18), Image.Resampling.LANCZOS).save(MENU / "menu_1x.png", "PNG")
    menu.resize((36, 36), Image.Resampling.LANCZOS).save(MENU / "menu_2x.png", "PNG")

    # 校验：AppIcon 四角必须是白底（非黑）
    corner = icon.getpixel((2, 2))
    if corner[0] < 250 or corner[1] < 250 or corner[2] < 250:
        raise SystemExit(f"AppIcon corner not white: {corner}")
    if not ICNS_OUT.exists() or ICNS_OUT.stat().st_size < 10_000:
        raise SystemExit(f"AppIcon.icns missing or too small: {ICNS_OUT}")

    print(
        f"branding applied: AppIcon=white-bg, icns={ICNS_OUT.stat().st_size}B, "
        "AppLogo/MenuBar=light-clear"
    )


if __name__ == "__main__":
    main()
