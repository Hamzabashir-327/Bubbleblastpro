#!/usr/bin/env python3
"""v3 art pass (run AFTER generate_assets.py + generate_assets_v2.py): 'Jungle Bridge' theme.
Jungle-canopy worlds, chunky candy lettering (white + purple outlines) for logo/titles, jungle level nodes."""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_assets as ga  # noqa: E402
import generate_assets_v2 as v2  # noqa: E402

FONT = ga.FONT
OUT = ga.out


# ------------------------------------------------------------------ chunky candy lettering
def render_word(text, top, bottom, size=110, bounce=0, spread=0, outline=(70, 24, 120), pad=40):
    """Each letter: dark-purple outline, thick white outline, gradient face, glossy top. Optional bouncy baseline."""
    font = ImageFont.truetype(FONT, size)
    k = size / 132.0
    o1, o2, o3 = max(6, int(22 * k)), max(4, int(14 * k)), max(3, int(12 * k))
    probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    widths = [(probe.textlength(ch, font=font) if ch != ' ' else size * 0.32) + spread + o1 * 0.55 for ch in text]
    total = int(sum(widths)) + pad * 2 + 40
    h = int(size * 1.9) + pad * 2
    canvas = Image.new("RGBA", (total, h), (0, 0, 0, 0))
    x = pad + 14
    for i, ch in enumerate(text):
        off = 0
        if bounce:
            off = int(math.sin(i * 1.7) * bounce)
        rot = (math.sin(i * 2.3) * 5) if bounce else 0
        lw, lh = int(widths[i] + 120), int(size * 1.9)
        L = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
        d = ImageDraw.Draw(L)
        pos = (60, lh // 2)
        # soft shadow
        sh = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
        ImageDraw.Draw(sh).text((pos[0], pos[1] + max(5, int(12 * k))), ch, font=font, fill=(0, 0, 0, 120), anchor="lm", stroke_width=o1 + 2, stroke_fill=(0, 0, 0, 120))
        L = Image.alpha_composite(L, sh.filter(ImageFilter.GaussianBlur(6)))
        d = ImageDraw.Draw(L)
        d.text(pos, ch, font=font, fill=outline + (255,), anchor="lm", stroke_width=o1, stroke_fill=outline + (255,))
        d.text(pos, ch, font=font, fill=(255, 255, 255, 255), anchor="lm", stroke_width=o2, stroke_fill=(255, 255, 255, 255))
        mask = Image.new("L", (lw, lh), 0)
        ImageDraw.Draw(mask).text(pos, ch, font=font, fill=255, anchor="lm")
        grad = np.zeros((lh, lw, 4), dtype="uint8")
        ys = np.clip((np.arange(lh)[:, None] - (lh / 2 - size * 0.55)) / (size * 1.1), 0, 1)
        for k in range(3):
            grad[..., k] = (top[k] * (1 - ys) + bottom[k] * ys).astype("uint8")
        grad[..., 3] = 255
        face = Image.fromarray(grad, "RGBA")
        face.putalpha(mask)
        L = Image.alpha_composite(L, face)
        hi = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
        ImageDraw.Draw(hi).rectangle([0, 0, lw, int(lh / 2 - size * 0.05)], fill=(255, 255, 255, 90))
        hi.putalpha(Image.fromarray((np.array(mask) * (np.array(hi.split()[3]) / 255.0)).astype("uint8")))
        L = Image.alpha_composite(L, hi)
        if rot:
            L = L.rotate(rot, resample=Image.BICUBIC, center=(60, lh // 2))
        canvas.alpha_composite(L, (int(x - 60), off))
        x += widths[i]
    return canvas.crop(canvas.getbbox())


def save_word(name, text, **kw):
    img = render_word(text, **kw)
    img.save(OUT("assets/ui", f"title_{name}.png"))
    return img


def make_titles_v3():
    gold = dict(top=(255, 248, 140), bottom=(255, 170, 10))
    pink = dict(top=(255, 190, 210), bottom=(255, 60, 120))
    cyan = dict(top=(190, 250, 255), bottom=(30, 160, 255))
    for text, name, st in [("SELECT LEVEL", "select_level", gold), ("LEVEL COMPLETE!", "level_complete", gold), ("GAME OVER", "game_over", pink),
                           ("PAUSED", "paused", cyan), ("SHOP", "shop", cyan), ("SETTINGS", "settings", cyan), ("TROPHIES", "trophies", gold),
                           ("DAILY REWARD", "daily", gold), ("BOSS", "boss", pink), ("TIME'S UP!", "time_up", pink)]:
        save_word(name, text, size=84, spread=6, **st)


def make_logo_v3():
    w, h = 760, 470
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    a = render_word("BUBBLE", top=(255, 246, 120), bottom=(255, 168, 0), size=132, bounce=9, spread=-2)
    b = render_word("BLAST", top=(170, 245, 255), bottom=(20, 140, 255), size=132, bounce=9, spread=-2)
    for im, y in ((a, 70), (b, 200)):
        sc = min(1.0, (w - 30) / im.width)
        im = im.resize((int(im.width * sc), int(im.height * sc)), Image.LANCZOS)
        img.alpha_composite(im, ((w - im.width) // 2, y))
    # three little candy bubbles on top, like the reference logo
    for ci, bx, by, bs in [(1, 250, 4, 74), (0, 330, 28, 70), (3, 420, 6, 74)]:
        bub = v2.candy_bubble(ga.BUBBLE_COLORS[ci], bs)
        img.alpha_composite(bub, (bx, by))
    d = ImageDraw.Draw(img)
    bx, by = w / 2, 392
    d.rounded_rectangle([bx - 118, by - 44 + 8, bx + 118, by + 44 + 8], radius=34, fill=(60, 10, 60, 160))
    d.rounded_rectangle([bx - 118, by - 44, bx + 118, by + 44], radius=34, fill=(255, 70, 120, 255), outline=(255, 255, 255, 255), width=7)
    d.text((bx, by + 3), "PRO", font=ImageFont.truetype(FONT, 78), fill=(255, 238, 140, 255), anchor="mm", stroke_width=5, stroke_fill=(120, 10, 60, 255))
    img.crop(img.getbbox()).save(OUT("assets/ui", "logo.png"))


# ------------------------------------------------------------------ jungle canopy worlds
def leaf(d, x, y, length, width, ang, fill):
    pts = []
    for t in range(0, 360, 30):
        a = math.radians(t)
        px, py = math.cos(a) * length / 2, math.sin(a) * width / 2
        pts.append((x + px * math.cos(ang) - py * math.sin(ang), y + px * math.sin(ang) + py * math.cos(ang)))
    d.polygon(pts, fill=fill)


def leaf_layer(rnd, W, H, palette, count, smin, smax):
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for _ in range(count):               # tree crowns
        x, y = rnd.randint(-60, W + 60), rnd.randint(-60, H + 60)
        r = rnd.randint(smin, smax)
        base = rnd.choice(palette)
        d.ellipse([x - r, y - r, x + r, y + r], fill=tuple(int(c * 0.55) for c in base) + (255,))
        d.ellipse([x - r * 0.92, y - r * 0.95, x + r * 0.9, y + r * 0.85], fill=tuple(int(c * 0.8) for c in base) + (255,))
        for _ in range(int(r * 0.9)):    # leaves on the crown
            lx, ly = x + rnd.uniform(-r, r) * 0.85, y + rnd.uniform(-r, r) * 0.85
            if (lx - x) ** 2 + (ly - y) ** 2 > (r * 0.9) ** 2:
                continue
            tone = rnd.choice([0.85, 1.0, 1.15, 1.3])
            col = tuple(min(255, int(c * tone)) for c in base)
            leaf(d, lx, ly, rnd.randint(16, 34), rnd.randint(6, 11), rnd.uniform(0, 6.283), col + (255,))
    return lay


def make_worlds_v3():
    W, H = 720, 1280
    specs = [
        ("world_1", [(34, 120, 44), (46, 150, 58), (28, 98, 40), (70, 175, 70)], (14, 70, 34)),
        ("world_2", [(190, 96, 30), (225, 140, 40), (150, 70, 30), (110, 150, 50)], (80, 40, 24)),
        ("world_3", [(20, 110, 120), (30, 150, 140), (16, 80, 110), (40, 170, 150)], (8, 34, 60)),
    ]
    for idx, (name, pal, base) in enumerate(specs):
        rnd = random.Random(300 + idx)
        img = Image.new("RGBA", (W, H), base + (255,))
        for layer, (cnt, a, b) in enumerate([(60, 70, 120), (70, 46, 80), (50, 34, 56)]):
            lay = leaf_layer(rnd, W, H, pal if layer else [tuple(int(c * 0.7) for c in p) for p in pal], cnt, a, b)
            img = Image.alpha_composite(img, lay.filter(ImageFilter.GaussianBlur(0.6)))
        rays = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        rd = ImageDraw.Draw(rays)
        for k in range(7):   # sun shafts through the canopy
            x0 = rnd.randint(-120, 640)
            rd.polygon([(x0, 0), (x0 + 60, 0), (x0 + 330, H * 0.8), (x0 + 120, H * 0.8)], fill=(255, 255, 200, 26))
        img = Image.alpha_composite(img, rays.filter(ImageFilter.GaussianBlur(10)))
        if idx == 2:
            fl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            fd = ImageDraw.Draw(fl)
            for _ in range(60):
                x, y = rnd.randint(0, W), rnd.randint(0, H)
                fd.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(190, 255, 190, 230))
                fd.ellipse([x - 9, y - 9, x + 9, y + 9], fill=(190, 255, 190, 40))
            img = Image.alpha_composite(img, fl)
        vg = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        vd = ImageDraw.Draw(vg)
        for k in range(14):
            vd.rectangle([k * 3, k * 3, W - k * 3, H - k * 3], outline=(0, 20, 0, 9))
        img = Image.alpha_composite(img, vg)
        img.convert("RGB").save(OUT("assets/backgrounds", f"{name}.png"))


def make_nodes_v3():
    v2.node_image("open", (120, 235, 110), (20, 145, 50), (255, 255, 255)).save(OUT("assets/ui", "node_open.png"))
    v2.node_image("done", (255, 244, 130), (255, 150, 10), (255, 255, 255)).save(OUT("assets/ui", "node_done.png"))
    v2.node_image("locked", (170, 140, 105), (90, 62, 38), (230, 205, 160), "lock").save(OUT("assets/ui", "node_locked.png"))
    v2.node_image("boss", (255, 130, 140), (190, 20, 55), (255, 235, 200), "crown").save(OUT("assets/ui", "node_boss.png"))


def make_icons_v3():
    n = 96
    s = 4
    # hamburger menu
    img = Image.new("RGBA", (n * s, n * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, y in enumerate((30, 48, 66)):
        d.rounded_rectangle([22 * s, (y - 5) * s, 74 * s, (y + 5) * s], radius=5 * s, fill=(255, 255, 255, 255))
    img.resize((n, n), Image.LANCZOS).save(OUT("assets/ui", "menu.png"))
    # back arrow
    img = Image.new("RGBA", (n * s, n * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(58 * s, 22 * s), (58 * s, 74 * s), (24 * s, 48 * s)], fill=(255, 255, 255, 255))
    img.resize((n, n), Image.LANCZOS).save(OUT("assets/ui", "back.png"))
    # small padlock
    img = Image.new("RGBA", (n * s, n * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.arc([32 * s, 14 * s, 64 * s, 52 * s], 180, 360, fill=(255, 255, 255, 255), width=7 * s)
    d.rounded_rectangle([26 * s, 42 * s, 70 * s, 78 * s], radius=7 * s, fill=(255, 255, 255, 255))
    d.ellipse([44 * s, 54 * s, 52 * s, 62 * s], fill=(120, 80, 20, 255))
    img.resize((n, n), Image.LANCZOS).save(OUT("assets/ui", "lock_small.png"))


if __name__ == "__main__":
    make_titles_v3()
    make_logo_v3()
    make_worlds_v3()
    make_nodes_v3()
    make_icons_v3()
    print("v3 jungle art generated")
