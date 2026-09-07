#!/usr/bin/env python3
"""Genera iconos PWA desde assets/images/logo_icon.png."""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/images/logo_icon.png"
WEB_ICONS = ROOT / "web/icons"
WEB_ROOT = ROOT / "web"

BG = (11, 16, 30, 255)  # #0B101E AppTheme.navyPrimary
TEAL = (50, 212, 182, 255)  # #32D4B6 accent ring on maskable optional

SIZES = {
    "Icon-72.png": 72,
    "Icon-96.png": 96,
    "Icon-128.png": 128,
    "Icon-144.png": 144,
    "Icon-152.png": 152,
    "Icon-167.png": 167,
    "Icon-192.png": 192,
    "Icon-384.png": 384,
    "Icon-512.png": 512,
    "Icon-maskable-192.png": 192,
    "Icon-maskable-512.png": 512,
}

FAVICON = 48
APPLE_TOUCH = 180


def _fit_square(img: Image.Image, size: int, padding_ratio: float = 0.08) -> Image.Image:
    """Escala el logo con padding sobre fondo navy."""
    canvas = Image.new("RGBA", (size, size), BG)
    inner = int(size * (1 - padding_ratio * 2))
    logo = img.convert("RGBA")
    logo.thumbnail((inner, inner), Image.Resampling.LANCZOS)
    x = (size - logo.width) // 2
    y = (size - logo.height) // 2
    canvas.paste(logo, (x, y), logo)
    return canvas


def _maskable(img: Image.Image, size: int) -> Image.Image:
    """Icono maskable: logo al ~72% con fondo sólido (zona segura PWA)."""
    canvas = Image.new("RGBA", (size, size), BG)
    draw = ImageDraw.Draw(canvas)
    margin = int(size * 0.08)
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=int(size * 0.12),
        fill=BG,
        outline=TEAL,
        width=max(1, size // 64),
    )
    inner = int(size * 0.72)
    logo = img.convert("RGBA")
    logo.thumbnail((inner, inner), Image.Resampling.LANCZOS)
    x = (size - logo.width) // 2
    y = (size - logo.height) // 2
    canvas.paste(logo, (x, y), logo)
    return canvas


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"No se encontró el logo: {SOURCE}")

    WEB_ICONS.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE)

    for name, size in SIZES.items():
        if "maskable" in name:
            out = _maskable(source, size)
        else:
            out = _fit_square(source, size)
        path = WEB_ICONS / name
        out.save(path, format="PNG", optimize=True)
        print(f"✓ {path.relative_to(ROOT)} ({size}px)")

    favicon = _fit_square(source, FAVICON, padding_ratio=0.06)
    favicon_path = WEB_ROOT / "favicon.png"
    favicon.save(favicon_path, format="PNG", optimize=True)
    print(f"✓ {favicon_path.relative_to(ROOT)} ({FAVICON}px)")

    apple = _fit_square(source, APPLE_TOUCH)
    apple_touch = WEB_ICONS / "apple-touch-icon.png"
    apple.save(apple_touch, format="PNG", optimize=True)
    print(f"✓ {apple_touch.relative_to(ROOT)} ({APPLE_TOUCH}px)")


if __name__ == "__main__":
    main()
