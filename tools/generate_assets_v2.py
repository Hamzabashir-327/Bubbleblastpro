#!/usr/bin/env python3
"""v2 art pass (run AFTER generate_assets.py): 3D transparent glass bubbles, 3D title lettering,
'Powered by Hamza' badge, level-map nodes and marker. Everything procedural/original.

    python3 tools/generate_assets_v2.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_assets as ga  # noqa: E402

ROOT = ga.ROOT
FONT = ga.FONT
OUT = lambda *p: ga.out(*p)  # noqa: E731


# ------------------------------------------------------------------ glass bubble
def glass_bubble(color, size=128):
    """Soft-body glass sphere: transparent centre, bright fresnel rim, caustic glow, specular highlights."""
    sc = 4
    n = size * sc
    y, x = np.mgrid[0:n, 0:n]
    u = (x + 0.5) / n * 2 - 1
    v = (y + 0.5) / n * 2 - 1
    r = np.sqrt(u * u + v * v)
    inside = np.clip((0.955 - r) * n / 2.2, 0, 1)
    z = np.sqrt(np.clip(1 - r * r, 0, 1))
    L = np.array([-0.45, -0.6, 0.66])
    L = L / np.linalg.norm(L)
    diff = np.clip(u * L[0] + v * L[1] + z * L[2], 0, 1)
    c = np.array(color, dtype=float)
    light = np.minimum(c * 1.38 + 70, 255)
    deep = c * 0.55
    t = np.clip(diff, 0, 1)[..., None]
    rgb = deep * (1 - t) + light * t
    # caustic glow bottom-right (light focused through the glass)
    cau = np.exp(-(((u - 0.32) / 0.34) ** 2 + ((v - 0.40) / 0.26) ** 2))[..., None]
    rgb = rgb + (light * 0.55) * cau
    # fresnel rim brighter + more opaque
    rim = np.clip((r - 0.62) / 0.33, 0, 1) ** 1.6
    rgb = rgb + (light * 0.55 + 40) * rim[..., None] * 0.55
    alpha = 0.50 + 0.40 * rim + 0.18 * cau[..., 0] + 0.08 * np.clip(v, 0, 1)
    alpha = np.clip(alpha, 0, 0.97) * inside
    arr = np.zeros((n, n, 4))
    arr[..., :3] = np.clip(rgb, 0, 255)
    arr[..., 3] = alpha * 255
    img = Image.fromarray(arr.astype("uint8"), "RGBA")
    d = ImageDraw.Draw(img)
    R0 = n * 0.4775
    d.ellipse([n / 2 - R0, n / 2 - R0, n / 2 + R0, n / 2 + R0], outline=tuple(int(q * 0.38) for q in color) + (200,), width=sc * 2)
    # specular layers
    hl = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.ellipse([n * 0.20, n * 0.13, n * 0.50, n * 0.33], fill=(255, 255, 255, 235))
    hl = hl.filter(ImageFilter.GaussianBlur(sc * 2.2))
    img = Image.alpha_composite(img, hl)
    dot = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dot)
    dd.ellipse([n * 0.30, n * 0.10, n * 0.40, n * 0.16], fill=(255, 255, 255, 255))
    dd.ellipse([n * 0.66, n * 0.70, n * 0.72, n * 0.75], fill=(255, 255, 255, 190))
    dd.arc([n * 0.12, n * 0.12, n * 0.88, n * 0.88], 20, 70, fill=(255, 255, 255, 170), width=sc * 3)
    dd.arc([n * 0.18, n * 0.18, n * 0.82, n * 0.82], 205, 245, fill=(255, 255, 255, 90), width=sc * 2)
    img = Image.alpha_composite(img, dot.filter(ImageFilter.GaussianBlur(sc * 0.7)))
    return img.resize((size, size), Image.LANCZOS)


def candy_bubble(color, size=128):
    """Solid, highly saturated 3D candy sphere: strong shading, dark rim, big glossy highlight."""
    sc = 4
    n = size * sc
    y, x = np.mgrid[0:n, 0:n]
    u = (x + 0.5) / n * 2 - 1
    v = (y + 0.5) / n * 2 - 1
    r = np.sqrt(u * u + v * v)
    inside = np.clip((0.965 - r) * n / 2.2, 0, 1)
    z = np.sqrt(np.clip(1 - r * r, 0, 1))
    L = np.array([-0.5, -0.62, 0.6])
    L = L / np.linalg.norm(L)
    diff = np.clip(u * L[0] + v * L[1] + z * L[2], 0, 1)[..., None]
    c = np.array(color, dtype=float)
    light = np.minimum(c + 95, 255)
    dark = c * 0.46
    rgb = np.where(diff < 0.58, dark + (c - dark) * (diff / 0.58), c + (light - c) * ((diff - 0.58) / 0.42))
    refl = (np.clip((r - 0.70) / 0.26, 0, 1) ** 2 * np.clip(u * 0.5 + v * 0.62 + 0.15, 0, 1))[..., None]
    rgb = rgb + (light - c) * 0.85 * refl
    arr = np.zeros((n, n, 4))
    arr[..., :3] = np.clip(rgb, 0, 255)
    arr[..., 3] = inside * 255
    img = Image.fromarray(arr.astype("uint8"), "RGBA")
    d = ImageDraw.Draw(img)
    R0 = n * 0.4825
    d.ellipse([n / 2 - R0, n / 2 - R0, n / 2 + R0, n / 2 + R0], outline=tuple(int(q * 0.42) for q in color) + (255,), width=sc * 3)
    hl = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse([n * 0.19, n * 0.12, n * 0.52, n * 0.34], fill=(255, 255, 255, 240))
    img = Image.alpha_composite(img, hl.filter(ImageFilter.GaussianBlur(sc * 1.6)))
    sp = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sp)
    sd.ellipse([n * 0.30, n * 0.085, n * 0.40, n * 0.145], fill=(255, 255, 255, 255))
    sd.arc([n * 0.14, n * 0.14, n * 0.86, n * 0.86], 18, 62, fill=(255, 255, 255, 150), width=sc * 3)
    img = Image.alpha_composite(img, sp.filter(ImageFilter.GaussianBlur(sc * 0.6)))
    return img.resize((size, size), Image.LANCZOS)


def make_glass_set():
    """(name kept for the pipeline) Writes bubble_0..5 and the special bubbles on the vivid candy base."""
    orig = ga.glossy_bubble
    ga.glossy_bubble = candy_bubble
    ga.make_bubbles()  # bubble_0..5 (+ small colour-blind glyphs)
    for name, fn in [("ice", ga.overlay_ice), ("stone", ga.overlay_stone), ("lock", ga.overlay_lock), ("critter", ga.critter),
                     ("rainbow", ga.rainbow), ("bomb", ga.bomb), ("lightning", ga.lightning), ("fireball", ga.fireball)]:
        ga.glossy_bubble = orig if name == "stone" else candy_bubble
        fn().save(OUT("assets/bubbles", f"{name}.png"))
    ga.glossy_bubble = orig


# ------------------------------------------------------------------ 3D lettering
def render_title(text, top=(255, 252, 200), bottom=(255, 165, 30), outline=(14, 44, 130), size=96, pad=36):
    font = ImageFont.truetype(FONT, size)
    probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    bbox = probe.textbbox((0, 0), text, font=font, stroke_width=12)
    w, h = bbox[2] - bbox[0] + pad * 2, bbox[3] - bbox[1] + pad * 2 + 16
    pos = (pad - bbox[0], pad - bbox[1])
    base = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # drop shadow
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((pos[0], pos[1] + 14), text, font=font, fill=(0, 0, 0, 140), stroke_width=12, stroke_fill=(0, 0, 0, 140))
    base = Image.alpha_composite(base, sh.filter(ImageFilter.GaussianBlur(7)))
    # outline (extruded downward for the 3D edge)
    ol = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(ol)
    for dy in range(10, 0, -2):
        od.text((pos[0], pos[1] + dy), text, font=font, fill=tuple(int(q * 0.55) for q in outline) + (255,), stroke_width=12, stroke_fill=tuple(int(q * 0.55) for q in outline) + (255,))
    od.text(pos, text, font=font, fill=outline + (255,), stroke_width=12, stroke_fill=outline + (255,))
    base = Image.alpha_composite(base, ol)
    # gradient face
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text(pos, text, font=font, fill=255)
    grad = np.zeros((h, w, 4), dtype="uint8")
    ys = np.linspace(0, 1, h)[:, None]
    for k in range(3):
        grad[..., k] = (top[k] * (1 - ys) + bottom[k] * ys).astype("uint8")
    grad[..., 3] = 255
    face = Image.fromarray(grad, "RGBA")
    face.putalpha(mask)
    base = Image.alpha_composite(base, face)
    # glossy top highlight
    hi = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(hi).rectangle([0, 0, w, int(h * 0.44)], fill=(255, 255, 255, 95))
    hi.putalpha(Image.fromarray((np.array(mask) * (np.array(hi.split()[3]) / 255.0)).astype("uint8")))
    base = Image.alpha_composite(base, hi)
    return base


def title_image(text, name, **kw):
    img = render_title(text, **kw)
    img.save(OUT("assets/ui", f"title_{name}.png"))
    return img.size


def make_titles():
    gold = dict()
    pink = dict(top=(255, 215, 225), bottom=(255, 80, 120), outline=(120, 10, 60))
    cyan = dict(top=(220, 255, 255), bottom=(40, 190, 255), outline=(10, 50, 130))
    for text, name, st in [("SELECT LEVEL", "select_level", gold), ("LEVEL COMPLETE!", "level_complete", gold), ("GAME OVER", "game_over", pink),
                           ("PAUSED", "paused", cyan), ("SHOP", "shop", cyan), ("SETTINGS", "settings", cyan), ("TROPHIES", "trophies", gold),
                           ("DAILY REWARD", "daily", gold), ("BOSS", "boss", pink), ("TIME'S UP!", "time_up", pink)]:
        title_image(text, name, **st)


def sparkle(draw, cx, cy, r, alpha=255):
    pts = []
    for i in range(8):
        a = i * math.pi / 4 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.2
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    draw.polygon(pts, fill=(255, 255, 255, alpha))


def heart(draw, cx, cy, r, fill):
    draw.ellipse([cx - r, cy - r * 0.9, cx, cy + r * 0.1], fill=fill)
    draw.ellipse([cx, cy - r * 0.9, cx + r, cy + r * 0.1], fill=fill)
    draw.polygon([(cx - r * 0.98, cy - r * 0.2), (cx + r * 0.98, cy - r * 0.2), (cx, cy + r * 1.05)], fill=fill)


def make_badge():
    """Loading-screen credit: 'HANDCRAFTED WITH <3 BY  HAMZA' on a candy ribbon."""
    w, h = 700, 190
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([36, 34, w - 36, h - 12], radius=70, fill=(0, 20, 80, 160))
    img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(10)))
    ys = np.linspace(0, 1, h)[:, None]
    arr = np.zeros((h, w, 4), dtype="uint8")
    top, bot = np.array([255, 150, 60]), np.array([255, 60, 130])
    for k in range(3):
        arr[..., k] = (top[k] * (1 - ys) + bot[k] * ys).astype("uint8")
    arr[..., 3] = 255
    g = Image.fromarray(arr, "RGBA")
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([32, 22, w - 32, h - 26], radius=66, fill=255)
    g.putalpha(m)
    img = Image.alpha_composite(img, g)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([32, 22, w - 32, h - 26], radius=66, outline=(255, 255, 255, 255), width=7)
    d.rounded_rectangle([46, 34, w - 46, h - 38], radius=56, outline=(255, 255, 255, 80), width=2)
    small = ImageFont.truetype(FONT, 27)
    d.text((w / 2 - 26, 58), "H A N D C R A F T E D   W I T H", font=small, fill=(255, 255, 255, 255), anchor="mm", stroke_width=3, stroke_fill=(150, 20, 70, 255))
    heart(d, w / 2 + 236, 56, 17, (255, 255, 255, 255))
    heart(d, w / 2 + 236, 56, 12, (255, 70, 110, 255))
    big = render_title("BY HAMZA", top=(255, 255, 255), bottom=(255, 232, 150), outline=(150, 20, 70), size=64, pad=10)
    big = big.resize((int(big.width * 0.92), int(big.height * 0.92)))
    img.alpha_composite(big, (int((w - big.width) / 2), 70))
    d = ImageDraw.Draw(img)
    for sx, sy, sr in [(84, 74, 24), (w - 84, 78, 22), (150, 140, 11), (w - 150, 142, 11), (w / 2 - 250, 38, 9)]:
        sparkle(d, sx, sy, sr, 245)
    img.save(OUT("assets/ui", "powered_by.png"))


def make_logo():
    """Candy-style logo to match the new theme."""
    w, h = 720, 440
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    a = render_title("BUBBLE", top=(255, 252, 200), bottom=(255, 160, 25), outline=(14, 44, 130), size=128, pad=22)
    b = render_title("BLAST", top=(225, 255, 255), bottom=(30, 170, 255), outline=(14, 44, 130), size=128, pad=22)
    for im, y in ((a, -6), (b, 112)):
        sc = min(1.0, (w - 30) / im.width)
        im = im.resize((int(im.width * sc), int(im.height * sc)))
        img.alpha_composite(im, ((w - im.width) // 2, y))
    d = ImageDraw.Draw(img)
    bx, by = w / 2, 322
    d.rounded_rectangle([bx - 112, by - 44 + 7, bx + 112, by + 44 + 7], radius=32, fill=(80, 10, 50, 150))
    d.rounded_rectangle([bx - 112, by - 44, bx + 112, by + 44], radius=32, fill=(255, 70, 110, 255), outline=(255, 255, 255, 255), width=6)
    d.text((bx, by + 3), "PRO", font=ImageFont.truetype(FONT, 78), fill=(255, 235, 140, 255), anchor="mm", stroke_width=4, stroke_fill=(130, 10, 50, 255))
    t = render_title("MYSTIC WORLDS", top=(255, 255, 255), bottom=(190, 235, 255), outline=(14, 44, 130), size=50, pad=12)
    sc = min(1.0, (w - 80) / t.width)
    t = t.resize((int(t.width * sc), int(t.height * sc)))
    img.alpha_composite(t, ((w - t.width) // 2, 376 - t.height // 2 + 14))
    img.save(OUT("assets/ui", "logo.png"))


# ------------------------------------------------------------------ map nodes
def node_image(name, top, bottom, rim, symbol=None, size=144):
    sc = 3
    n = size * sc
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = n / 2
    R0 = n * 0.40
    base_y = n * 0.46
    d.ellipse([cx - R0 * 1.02, base_y - R0 + n * 0.07, cx + R0 * 1.02, base_y + R0 + n * 0.07], fill=(10, 0, 40, 130))  # ground shadow
    d.ellipse([cx - R0, base_y - R0 + n * 0.045, cx + R0, base_y + R0 + n * 0.045], fill=tuple(int(q * 0.5) for q in bottom) + (255,))  # 3D thickness
    arr = np.zeros((n, n, 4))
    y, x = np.mgrid[0:n, 0:n]
    t = np.clip((y - (base_y - R0)) / (2 * R0), 0, 1)[..., None]
    arr[..., :3] = np.array(top) * (1 - t) + np.array(bottom) * t
    arr[..., 3] = 255
    face = Image.fromarray(arr.astype("uint8"), "RGBA")
    m = Image.new("L", (n, n), 0)
    ImageDraw.Draw(m).ellipse([cx - R0, base_y - R0, cx + R0, base_y + R0], fill=255)
    face.putalpha(m)
    img = Image.alpha_composite(img, face)
    d = ImageDraw.Draw(img)
    d.ellipse([cx - R0, base_y - R0, cx + R0, base_y + R0], outline=rim + (255,), width=sc * 5)
    d.ellipse([cx - R0 * 0.82, base_y - R0 * 0.82, cx + R0 * 0.82, base_y + R0 * 0.82], outline=(255, 255, 255, 70), width=sc * 2)
    hl = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse([cx - R0 * 0.62, base_y - R0 * 0.92, cx + R0 * 0.3, base_y - R0 * 0.28], fill=(255, 255, 255, 120))
    img = Image.alpha_composite(img, hl.filter(ImageFilter.GaussianBlur(sc * 3)))
    d = ImageDraw.Draw(img)
    if symbol == "lock":
        d.arc([cx - R0 * 0.28, base_y - R0 * 0.62, cx + R0 * 0.28, base_y - R0 * 0.02], 180, 360, fill=(235, 235, 245, 255), width=sc * 6)
        d.rounded_rectangle([cx - R0 * 0.42, base_y - R0 * 0.2, cx + R0 * 0.42, base_y + R0 * 0.52], radius=sc * 6, fill=(240, 200, 70, 255), outline=(100, 70, 10, 255), width=sc * 3)
        d.ellipse([cx - R0 * 0.07, base_y + R0 * 0.0, cx + R0 * 0.07, base_y + R0 * 0.14], fill=(100, 70, 10, 255))
    elif symbol == "crown":
        pts = [(cx - R0 * 0.55, base_y - R0 * 0.55), (cx - R0 * 0.3, base_y - R0 * 0.85), (cx, base_y - R0 * 0.58), (cx + R0 * 0.3, base_y - R0 * 0.85), (cx + R0 * 0.55, base_y - R0 * 0.55), (cx + R0 * 0.5, base_y - R0 * 0.3), (cx - R0 * 0.5, base_y - R0 * 0.3)]
        d.polygon(pts, fill=(255, 215, 60, 255), outline=(130, 80, 0, 255))
    return img.resize((size, size), Image.LANCZOS)


def make_nodes():
    node_image("open", (110, 235, 235), (20, 150, 190), (255, 255, 255)).save(OUT("assets/ui", "node_open.png"))
    node_image("done", (255, 240, 130), (255, 150, 20), (255, 255, 255)).save(OUT("assets/ui", "node_done.png"))
    node_image("locked", (170, 170, 195), (90, 90, 120), (210, 210, 230), "lock").save(OUT("assets/ui", "node_locked.png"))
    node_image("boss", (255, 150, 170), (200, 20, 70), (255, 235, 200), "crown").save(OUT("assets/ui", "node_boss.png"))
    # glow halo for the current level
    s = 220
    halo = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([20, 20, s - 20, s - 20], fill=(255, 230, 120, 200))
    halo.filter(ImageFilter.GaussianBlur(26)).save(OUT("assets/ui", "node_halo.png"))
    # marker: a little glass bubble with a face
    mk = glass_bubble(ga.BUBBLE_COLORS[4], 120).copy()
    d = ImageDraw.Draw(mk)
    for ex in (42, 78):
        d.ellipse([ex - 8, 52, ex + 8, 74], fill=(35, 15, 60, 255))
        d.ellipse([ex - 3, 55, ex + 3, 61], fill=(255, 255, 255, 255))
    d.arc([44, 66, 76, 90], 20, 160, fill=(35, 15, 60, 255), width=4)
    mk.save(OUT("assets/ui", "marker.png"))


def make_worlds():
    import random
    W, H = 720, 1280
    specs = [
        ("world_1", (70, 205, 255), (24, 125, 238), (8, 46, 140), "reef"),
        ("world_2", (255, 190, 100), (255, 92, 150), (86, 36, 150), "sunset"),
        ("world_3", (12, 24, 80), (22, 96, 140), (6, 34, 70), "aurora"),
    ]
    for idx, (name, c1, c2, c3, style) in enumerate(specs):
        rnd = random.Random(idx + 41)
        y = np.linspace(0, 1, H)[:, None, None]
        t = np.array(c1, float)[None, None, :]; m = np.array(c2, float)[None, None, :]; b = np.array(c3, float)[None, None, :]
        arr = np.where(y < 0.55, t * (1 - y / 0.55) + m * (y / 0.55), m * (1 - (y - 0.55) / 0.45) + b * ((y - 0.55) / 0.45))
        img = Image.fromarray((arr * np.ones((1, W, 1))).astype("uint8"), "RGB").convert("RGBA")
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        if style in ("reef", "sunset"):
            for k in range(6):   # soft light beams
                x0 = rnd.randint(-100, 700)
                d.polygon([(x0, 0), (x0 + 70, 0), (x0 + 320 + k * 20, 900), (x0 + 120, 900)], fill=(255, 255, 255, 22))
        if style == "sunset":
            d.ellipse([W / 2 - 150, 120, W / 2 + 150, 420], fill=(255, 245, 190, 120))
        if style == "aurora":
            for k, col in enumerate([(70, 255, 170, 70), (80, 200, 255, 60), (170, 110, 255, 55)]):
                pts = [(x, 330 + k * 90 + 60 * math.sin(x / 120 + k * 1.7) + 30 * math.sin(x / 47 + k)) for x in range(-20, W + 40, 20)]
                d.polygon(pts + [(W + 40, 120 + k * 60), (-20, 120 + k * 60)], fill=col)
            for _ in range(90):
                x, yy = rnd.randint(0, W), rnd.randint(0, 760)
                d.ellipse([x, yy, x + 2, yy + 2], fill=(255, 255, 255, rnd.randint(90, 230)))
        lay = lay.filter(ImageFilter.GaussianBlur(14 if style == "aurora" else 6))
        img = Image.alpha_composite(img, lay)
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        for _ in range(46):   # glassy bokeh bubbles
            x, yy, r = rnd.randint(0, W), rnd.randint(0, H), rnd.randint(8, 46)
            d.ellipse([x - r, yy - r, x + r, yy + r], outline=(255, 255, 255, rnd.randint(40, 90)), width=2, fill=(255, 255, 255, rnd.randint(8, 24)))
            d.ellipse([x - r * 0.55, yy - r * 0.62, x - r * 0.2, yy - r * 0.3], fill=(255, 255, 255, 70))
        for k in range(4):   # waves / hills at the bottom
            base = 1090 + k * 52
            pts = [(x, base + 16 * math.sin(x / 70 + k * 1.3) + 8 * math.sin(x / 29 + k)) for x in range(0, W + 21, 20)]
            col = [(255, 255, 255, 26), (0, 30, 100, 40), (0, 20, 80, 55), (0, 10, 60, 75)][k]
            d.polygon(pts + [(W, H), (0, H)], fill=col)
        if style == "reef":
            coral = [(255, 96, 140), (255, 150, 60), (190, 90, 255), (60, 220, 170), (255, 220, 70)]
            for k in range(11):   # colourful coral fans along the sea floor
                x = 10 + k * 66 + rnd.randint(-12, 12)
                col = coral[k % len(coral)]
                base_y = H - rnd.randint(0, 28)
                for br in range(5):
                    ang = math.radians(-90 + (br - 2) * 24)
                    ln = rnd.randint(70, 130)
                    ex, ey = x + ln * math.cos(ang), base_y + ln * math.sin(ang)
                    d.line([(x, base_y), (ex, ey)], fill=col + (190,), width=16)
                    d.ellipse([ex - 12, ey - 12, ex + 12, ey + 12], fill=tuple(min(255, q + 40) for q in col) + (210,))
                d.ellipse([x - 22, base_y - 14, x + 22, base_y + 16], fill=col + (230,))
        img = Image.alpha_composite(img, lay.filter(ImageFilter.GaussianBlur(1.1)))
        img.convert("RGB").save(OUT("assets/backgrounds", f"{name}.png"))


if __name__ == "__main__":
    make_glass_set()
    make_titles()
    make_badge()
    make_logo()
    make_worlds()
    make_nodes()
    print("v2 art generated")
