#!/usr/bin/env python3
"""Generates the app icon (512 + 192 + adaptive layers). Run after generate_assets.py."""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_assets as ga  # noqa: E402

ROOT = ga.ROOT
FONT = ga.FONT


def radial_bg(n):
    y, x = np.mgrid[0:n, 0:n]
    d = np.sqrt((x - n * 0.5) ** 2 + (y - n * 0.42) ** 2) / (n * 0.75)
    d = np.clip(d, 0, 1)[..., None]
    inner = np.array([150, 70, 245.0])
    outer = np.array([34, 12, 90.0])
    arr = inner * (1 - d) + outer * d
    ang = np.arctan2(y - n * 0.42, x - n * 0.5)
    rays = (np.sin(ang * 9) * 0.5 + 0.5)[..., None] * (1 - d) * 22
    arr = np.clip(arr + rays, 0, 255)
    return Image.fromarray(arr.astype("uint8"), "RGB").convert("RGBA")


def sparkle(draw, cx, cy, r, alpha=255):
    pts = []
    for i in range(8):
        a = i * math.pi / 4 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.22
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    draw.polygon(pts, fill=(255, 255, 255, alpha))


def compose(n, with_bg=True, ribbon=True):
    S = 4
    img = radial_bg(n * 1) if with_bg else Image.new("RGBA", (n, n), (0, 0, 0, 0))
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    # bubble cluster (centre, size as fraction of n, colour index)
    bubbles = [(0.30, 0.60, 0.30, 3), (0.70, 0.58, 0.28, 0), (0.50, 0.30, 0.26, 1), (0.50, 0.66, 0.38, 4), (0.78, 0.30, 0.17, 5), (0.20, 0.30, 0.15, 2)]
    for fx, fy, fs, ci in sorted(bubbles, key=lambda b: b[2]):
        size = int(n * fs * 1.7)
        shadow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).ellipse([fx * n - size * 0.48, fy * n - size * 0.40, fx * n + size * 0.48, fy * n + size * 0.58], fill=(10, 0, 40, 110))
        layer = Image.alpha_composite(layer, shadow.filter(ImageFilter.GaussianBlur(n * 0.012)))
        b = ga.glossy_bubble(ga.BUBBLE_COLORS[ci], size)
        layer.alpha_composite(b, (int(fx * n - size / 2), int(fy * n - size / 2)))
    d = ImageDraw.Draw(layer)
    for sx, sy, sr in [(0.14, 0.12, 0.07), (0.86, 0.14, 0.05), (0.90, 0.52, 0.035), (0.10, 0.52, 0.03)]:
        sparkle(d, sx * n, sy * n, sr * n, 235)
    if ribbon:
        f = ImageFont.truetype(FONT, int(n * 0.115))
        w, h = n * 0.56, n * 0.15
        cx, cy = n * 0.5, n * 0.875
        d.rounded_rectangle([cx - w / 2, cy - h / 2 + 5, cx + w / 2, cy + h / 2 + 5], radius=h * 0.45, fill=(80, 10, 40, 160))
        d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], radius=h * 0.45, fill=(255, 190, 20, 255), outline=(255, 255, 255, 255), width=max(3, n // 100))
        d.text((cx, cy + 2), "PRO", font=f, fill=(120, 40, 0, 255), anchor="mm")
    return Image.alpha_composite(img, layer)


def main():
    out = os.path.join(ROOT, "assets/icons")
    big = compose(512)
    big.convert("RGB").save(os.path.join(out, "icon.png"))
    big.convert("RGB").resize((192, 192), Image.LANCZOS).save(os.path.join(out, "icon_192.png"))
    # adaptive: foreground uses the central safe zone (66%), background is the gradient
    fg_full = compose(432, with_bg=False, ribbon=True)
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    small = fg_full.resize((int(432 * 0.74), int(432 * 0.74)), Image.LANCZOS)
    fg.alpha_composite(small, ((432 - small.width) // 2, (432 - small.height) // 2))
    fg.save(os.path.join(out, "icon_fg_432.png"))
    radial_bg(432).convert("RGB").save(os.path.join(out, "icon_bg_432.png"))
    print("icons written")


if __name__ == "__main__":
    main()
