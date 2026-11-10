"""Renders the Sharrow mark into every platform icon slot. Usage: python tool/gen_icons.py"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
BG = (14, 15, 18, 255)
FG = (245, 246, 248, 255)
ACCENT = (52, 211, 153, 255)
SS = 4  # supersampling


def mark(draw, size, color, inset=0.0):
    s = size
    k = 1.0 - inset * 2
    o = s * inset

    def p(x, y):
        return (o + x * s * k, o + y * s * k)

    draw.polygon([p(0.74, 0.5), p(0.30, 0.255), p(0.415, 0.5), p(0.30, 0.745)], fill=color)


def app_icon(size, full_bleed=False):
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if full_bleed:
        d.rectangle([0, 0, big, big], fill=BG)
        mark(d, big, FG, inset=0.06)
    else:
        pad = big * 0.06
        d.rounded_rectangle([pad, pad, big - pad, big - pad], radius=big * 0.22, fill=BG)
        mark(d, big, FG, inset=0.1)
    return img.resize((size, size), Image.LANCZOS)


def glyph(size, color, dot=None):
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    mark(d, big, color, inset=-0.08)
    if dot:
        r = big * 0.17
        cx, cy = big * 0.8, big * 0.8
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=dot)
    return img.resize((size, size), Image.LANCZOS)


def main():
    icons = ROOT / "assets" / "icons"
    icons.mkdir(parents=True, exist_ok=True)
    app_icon(1024).save(icons / "app_icon.png")
    app_icon(512).save(icons / "app_icon_512.png")
    glyph(64, FG).save(icons / "tray.png")
    glyph(64, FG, dot=ACCENT).save(icons / "tray_connected.png")
    glyph(64, (30, 30, 34, 255)).save(icons / "tray_light.png")
    glyph(64, (30, 30, 34, 255), dot=ACCENT).save(icons / "tray_light_connected.png")
    tray_app = app_icon(64)
    tray_app.save(icons / "tray_app.png")
    big = app_icon(64 * SS).copy()
    d = ImageDraw.Draw(big)
    r = 64 * SS * 0.2
    cx = cy = 64 * SS * 0.78
    d.ellipse([cx - r - SS * 4, cy - r - SS * 4, cx + r + SS * 4, cy + r + SS * 4], fill=BG)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ACCENT)
    big.resize((64, 64), Image.LANCZOS).save(icons / "tray_app_connected.png")

    ico = app_icon(256)
    ico.save(ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
             sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    app_icon(256).save(icons / "tray.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48)])

    res = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        app_icon(px).save(res / f"mipmap-{folder}" / "ic_launcher.png")
        stat = res / f"drawable-{folder}"
        stat.mkdir(exist_ok=True)
        glyph(px // 2, (255, 255, 255, 255)).save(stat / "ic_stat_sharrow.png")

    for appicon in [ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset",
                    ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"]:
        if not appicon.exists():
            continue
        ios = "ios" in str(appicon)
        for png in appicon.glob("*.png"):
            w = Image.open(png).size[0]
            img = app_icon(w, full_bleed=ios)
            if ios:
                img = img.convert("RGB")
            img.save(png)
    print("icons generated")


if __name__ == "__main__":
    main()
