#!/usr/bin/env python3
"""Generates ALL original image assets for Bubble Blast Pro - Mystic Worlds.

Everything is drawn procedurally with Pillow/numpy, so there is no third-party
artwork. Run from the project root:  python3 tools/generate_assets.py
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "assets/fonts/Poppins-Bold.ttf")

BUBBLE_COLORS = [
    (236, 28, 50),    # 0 red
    (255, 205, 0),    # 1 yellow
    (28, 196, 60),    # 2 green
    (22, 118, 255),   # 3 blue
    (172, 52, 255),   # 4 purple
    (255, 62, 168),   # 5 hot pink
]
S = 128  # bubble sprite size


def out(*parts):
    p = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def ss_canvas(size, scale=4):
    """Supersampled RGBA canvas."""
    return Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0)), scale


def finish(img, size):
    return img.resize((size, size), Image.LANCZOS)


def radial(size, center, radius, inner, outer):
    """Radial gradient disc as numpy RGBA."""
    y, x = np.mgrid[0:size, 0:size]
    d = np.sqrt((x - center[0]) ** 2 + (y - center[1]) ** 2) / radius
    d = np.clip(d, 0, 1)[..., None]
    inner = np.array(inner, dtype=float)
    outer = np.array(outer, dtype=float)
    return inner * (1 - d) + outer * d


def glossy_bubble(color, size=S):
    scale = 4
    n = size * scale
    c = np.array(color, dtype=float)
    light = np.minimum(c * 1.35 + 40, 255)
    dark = c * 0.55
    arr = radial(n, (n * 0.40, n * 0.36), n * 0.62, light, dark)
    rgba = np.zeros((n, n, 4))
    rgba[..., :3] = arr
    y, x = np.mgrid[0:n, 0:n]
    dist = np.sqrt((x - n / 2) ** 2 + (y - n / 2) ** 2)
    r = n * 0.47
    rgba[..., 3] = np.clip((r - dist) * 1.0, 0, 1) * 255
    img = Image.fromarray(rgba.astype("uint8"), "RGBA")
    d = ImageDraw.Draw(img)
    # rim
    d.ellipse([n / 2 - r, n / 2 - r, n / 2 + r, n / 2 + r], outline=tuple(int(v * 0.45) for v in color) + (255,), width=scale * 2)
    # soft highlight
    hl = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.ellipse([n * 0.22, n * 0.14, n * 0.58, n * 0.40], fill=(255, 255, 255, 190))
    hl = hl.filter(ImageFilter.GaussianBlur(scale * 2))
    img = Image.alpha_composite(img, hl)
    d = ImageDraw.Draw(img)
    d.ellipse([n * 0.62, n * 0.66, n * 0.74, n * 0.76], fill=(255, 255, 255, 110))
    return finish(img, size)


def glyph(idx, size=S):
    """Colour-blind friendly symbol drawn on top of each bubble colour."""
    scale = 4
    n = size * scale
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = n / 2
    r = n * 0.15
    fill = (255, 255, 255, 120)
    if idx == 0:    # circle
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)
    elif idx == 1:  # diamond
        d.polygon([(cx, cy - r * 1.2), (cx + r * 1.2, cy), (cx, cy + r * 1.2), (cx - r * 1.2, cy)], fill=fill)
    elif idx == 2:  # triangle
        d.polygon([(cx, cy - r * 1.15), (cx + r * 1.2, cy + r * 0.9), (cx - r * 1.2, cy + r * 0.9)], fill=fill)
    elif idx == 3:  # square
        d.rectangle([cx - r, cy - r, cx + r, cy + r], fill=fill)
    elif idx == 4:  # star
        pts = []
        for i in range(10):
            ang = -math.pi / 2 + i * math.pi / 5
            rr = r * 1.35 if i % 2 == 0 else r * 0.6
            pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
        d.polygon(pts, fill=fill)
    else:           # plus
        d.rectangle([cx - r * 1.2, cy - r * 0.4, cx + r * 1.2, cy + r * 0.4], fill=fill)
        d.rectangle([cx - r * 0.4, cy - r * 1.2, cx + r * 0.4, cy + r * 1.2], fill=fill)
    return finish(img, size)


def make_bubbles():
    for i, col in enumerate(BUBBLE_COLORS):
        img = glossy_bubble(col)
        img = Image.alpha_composite(img, glyph(i))
        img.save(out("assets/bubbles", f"bubble_{i}.png"))


def overlay_ice():
    img, sc = ss_canvas(S)
    n = S * sc
    d = ImageDraw.Draw(img)
    d.ellipse([n * 0.02, n * 0.02, n * 0.98, n * 0.98], fill=(190, 235, 255, 120), outline=(235, 250, 255, 230), width=sc * 4)
    rnd = random.Random(7)
    for _ in range(7):
        x, y = rnd.uniform(0.2, 0.8) * n, rnd.uniform(0.2, 0.8) * n
        a = rnd.uniform(0, math.pi)
        l = rnd.uniform(0.08, 0.16) * n
        d.line([(x - l * math.cos(a), y - l * math.sin(a)), (x + l * math.cos(a), y + l * math.sin(a))], fill=(255, 255, 255, 200), width=sc * 2)
    return finish(img, S)


def overlay_stone():
    n = S * 4
    base = glossy_bubble((120, 124, 134), S * 4)
    img = base
    d = ImageDraw.Draw(img)
    d.line([(n * 0.30, n * 0.30), (n * 0.46, n * 0.50), (n * 0.40, n * 0.70)], fill=(40, 42, 50, 255), width=18)
    d.line([(n * 0.46, n * 0.50), (n * 0.68, n * 0.46)], fill=(40, 42, 50, 255), width=14)
    return finish(img, S)


def overlay_lock():
    img, sc = ss_canvas(S)
    n = S * sc
    d = ImageDraw.Draw(img)
    d.ellipse([n * 0.04, n * 0.04, n * 0.96, n * 0.96], outline=(60, 50, 40, 230), width=sc * 5)
    d.arc([n * 0.34, n * 0.22, n * 0.66, n * 0.56], 180, 360, fill=(235, 235, 240, 255), width=sc * 6)
    d.rounded_rectangle([n * 0.30, n * 0.45, n * 0.70, n * 0.76], radius=sc * 6, fill=(250, 200, 60, 255), outline=(90, 60, 10, 255), width=sc * 3)
    d.ellipse([n * 0.46, n * 0.53, n * 0.54, n * 0.61], fill=(90, 60, 10, 255))
    d.rectangle([n * 0.485, n * 0.58, n * 0.515, n * 0.68], fill=(90, 60, 10, 255))
    return finish(img, S)


def critter():
    """Rescue bubble: a friendly glowing critter inside a cage."""
    img = glossy_bubble((255, 232, 190))
    big = img.resize((S * 4, S * 4), Image.LANCZOS)
    n = S * 4
    d = ImageDraw.Draw(big)
    d.ellipse([n * 0.25, n * 0.22, n * 0.75, n * 0.78], fill=(250, 150, 190, 255), outline=(120, 40, 80, 255), width=8)
    d.polygon([(n * 0.28, n * 0.30), (n * 0.30, n * 0.12), (n * 0.42, n * 0.25)], fill=(250, 150, 190, 255), outline=(120, 40, 80, 255))
    d.polygon([(n * 0.72, n * 0.30), (n * 0.70, n * 0.12), (n * 0.58, n * 0.25)], fill=(250, 150, 190, 255), outline=(120, 40, 80, 255))
    for ex in (0.40, 0.60):
        d.ellipse([n * (ex - 0.045), n * 0.42, n * (ex + 0.045), n * 0.53], fill=(40, 20, 50, 255))
        d.ellipse([n * (ex - 0.015), n * 0.43, n * (ex + 0.015), n * 0.46], fill=(255, 255, 255, 255))
    d.arc([n * 0.42, n * 0.52, n * 0.58, n * 0.64], 20, 160, fill=(120, 40, 80, 255), width=7)
    for k in range(1, 5):  # cage bars
        x = n * (0.14 + k * 0.145)
        d.line([(x, n * 0.08), (x, n * 0.92)], fill=(90, 70, 40, 230), width=10)
    d.ellipse([n * 0.04, n * 0.04, n * 0.96, n * 0.96], outline=(90, 70, 40, 255), width=14)
    return finish(big, S)


def rainbow():
    n = S * 4
    y, x = np.mgrid[0:n, 0:n]
    ang = (np.arctan2(y - n / 2, x - n / 2) + math.pi) / (2 * math.pi)
    import colorsys
    arr = np.zeros((n, n, 4))
    hue = ang
    for hv, idx in zip(np.unique((hue * 360).astype(int)), range(361)):
        pass
    rgb = np.zeros((n, n, 3))
    # vectorised HSV->RGB
    h6 = hue * 6.0
    i = np.floor(h6).astype(int) % 6
    f = h6 - np.floor(h6)
    v = 1.0
    s = 0.75
    p = v * (1 - s)
    q = v * (1 - s * f)
    t = v * (1 - s * (1 - f))
    conds = [i == 0, i == 1, i == 2, i == 3, i == 4, i == 5]
    rs = [v, q, p, p, t, v]
    gs = [t, v, v, q, p, p]
    bs = [p, p, t, v, v, q]
    rgb[..., 0] = np.select(conds, [np.full_like(f, a) if np.isscalar(a) else a for a in rs])
    rgb[..., 1] = np.select(conds, [np.full_like(f, a) if np.isscalar(a) else a for a in gs])
    rgb[..., 2] = np.select(conds, [np.full_like(f, a) if np.isscalar(a) else a for a in bs])
    dist = np.sqrt((x - n / 2) ** 2 + (y - n / 2) ** 2)
    shade = np.clip(1.1 - dist / (n * 0.6), 0.55, 1.0)[..., None]
    arr[..., :3] = rgb * 255 * shade
    arr[..., 3] = np.clip((n * 0.47 - dist), 0, 1) * 255
    img = Image.fromarray(arr.astype("uint8"), "RGBA")
    d = ImageDraw.Draw(img)
    d.ellipse([n * 0.03, n * 0.03, n * 0.97, n * 0.97], outline=(255, 255, 255, 230), width=10)
    hl = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse([n * 0.22, n * 0.14, n * 0.58, n * 0.40], fill=(255, 255, 255, 170))
    hl = hl.filter(ImageFilter.GaussianBlur(10))
    return finish(Image.alpha_composite(img, hl), S)


def bomb():
    base = glossy_bubble((60, 62, 80), S * 4)
    n = S * 4
    d = ImageDraw.Draw(base)
    d.line([(n * 0.55, n * 0.20), (n * 0.66, n * 0.06)], fill=(200, 160, 90, 255), width=14)
    for k in range(8):
        a = k * math.pi / 4
        d.line([(n * 0.68, n * 0.05), (n * 0.68 + 26 * math.cos(a), n * 0.05 + 26 * math.sin(a))], fill=(255, 200, 40, 255), width=8)
    d.ellipse([n * 0.64, n * 0.01, n * 0.72, n * 0.09], fill=(255, 90, 30, 255))
    d.ellipse([n * 0.30, n * 0.50, n * 0.40, n * 0.60], fill=(255, 255, 255, 60))
    return finish(base, S)


def lightning():
    base = glossy_bubble((250, 214, 60), S * 4)
    n = S * 4
    d = ImageDraw.Draw(base)
    pts = [(0.58, 0.12), (0.30, 0.54), (0.48, 0.54), (0.38, 0.88), (0.72, 0.42), (0.54, 0.42)]
    d.polygon([(x * n, y * n) for x, y in pts], fill=(255, 255, 255, 255), outline=(120, 80, 0, 255))
    return finish(base, S)


def fireball():
    n = S * 4
    base = glossy_bubble((255, 96, 20), n)
    d = ImageDraw.Draw(base)
    flame = [(0.50, 0.08), (0.66, 0.30), (0.74, 0.52), (0.64, 0.80), (0.50, 0.88), (0.36, 0.80), (0.26, 0.52), (0.36, 0.30)]
    d.polygon([(x * n, y * n) for x, y in flame], fill=(255, 220, 70, 255), outline=(150, 40, 0, 255))
    inner = [(0.50, 0.38), (0.58, 0.56), (0.54, 0.76), (0.46, 0.76), (0.42, 0.56)]
    d.polygon([(x * n, y * n) for x, y in inner], fill=(255, 255, 230, 255))
    return finish(base, S)


def make_special():
    for name, fn in [("ice", overlay_ice), ("stone", overlay_stone), ("lock", overlay_lock), ("critter", critter),
                     ("rainbow", rainbow), ("bomb", bomb), ("lightning", lightning), ("fireball", fireball)]:
        fn().save(out("assets/bubbles", f"{name}.png"))


# ---------------------------------------------------------------- icons
def icon_canvas(size=96, scale=4):
    n = size * scale
    return Image.new("RGBA", (n, n), (0, 0, 0, 0)), n, scale


def power_icon(name, size=96):
    """Power-up button icon: rounded tile + symbol."""
    img, n, sc = icon_canvas(size)
    d = ImageDraw.Draw(img)
    tile = {
        "rainbow": (120, 80, 220), "bomb": (70, 74, 100), "lightning": (230, 170, 30),
        "fireball": (225, 80, 30), "color_switch": (30, 160, 170), "time_freeze": (60, 130, 230),
    }[name]
    d.rounded_rectangle([n * 0.04, n * 0.04, n * 0.96, n * 0.96], radius=n * 0.22, fill=tile + (255,), outline=(255, 255, 255, 200), width=sc * 3)
    cx = cy = n / 2
    if name == "rainbow":
        for i, col in enumerate([(255, 80, 80), (255, 200, 60), (90, 220, 120), (90, 160, 255)]):
            r = n * (0.34 - i * 0.065)
            d.arc([cx - r, cy - r + n * 0.12, cx + r, cy + r + n * 0.12], 180, 360, fill=col + (255,), width=sc * 6)
    elif name == "bomb":
        d.ellipse([n * 0.27, n * 0.33, n * 0.73, n * 0.80], fill=(25, 25, 35, 255), outline=(255, 255, 255, 220), width=sc * 2)
        d.line([(n * 0.58, n * 0.36), (n * 0.70, n * 0.20)], fill=(230, 190, 110, 255), width=sc * 4)
        d.ellipse([n * 0.66, n * 0.14, n * 0.76, n * 0.24], fill=(255, 190, 40, 255))
        d.ellipse([n * 0.36, n * 0.46, n * 0.46, n * 0.56], fill=(255, 255, 255, 120))
    elif name == "lightning":
        pts = [(0.58, 0.14), (0.28, 0.56), (0.47, 0.56), (0.38, 0.88), (0.74, 0.42), (0.55, 0.42)]
        d.polygon([(x * n, y * n) for x, y in pts], fill=(255, 255, 255, 255))
    elif name == "fireball":
        flame = [(0.50, 0.12), (0.66, 0.34), (0.74, 0.56), (0.64, 0.82), (0.50, 0.88), (0.36, 0.82), (0.26, 0.56), (0.36, 0.34)]
        d.polygon([(x * n, y * n) for x, y in flame], fill=(255, 225, 80, 255))
        d.polygon([(x * n, y * n) for x, y in [(0.5, 0.42), (0.58, 0.60), (0.54, 0.78), (0.46, 0.78), (0.42, 0.60)]], fill=(255, 120, 30, 255))
    elif name == "color_switch":
        for k, col in enumerate([(255, 90, 90), (90, 160, 255)]):
            a0 = k * 180 + 20
            d.arc([n * 0.22, n * 0.22, n * 0.78, n * 0.78], a0, a0 + 130, fill=col + (255,), width=sc * 9)
        for a in (150, 330):
            ax = cx + n * 0.28 * math.cos(math.radians(a))
            ay = cy + n * 0.28 * math.sin(math.radians(a))
            d.polygon([(ax, ay - n * 0.09), (ax + n * 0.09, ay + n * 0.06), (ax - n * 0.09, ay + n * 0.06)], fill=(255, 255, 255, 255))
    elif name == "time_freeze":
        d.ellipse([n * 0.22, n * 0.22, n * 0.78, n * 0.78], fill=(235, 245, 255, 255), outline=(20, 60, 120, 255), width=sc * 3)
        d.line([(cx, cy), (cx, n * 0.32)], fill=(20, 60, 120, 255), width=sc * 4)
        d.line([(cx, cy), (n * 0.64, cy)], fill=(20, 60, 120, 255), width=sc * 4)
        for k in range(6):
            a = math.radians(k * 60)
            d.line([(cx, cy), (cx + n * 0.46 * math.cos(a), cy + n * 0.46 * math.sin(a))], fill=(200, 235, 255, 160), width=sc * 2)
    return finish(img, size)


def finish(img, size):  # noqa: F811  (re-define to support non-square)
    return img.resize((size, size), Image.LANCZOS)


def star_icon(on, size=96):
    img, n, sc = icon_canvas(size)
    d = ImageDraw.Draw(img)
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rr = n * 0.46 if i % 2 == 0 else n * 0.20
        pts.append((n / 2 + rr * math.cos(ang), n / 2 + rr * math.sin(ang) + n * 0.03))
    if on:
        d.polygon(pts, fill=(255, 205, 40, 255), outline=(170, 100, 0, 255))
        d.polygon([(n / 2 + (p[0] - n / 2) * 0.55, n / 2 + (p[1] - n / 2) * 0.55 - n * 0.04) for p in pts], fill=(255, 235, 130, 200))
    else:
        d.polygon(pts, fill=(70, 60, 100, 220), outline=(130, 120, 160, 255))
    return finish(img, size)


def coin_icon(size=64):
    img, n, sc = icon_canvas(size)
    d = ImageDraw.Draw(img)
    d.ellipse([n * 0.06, n * 0.06, n * 0.94, n * 0.94], fill=(255, 196, 30, 255), outline=(150, 90, 0, 255), width=sc * 3)
    d.ellipse([n * 0.20, n * 0.20, n * 0.80, n * 0.80], outline=(210, 140, 10, 255), width=sc * 3)
    f = ImageFont.truetype(FONT, int(n * 0.46))
    d.text((n / 2, n / 2 + n * 0.02), "B", font=f, fill=(150, 90, 0, 255), anchor="mm")
    return finish(img, size)


def pause_icon(size=64):
    img, n, sc = icon_canvas(size)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([n * 0.24, n * 0.20, n * 0.42, n * 0.80], radius=sc * 4, fill=(255, 255, 255, 255))
    d.rounded_rectangle([n * 0.58, n * 0.20, n * 0.76, n * 0.80], radius=sc * 4, fill=(255, 255, 255, 255))
    return finish(img, size)


def swap_icon(size=64):
    img, n, sc = icon_canvas(size)
    d = ImageDraw.Draw(img)
    d.arc([n * 0.18, n * 0.18, n * 0.82, n * 0.82], 200, 340, fill=(255, 255, 255, 255), width=sc * 6)
    d.arc([n * 0.18, n * 0.18, n * 0.82, n * 0.82], 20, 160, fill=(255, 255, 255, 255), width=sc * 6)
    d.polygon([(n * 0.80, n * 0.30), (n * 0.88, n * 0.52), (n * 0.62, n * 0.44)], fill=(255, 255, 255, 255))
    d.polygon([(n * 0.20, n * 0.70), (n * 0.12, n * 0.48), (n * 0.38, n * 0.56)], fill=(255, 255, 255, 255))
    return finish(img, size)


def make_icons():
    for name in ["rainbow", "bomb", "lightning", "fireball", "color_switch", "time_freeze"]:
        power_icon(name).save(out("assets/icons", f"power_{name}.png"))
    star_icon(True).save(out("assets/ui", "star_on.png"))
    star_icon(False).save(out("assets/ui", "star_off.png"))
    coin_icon().save(out("assets/ui", "coin.png"))
    pause_icon().save(out("assets/ui", "pause.png"))
    swap_icon().save(out("assets/ui", "swap.png"))


# ---------------------------------------------------------------- backgrounds
def gradient_bg(top, bottom, w=720, h=1280):
    y = np.linspace(0, 1, h)[:, None, None]
    t = np.array(top, dtype=float)[None, None, :]
    b = np.array(bottom, dtype=float)[None, None, :]
    arr = (t * (1 - y) + b * y) * np.ones((1, w, 1))
    return Image.fromarray(arr.astype("uint8"), "RGB").convert("RGBA")


def make_backgrounds():
    specs = [
        ("world_1", (28, 14, 70), (96, 40, 140), "crystals"),
        ("world_2", (8, 40, 70), (20, 120, 130), "waves"),
        ("world_3", (60, 18, 36), (200, 90, 50), "dunes"),
    ]
    for idx, (name, top, bot, style) in enumerate(specs):
        img = gradient_bg(top, bot)
        rnd = random.Random(idx + 11)
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        for _ in range(60):  # bokeh
            x, y = rnd.randint(0, 720), rnd.randint(0, 1280)
            r = rnd.randint(6, 34)
            a = rnd.randint(14, 40)
            d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, a))
        for _ in range(70):  # stars
            x, y = rnd.randint(0, 720), rnd.randint(0, 700)
            d.ellipse([x, y, x + 2, y + 2], fill=(255, 255, 255, rnd.randint(90, 200)))
        if style == "crystals":
            for k in range(7):
                x = k * 120 + rnd.randint(-20, 20)
                hgt = rnd.randint(160, 340)
                d.polygon([(x, 1280), (x + 40, 1280 - hgt), (x + 80, 1280)], fill=(190, 140, 255, 60))
                d.polygon([(x + 40, 1280 - hgt), (x + 80, 1280), (x + 40, 1280)], fill=(255, 255, 255, 30))
        elif style == "waves":
            for k in range(6):
                base = 1000 + k * 55
                pts = [(x, base + 18 * math.sin(x / 55 + k)) for x in range(0, 741, 20)] + [(740, 1280), (0, 1280)]
                d.polygon(pts, fill=(255, 255, 255, 14))
        else:
            for k in range(4):
                base = 980 + k * 70
                pts = [(x, base + 40 * math.sin(x / 130 + k * 1.7)) for x in range(0, 741, 20)] + [(740, 1280), (0, 1280)]
                d.polygon(pts, fill=(60, 10, 20, 50))
        layer = layer.filter(ImageFilter.GaussianBlur(1.2))
        img = Image.alpha_composite(img, layer)
        img.convert("RGB").save(out("assets/backgrounds", f"{name}.png"))


# ---------------------------------------------------------------- logo + app icon
def make_logo_and_icon():
    f_big = ImageFont.truetype(FONT, 118)
    f_mid = ImageFont.truetype(FONT, 56)
    f_pro = ImageFont.truetype(FONT, 84)
    w, h = 720, 430
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def outlined(xy, text, font, fill, outline, width=9, anchor="mm"):
        x, y = xy
        for dx in range(-width, width + 1, 3):
            for dy in range(-width, width + 1, 3):
                if dx * dx + dy * dy <= width * width:
                    d.text((x + dx, y + dy), text, font=font, fill=outline, anchor=anchor)
        d.text(xy, text, font=font, fill=fill, anchor=anchor)

    outlined((w / 2, 96), "BUBBLE", f_big, (255, 214, 64), (90, 30, 120))
    outlined((w / 2, 214), "BLAST", f_big, (96, 224, 240), (30, 40, 120))
    # PRO badge
    bx, by = w / 2, 322
    d.rounded_rectangle([bx - 110, by - 46, bx + 110, by + 46], radius=30, fill=(236, 64, 96, 255), outline=(255, 255, 255, 255), width=6)
    d.text((bx, by + 2), "PRO", font=f_pro, fill=(255, 255, 255, 255), anchor="mm")
    outlined((w / 2, 402), "MYSTIC WORLDS", f_mid, (255, 255, 255), (60, 30, 100), width=5)
    img.save(out("assets/ui", "logo.png"))

    # App icon (square, 512) and adaptive layers
    n = 512
    bg = gradient_bg((60, 24, 120), (150, 60, 190), n, n)
    bg.save(out("assets/icons", "icon_bg_432.png")) if False else None
    icon = bg.copy()
    ib = glossy_bubble(BUBBLE_COLORS[3], 300)
    ir = glossy_bubble(BUBBLE_COLORS[0], 220)
    iy = glossy_bubble(BUBBLE_COLORS[1], 180)
    icon.alpha_composite(ib, (60, 120))
    icon.alpha_composite(ir, (250, 60))
    icon.alpha_composite(iy, (270, 270))
    d2 = ImageDraw.Draw(icon)
    d2.rounded_rectangle([160, 400, 352, 478], radius=30, fill=(236, 64, 96, 255), outline=(255, 255, 255, 255), width=5)
    d2.text((256, 441), "PRO", font=ImageFont.truetype(FONT, 56), fill=(255, 255, 255, 255), anchor="mm")
    icon.convert("RGB").save(out("assets/icons", "icon.png"))
    icon.convert("RGB").resize((192, 192), Image.LANCZOS).save(out("assets/icons", "icon_192.png"))

    # Adaptive icon layers (432x432, safe zone is the central 66%)
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.alpha_composite(glossy_bubble(BUBBLE_COLORS[3], 190), (70, 120))
    fg.alpha_composite(glossy_bubble(BUBBLE_COLORS[0], 140), (212, 80))
    fg.alpha_composite(glossy_bubble(BUBBLE_COLORS[1], 120), (225, 222))
    fd = ImageDraw.Draw(fg)
    fd.rounded_rectangle([146, 316, 286, 372], radius=22, fill=(236, 64, 96, 255), outline=(255, 255, 255, 255), width=4)
    fd.text((216, 345), "PRO", font=ImageFont.truetype(FONT, 38), fill=(255, 255, 255, 255), anchor="mm")
    fg.save(out("assets/icons", "icon_fg_432.png"))
    gradient_bg((60, 24, 120), (150, 60, 190), 432, 432).convert("RGB").save(out("assets/icons", "icon_bg_432.png"))


if __name__ == "__main__":
    make_bubbles()
    make_special()
    make_icons()
    make_backgrounds()
    make_logo_and_icon()
    print("assets generated")
