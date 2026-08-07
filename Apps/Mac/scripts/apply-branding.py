#!/usr/bin/env python3
"""从 Branding/ 源文件生成 AppIcon / AppLogo / MenuBarIcon。

对齐智额：
- 安装包 / Dock / AppIcon / Mac 通知：浅色有背景（白底）Logo
- 状态栏 / 界面 AppLogo：浅色无背景彩色 Logo（真透明，禁止白边）
- AppIcon 文件名与智额一致：icon_16x16.png …
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


def zero_transparent_rgb(im: Image.Image) -> Image.Image:
    """透明像素 RGB 必须为 0。源稿常见 (255,255,255,0)，缩小后会渗出白底/白边。"""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                px[x, y] = (0, 0, 0, 0)
            elif a < 255:
                # 预乘友好：半透明也压掉白底 RGB
                px[x, y] = (
                    min(255, (r * a) // 255),
                    min(255, (g * a) // 255),
                    min(255, (b * a) // 255),
                    a,
                )
    return im


def resize_rgba(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """预乘 alpha 再缩放，避免 LANCZOS 把白透明像素渗成白方块。"""
    im = zero_transparent_rgb(im.convert("RGBA"))
    r, g, b, a = im.split()
    # 预乘
    r = Image.composite(r, Image.new("L", im.size, 0), a)
    g = Image.composite(g, Image.new("L", im.size, 0), a)
    b = Image.composite(b, Image.new("L", im.size, 0), a)
    r = r.resize(size, Image.Resampling.LANCZOS)
    g = g.resize(size, Image.Resampling.LANCZOS)
    b = b.resize(size, Image.Resampling.LANCZOS)
    a = a.resize(size, Image.Resampling.LANCZOS)
    # 反预乘
    out = Image.merge("RGBA", (r, g, b, a))
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            rr, gg, bb, aa = px[x, y]
            if aa == 0:
                px[x, y] = (0, 0, 0, 0)
            elif aa < 255:
                px[x, y] = (
                    min(255, (rr * 255) // aa),
                    min(255, (gg * 255) // aa),
                    min(255, (bb * 255) // aa),
                    aa,
                )
    return zero_transparent_rgb(out)


def tight_square(im: Image.Image, pad_ratio: float = 0.10) -> Image.Image:
    im = zero_transparent_rgb(im.convert("RGBA"))
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    w, h = im.size
    side = max(w, h)
    pad = int(side * pad_ratio)
    out = Image.new("RGBA", (side + 2 * pad, side + 2 * pad), (0, 0, 0, 0))
    out.paste(im, ((out.size[0] - w) // 2, (out.size[1] - h) // 2), im)
    return zero_transparent_rgb(out)


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


def clear_border(im: Image.Image, px: int = 1) -> Image.Image:
    """外圈强制全透明，避免缩放抗锯齿渗到边缘显方底。"""
    im = im.convert("RGBA")
    w, h = im.size
    px = max(1, min(px, w // 4, h // 4))
    data = im.load()
    for y in range(h):
        for x in range(w):
            if x < px or y < px or x >= w - px or y >= h - px:
                data[x, y] = (0, 0, 0, 0)
    return im


def assert_no_white_bg(im: Image.Image, label: str) -> None:
    """状态栏/界面 logo：不允许出现不透明白底块。"""
    im = im.convert("RGBA")
    w, h = im.size
    white = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = im.getpixel((x, y))
            if a > 200 and r > 245 and g > 245 and b > 245:
                white += 1
    # 中心星点可能有近白，允许极少量；整块白底会占很多像素
    limit = max(4, (w * h) // 50)
    if white > limit:
        raise SystemExit(f"{label}: too many opaque white pixels ({white}), looks like background")


def main() -> None:
    light_clear = resolve("logo-light-clear.png", "智余logo浅色模式无背景.png")
    light_bg = resolve("logo-light-bg.jpg", "智余logo浅色模式有背景.jpg")

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

    # —— 界面 / 状态栏：真透明，预乘缩放防白边 ——
    clear_src = zero_transparent_rgb(Image.open(light_clear))
    ui = tight_square(clear_src, pad_ratio=0.06)
    APP_LOGO.mkdir(parents=True, exist_ok=True)
    for name, px in [("logo_1x.png", 64), ("logo_2x.png", 128), ("logo_3x.png", 192)]:
        out = resize_rgba(ui, (px, px))
        out.save(APP_LOGO / name, "PNG")
        assert_no_white_bg(out, name)

    # 状态栏 18pt：留边 + 清 1px 外圈，杜绝缩放渗白成「方块底」
    menu = tight_square(clear_src, pad_ratio=0.10)
    MENU.mkdir(parents=True, exist_ok=True)
    for name, px in [("menu_1x.png", 18), ("menu_2x.png", 36), ("menu_3x.png", 54)]:
        out = resize_rgba(menu, (px, px))
        out = clear_border(out, 1)
        out.save(MENU / name, "PNG")
        for xy in [(0, 0), (px - 1, 0), (0, px - 1), (px - 1, px - 1)]:
            if out.getpixel(xy)[3] != 0:
                raise SystemExit(f"{name} corner not transparent at {xy}: {out.getpixel(xy)}")
        assert_no_white_bg(out, name)

    corner = icon.getpixel((2, 2))
    if corner[0] < 250 or corner[1] < 250 or corner[2] < 250:
        raise SystemExit(f"AppIcon corner not white: {corner}")
    if not ICNS_OUT.exists() or ICNS_OUT.stat().st_size < 10_000:
        raise SystemExit(f"AppIcon.icns missing or too small: {ICNS_OUT}")

    print(
        f"branding applied: AppIcon=white-bg, MenuBar/AppLogo=true-clear "
        f"(no white fringe), icns={ICNS_OUT.stat().st_size}B"
    )


if __name__ == "__main__":
    main()
