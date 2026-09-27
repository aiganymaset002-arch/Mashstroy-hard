#!/usr/bin/env python3
"""Делает иконку и логотипы приложения из логотипа Asset МАШСТРОЙ.

Запуск: python3 scripts/make_brand_assets.py  (нужен Pillow)
Источник: Branding/asset-mashstroy-logo.png (эмблема слева, чёрный фон).
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Branding" / "asset-mashstroy-logo.png"
ASSETS = ROOT / "App" / "MashstroyAIControl" / "Assets.xcassets"
EMBLEM_MAX_X = 330  # эмблема левее этой колонки, текст правее
THRESHOLD = 40


def content_box(img, x0, x1):
    px = img.load()
    w, h = img.size
    xs, ys = [], []
    # Отступ 20 px отсекает тонкую рамку по краю исходника.
    for y in range(20, h - 20):
        for x in range(max(x0, 20), min(x1, w - 20)):
            if max(px[x, y]) > THRESHOLD:
                xs.append(x)
                ys.append(y)
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def pad_square(box, margin):
    x0, y0, x1, y1 = box
    side = max(x1 - x0, y1 - y0) * (1 + 2 * margin)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    return tuple(round(v) for v in (cx - side / 2, cy - side / 2, cx + side / 2, cy + side / 2))


def on_black(img, box):
    """Вырезка с чёрными полями, если рамка выходит за картинку."""
    x0, y0, x1, y1 = box
    out = Image.new("RGB", (x1 - x0, y1 - y0), (0, 0, 0))
    out.paste(img.crop((max(x0, 0), max(y0, 0), min(x1, img.width), min(y1, img.height))),
              (max(-x0, 0), max(-y0, 0)))
    return out


def main():
    src = Image.open(SOURCE).convert("RGB")

    # Эмблема круглая: диаметр берём по высоте, всё вне круга (начало текста) закрашиваем чёрным.
    x0, y0, x1, y1 = content_box(src, 0, EMBLEM_MAX_X)
    d = y1 - y0
    circle = (x0, y0, x0 + d, y1)
    masked = Image.new("RGB", src.size, (0, 0, 0))
    mask = Image.new("L", src.size, 0)
    ImageDraw.Draw(mask).ellipse((circle[0] - 2, circle[1] - 2, circle[2] + 2, circle[3] + 2), fill=255)
    masked.paste(src, mask=mask.filter(ImageFilter.GaussianBlur(1)))
    emblem = on_black(masked, pad_square(circle, 0.12))
    icon = emblem.resize((1024, 1024), Image.LANCZOS).filter(ImageFilter.UnsharpMask(2, 60, 2))
    icon.save(ASSETS / "AppIcon.appiconset" / "AppIcon-1024.png", optimize=True)
    emblem.resize((512, 512), Image.LANCZOS).save(ASSETS / "BrandEmblem.imageset" / "BrandEmblem.png", optimize=True)

    x0, y0, x1, y1 = content_box(src, 0, src.width)
    m = 24
    logo = on_black(src, (x0 - m, y0 - m, x1 + m, y1 + m))
    logo.save(ASSETS / "BrandLogo.imageset" / "BrandLogo.png", optimize=True)
    logo.save(ASSETS / "LaunchLogo.imageset" / "LaunchLogo.png", optimize=True)


if __name__ == "__main__":
    main()
