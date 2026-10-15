"""Layout builders shared by tools/generate_levels.py and tools/make_test_vectors.py
(masks, clumped colouring, obstacle placement, connectivity clean-up)."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import board_sim as bs  # noqa: E402

TITLES = [
    "First Pop", "Gentle Slope", "Score Rush", "Four Winds", "Frozen Dew", "Little Lost Friends",
    "Crystal Heart", "Rock Garden", "Locked Doors", "Guardian of the Grove",
    "Tidal Pearls", "Coral Maze", "Deep Current", "Frost Reef", "Sunken Cage",
    "Whale Song", "Stone Lagoon", "Lockjaw Bay", "Pearl Rush", "Leviathan's Keep",
    "Ember Dunes", "Sand Spirits", "Obsidian Gate", "Cinder Chain", "Mirage Run",
    "Ash Valley", "Caged Constellation", "Magma Lock", "Phoenix Trial", "Mystic Heart",
]


# Shape masks: (col, row, rows) -> keep this cell?
def m_solid(c, r, n):
    return True


def m_pyramid(c, r, n):
    w = bs.row_cols(r)
    margin = (n - 1 - r) * 0.5
    return margin <= c < w - margin


def m_diamond(c, r, n):
    mid = (n - 1) / 2.0
    half = bs.row_cols(r) / 2.0
    spread = half * (1.0 - abs(r - mid) / (mid + 0.5))
    return abs((c + 0.5) - half) <= spread + 0.01


def m_hourglass(c, r, n):
    mid = (n - 1) / 2.0
    half = bs.row_cols(r) / 2.0
    spread = half * (0.35 + 0.65 * abs(r - mid) / (mid + 0.5))
    return abs((c + 0.5) - half) <= spread + 0.01


def m_heart(c, r, n):
    x = ((c + 0.5) / bs.row_cols(r)) * 2 - 1
    y = 1.0 - (r / max(1, n - 1)) * 2.2
    return (x * x + (y - math.sqrt(abs(x))) ** 2) <= 1.05 or r == 0


def m_ring(c, r, n):
    if r <= 1:
        return True
    half = bs.row_cols(r) / 2.0
    return abs((c + 0.5) - half) > 1.8 or r >= n - 2 or r < 2


def m_zigzag(c, r, n):
    phase = (r % 4)
    return not (phase == 2 and 3 <= c <= 5) and not (phase == 0 and r > 0 and c in (7, 8) and r % 8 == 0)


def m_comb(c, r, n):
    return r < 2 or (c % 3 != 1)


MASKS = {"solid": m_solid, "pyramid": m_pyramid, "diamond": m_diamond, "hourglass": m_hourglass,
         "heart": m_heart, "ring": m_ring, "zigzag": m_zigzag, "comb": m_comb}



def pattern_color(pattern, c, r, n_rows, colors):
    x = c + (0.5 if r % 2 else 0.0)
    cy = (n_rows - 1) / 2.0
    if pattern == 'diamond':
        return int((abs(x - 4.5) + abs(r - cy) * 0.9) * 0.85) % colors
    if pattern == 'stripes':
        return int((x + r * 0.9) / 1.6) % colors
    if pattern == 'zigzag':
        return int((x + 2.0 * abs((r % 6) - 3)) / 2.0) % colors
    if pattern == 'chevron':
        return int(abs(x - 4.5) * 0.8 + r * 0.75) % colors
    return 0


def build_rows(rng, n_rows, colors, mask, ice_pct, stones, locks, rescue, pattern=None):
    mask_fn = MASKS[mask]
    cells = {}
    for r in range(n_rows):
        for c in range(bs.row_cols(r)):
            if r == 0 or mask_fn(c, r, n_rows):
                cells[(c, r)] = None
    # colouring: mosaic pattern (like the reference art) or clumped random
    for r in range(n_rows):
        for c in range(bs.row_cols(r)):
            if (c, r) not in cells:
                continue
            if pattern:
                cells[(c, r)] = pattern_color(pattern, c, r, n_rows, colors)
                continue
            opts = []
            for n in bs.neighbors((c, r)):
                if n in cells and cells[n] is not None and n[1] <= r:
                    opts.append(cells[n])
            if opts and rng.random() < 0.58:
                cells[(c, r)] = rng.choice(opts)
            else:
                cells[(c, r)] = rng.randrange(colors)
    kinds = {k: "n" for k in cells}
    keys = sorted(cells, key=lambda k: (k[1], k[0]))
    inner = [k for k in keys if k[1] >= 1]
    # ice
    for k in keys:
        if rng.random() * 100 < ice_pct:
            kinds[k] = "i"
    # stones (never in row 0, avoid neighbours of each other)
    placed = []
    tries = 0
    while len(placed) < stones and tries < 300 and inner:
        tries += 1
        k = rng.choice(inner)
        if k[1] < 1 or kinds[k] == "s":
            continue
        if any(n in placed for n in bs.neighbors(k)):
            continue
        placed.append(k)
        kinds[k] = "s"
    # locks
    tries = 0
    nl = 0
    while nl < locks and tries < 300 and inner:
        tries += 1
        k = rng.choice(inner)
        if kinds[k] in ("n", "i") and k[1] >= 1:
            kinds[k] = "l"
            nl += 1
    # critters (need at least two non-stone neighbours)
    tries = 0
    nr = 0
    while nr < rescue and tries < 400 and inner:
        tries += 1
        k = rng.choice(inner)
        if kinds[k] != "n":
            continue
        nb = [n for n in bs.neighbors(k) if n in cells and kinds[n] in ("n", "i", "l")]
        if len(nb) >= 3:
            kinds[k] = "r"
            nr += 1
    rows = []
    for r in range(n_rows):
        line = ""
        for c in range(bs.row_cols(r)):
            k = (c, r)
            if k not in cells:
                line += "."
            else:
                kd = kinds[k]
                col = cells[k]
                if kd == "n":
                    line += str(col)
                elif kd == "i":
                    line += chr(97 + col)
                elif kd == "l":
                    line += chr(65 + col)
                elif kd == "s":
                    line += "#"
                else:
                    line += "*"
        rows.append(line)
    return strip_unsupported(rows)


def strip_unsupported(rows):
    b = bs.Board()
    b.load_rows(rows)
    res = b._new_result()
    b._drop_floating(res)
    out = []
    for r, line in enumerate(rows):
        chars = list(line)
        for c in range(len(chars)):
            if chars[c] != "." and (c, r) not in b.grid:
                chars[c] = "."
        out.append("".join(chars))
    while out and set(out[-1]) <= {"."}:
        out.pop()
    return out


