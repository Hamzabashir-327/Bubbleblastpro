#!/usr/bin/env python3
"""Creates tests/vectors/cases.json: single-shot scenarios with the outcome the Python
mirror computes. tests/run_tests.gd replays each one with the real GDScript BoardLogic
inside Godot (headless) and fails on any difference, proving both implementations agree.

    python3 tools/make_test_vectors.py
"""
import glob
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import board_sim as bs  # noqa: E402
import generate_levels_v1_helpers as gl  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def rows_of(board, n_rows):
    out = []
    for r in range(n_rows):
        line = ""
        for c in range(bs.row_cols(r)):
            v = board.grid.get((c, r))
            if v is None:
                line += "."
            elif v[1] == bs.NORMAL:
                line += str(v[0])
            elif v[1] == bs.ICE:
                line += chr(97 + v[0])
            elif v[1] == bs.LOCKED:
                line += chr(65 + v[0])
            elif v[1] == bs.STONE:
                line += "#"
            else:
                line += "*"
        out.append(line)
    return out


def cells(lst):
    return sorted([list(x["cell"]) if isinstance(x, dict) else list(x) for x in lst])


def main():
    rng = random.Random(2024)
    boards = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data/levels/level_*.json"))):
        boards.append(json.load(open(path))["rows"])
    for i in range(40):  # extra random boards, including odd shapes
        rows = gl.build_rows(random.Random(5000 + i), rng.randint(4, 10), rng.randint(3, 6),
                             rng.choice(list(gl.MASKS)), rng.choice([0, 15, 30]), rng.randint(0, 5), rng.randint(0, 6), rng.randint(0, 4))
        boards.append(rows)
    cases = []
    cid = 0
    protos = [bs.P_NORMAL] * 5 + [bs.P_RAINBOW, bs.P_BOMB, bs.P_LIGHTNING, bs.P_FIREBALL]
    for rows in boards:
        for _ in range(4):
            origin = rng.choice([bs.ORIGIN, (20.0, 170.0), (30.0, 200.0)])
            start = (origin[0] + 340.0, origin[1] + 880.0)
            ang = math.radians(rng.uniform(13, 167))
            d = (math.cos(ang), -math.sin(ang))
            proj = rng.choice(protos)
            color = rng.randrange(6)
            b = bs.Board()
            b.load_rows(rows)
            if proj == bs.P_FIREBALL:
                tr = b.trace_fireball(start, d, origin)
                res = b.resolve_fireball(tr["destroyed"])
                extra = {"destroyed": sorted(list(c) for c in tr["destroyed"])}
                cell = [-1, -1]
            else:
                tr = b.trace_shot(start, d, origin)
                cell_t = b.landing_cell(tr["end"], origin)
                if cell_t == (-1, -1):
                    continue
                res = b.resolve_landing(cell_t, proj, color)
                extra = {}
                cell = list(cell_t)
            cid += 1
            cases.append({
                "id": cid, "rows": rows, "origin": list(origin), "start": list(start), "dir": list(d),
                "proj": proj, "color": color,
                "expect": {
                    "end": [round(tr["end"][0], 4), round(tr["end"][1], 4)], "points": len(tr["points"]), "cell": cell,
                    "landed": res["landed"], "final_color": res["final_color"],
                    "popped": cells(res["popped"]), "dropped": cells(res["dropped"]), "freed": cells(res["freed"]),
                    "cracked": cells(res["cracked"]), "unlocked": cells(res["unlocked"]),
                    "rescued": res["rescued"], "pop_count": res["pop_count"], "drop_count": res["drop_count"],
                    "score": res["score"], "remaining": len(b.grid), **extra,
                },
            })
    out = os.path.join(ROOT, "tests/vectors/cases.json")
    json.dump(cases, open(out, "w"))
    print("wrote", len(cases), "cases to", out)


if __name__ == "__main__":
    main()
