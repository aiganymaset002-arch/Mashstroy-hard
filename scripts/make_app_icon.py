#!/usr/bin/env python3
"""Рисует временную иконку MASHSTROY AI Control 1024×1024 (RGB, без прозрачности).

Запуск: python3 scripts/make_app_icon.py
Замените результат на иконку от дизайнера перед релизом, если она будет.
"""
import math
import struct
import zlib
from pathlib import Path

SIZE = 1024
NAVY = (13, 46, 82)
NAVY_DARK = (8, 28, 52)
ORANGE = (245, 158, 18)
STEEL = (196, 206, 218)
WHITE = (255, 255, 255)


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def in_round_rect(x, y, x0, y0, x1, y1, r):
    if x < x0 or x > x1 or y < y0 or y > y1:
        return False
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def pixel(x, y):
    # Фон: вертикальный градиент
    color = mix(NAVY, NAVY_DARK, y / SIZE)

    # Лента конвейера с двумя барабанами
    belt = in_round_rect(x, y, 150, 560, 874, 700, 70)
    inner = in_round_rect(x, y, 175, 585, 849, 675, 45)
    if belt and not inner:
        color = STEEL
    for cx in (220, 804):
        d = math.hypot(x - cx, y - 630)
        if d <= 40:
            color = ORANGE if d > 22 else NAVY_DARK

    # Три кирпича на ленте
    for bx in (250, 440, 630):
        if in_round_rect(x, y, bx, 430, bx + 150, 548, 14):
            color = ORANGE

    # Искра ИИ: четырёхлучевая звезда
    sx, sy = x - 512, y - 270
    if abs(sx) ** 0.5 + abs(sy) ** 0.5 <= 11:
        color = WHITE

    # Линии датчиков под лентой
    for i, lx in enumerate((300, 512, 724)):
        if abs(x - lx) <= 8 and 720 <= y <= 800 + i % 2 * 40:
            color = STEEL
    return color


def write_png(path, width, height, rows):
    raw = b"".join(b"\x00" + bytes(c for px in row for c in px) for row in rows)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


if __name__ == "__main__":
    out = Path(__file__).resolve().parent.parent / "App/MashstroyAIControl/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
    rows = [[pixel(x, y) for x in range(SIZE)] for y in range(SIZE)]
    write_png(out, SIZE, SIZE, rows)
    print(f"Иконка сохранена: {out}")
