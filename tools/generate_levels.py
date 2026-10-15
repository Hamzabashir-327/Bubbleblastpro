#!/usr/bin/env python3
"""Generates data/levels/level_001..030.json (v2 rules: FEWER bubbles + SLOWLY SINKING ceiling).

Layouts are seeded procedural shapes. After each shot the ceiling sinks `descent.shot` px
(+ `descent.miss` px more when the shot popped nothing); the level is lost when the lowest bubble
reaches the red line. The descent speed is TUNED per level by playing it with the greedy bot
(board_sim.bot_play_descent, no power-ups) so that the bot wins at least ~85% of the time.
`shots` in the file is the PAR used for the end bonus (it is NOT a hard limit any more).

    python3 tools/generate_levels.py      # resumable; slow on one CPU
"""
import json
import math
import os
import random
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import board_sim as bs  # noqa: E402
import generate_levels_v1_helpers as h  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRIALS = 8

TITLES = h.TITLES
PATTERNS = [None, 'diamond', 'stripes', None, 'zigzag', 'chevron', 'diamond', None, 'stripes', 'chevron']  # by level_id % 10
TIPS = {
    1: "Bubbles slowly sink. Clear them all before they touch the red line!",
    2: "Bounce shots off the walls to reach tricky spots.",
    3: "Reach the target score before the bubbles reach the line.",
    5: "Ice bubbles crack on the first match and pop on the next.",
    6: "Free the critters by popping bubbles next to them.",
    8: "Stone bubbles never pop. Cut them loose from above!",
    9: "Locked bubbles open when a neighbour pops.",
    10: "Boss puzzle: a bit of everything. Good luck!",
    12: "Timed level. Time Freeze can pause the clock.",
}

# (rows, colours, mask, ice%, stones, locks, rescue, objective, timed)  - smaller than v1 on purpose
SPEC = [
    (5, 3, "solid", 0, 0, 0, 0, "clear", False),
    (6, 3, "pyramid", 0, 0, 0, 0, "clear", False),
    (6, 3, "solid", 0, 0, 0, 0, "score", False),
    (6, 4, "solid", 0, 0, 0, 0, "clear", False),
    (6, 4, "pyramid", 14, 0, 0, 0, "clear", False),
    (6, 4, "solid", 0, 0, 0, 3, "rescue", False),
    (7, 4, "diamond", 14, 0, 0, 0, "clear", False),
    (6, 4, "solid", 0, 2, 0, 0, "clear", False),
    (6, 4, "solid", 0, 0, 4, 0, "clear", False),
    (8, 5, "heart", 12, 2, 2, 3, "clear", False),
    (7, 4, "hourglass", 10, 0, 0, 0, "score", False),
    (7, 5, "comb", 8, 1, 0, 0, "clear", True),
    (7, 5, "solid", 12, 2, 0, 0, "clear", False),
    (7, 5, "diamond", 14, 2, 3, 0, "clear", False),
    (7, 5, "solid", 8, 1, 0, 4, "rescue", True),
    (7, 5, "zigzag", 12, 2, 0, 0, "score", False),
    (7, 5, "pyramid", 10, 3, 3, 0, "clear", False),
    (7, 5, "hourglass", 12, 2, 4, 0, "clear", True),
    (7, 5, "solid", 14, 2, 0, 0, "score", False),
    (8, 5, "heart", 14, 3, 3, 4, "clear", False),
    (7, 5, "ring", 12, 2, 0, 0, "clear", False),
    (7, 6, "comb", 12, 2, 2, 0, "clear", True),
    (8, 5, "diamond", 14, 3, 3, 0, "clear", False),
    (8, 6, "zigzag", 14, 2, 4, 0, "score", False),
    (7, 5, "solid", 12, 2, 3, 4, "rescue", True),
    (8, 6, "hourglass", 16, 3, 4, 0, "clear", False),
    (8, 6, "ring", 14, 3, 4, 4, "rescue", False),
    (8, 6, "pyramid", 16, 3, 4, 0, "clear", True),
    (8, 6, "solid", 16, 3, 4, 0, "score", False),
    (8, 6, "heart", 16, 3, 4, 4, "clear", False),
]


def descent_for(level_id, scale):
    return {"shot": round((4.0 + 0.14 * level_id) * scale, 1), "miss": round((9.0 + 0.30 * level_id) * scale, 1)}


def run(rows, objective, descent, seed, trials=TRIALS):
    return [bs.bot_play_descent(rows, objective, descent, random.Random(seed * 1000 + t)) for t in range(trials)]


def tune(level_id, rows, obj_type):
    b = bs.Board()
    b.load_rows(rows)
    crit = b.count_kind(bs.RESCUE)
    seed = level_id
    easy = descent_for(level_id, 0.5)
    if obj_type == "rescue":
        objective = {"type": "rescue", "target": crit}
    elif obj_type == "score":
        probe = [r for r in run(rows, {"type": "clear"}, easy, seed) if r["won"]]
        if not probe:
            return None
        objective = {"type": "score", "target": int(round(0.7 * statistics.median([r["score"] for r in probe]) / 50.0)) * 50}
    else:
        objective = {"type": "clear"}
    # strongest descent the bot can still beat >= 85% of the time (levels get harder, never unfair)
    chosen = None
    cap = min(3.4, 1.0 + 0.1 * level_id)  # early levels stay gentle, late ones push harder
    for scale in [x for x in (3.4, 2.8, 2.3, 1.9, 1.6, 1.35, 1.15, 1.0, 0.8, 0.65, 0.5, 0.4) if x <= cap + 1e-9]:
        d = descent_for(level_id, scale)
        res = run(rows, objective, d, seed + 11)
        rate = sum(1 for r in res if r["won"]) / len(res)
        if rate >= 0.85:
            chosen = (d, res, rate, scale)
            break
    if chosen is None:
        return None
    d, res, rate, scale = chosen
    wins = [r for r in res if r["won"]]
    par = int(statistics.median([r["shots"] for r in wins])) + 1
    totals = [r["score"] + 50 * max(0, par - r["shots"]) for r in wins]
    med = statistics.median(totals)
    stars = [int(round(0.9 * med / 50.0)) * 50, int(round(1.3 * med / 50.0)) * 50]
    if stars[1] <= stars[0]:
        stars[1] = stars[0] + 50
    shots_sorted = sorted(r["shots"] for r in wins)
    p90 = shots_sorted[min(len(shots_sorted) - 1, int(len(shots_sorted) * 0.9))]
    return objective, par, d, stars, {"rate": rate, "median_shots": statistics.median(shots_sorted), "p90": p90, "scale": scale, "critters": crit}


def main():
    outdir = os.path.join(ROOT, "data/levels")
    os.makedirs(outdir, exist_ok=True)
    cache_path = os.path.join(ROOT, "tools/.level_report_cache.json")
    cache = json.load(open(cache_path)) if os.path.exists(cache_path) else {}
    lines = ["# Level report (generated by tools/generate_levels.py)", "",
             "Rules v2: few bubbles, ceiling sinks after every shot. `Sink` = px per shot / extra px after a miss.",
             "`Bot win` = share of 8 greedy-bot games (no power-ups) won with that descent. `Par` = shots for the end bonus.", "",
             "| Lvl | Name | Rows | Bubbles | Colours | Objective | Sink | Par | Time | Bot win | Stars (2/3) |",
             "|---:|---|---:|---:|---:|---|---|---:|---:|---:|---|"]
    for i, spec in enumerate(SPEC):
        level_id = i + 1
        n_rows, colors, mask, ice, stones, locks, rescue, obj_type, timed = spec
        lvl_path = os.path.join(outdir, f"level_{level_id:03d}.json")
        if os.path.exists(lvl_path) and str(level_id) in cache:
            lines.append(cache[str(level_id)])
            print("(kept)", lines[-1], flush=True)
            continue
        ok = None
        rows = None
        min_bubbles = int(16 + 0.7 * level_id)
        for attempt in range(40):
            rng = random.Random(level_id * 7919 + attempt * 104729)
            ease = attempt // 14
            pat = PATTERNS[level_id % 10] if (level_id > 3 and obj_type != 'rescue' and attempt < 24) else None
            rows = h.build_rows(rng, n_rows, colors, mask, max(0, ice - 3 * ease), max(0, stones - ease), max(0, locks - ease), max(1 if rescue else 0, rescue - ease), pat)
            b = bs.Board()
            b.load_rows(rows)
            if len(b.grid) < min_bubbles:
                continue
            if obj_type == "rescue" and b.count_kind(bs.RESCUE) < max(2, rescue - 1):
                continue
            ok = tune(level_id, rows, obj_type)
            if ok:
                break
        if not ok:
            raise SystemExit(f"could not build a winnable level {level_id}")
        objective, par, d, stars, rep = ok
        time_limit = min(180, int(math.ceil((rep["p90"] * 6.0 + 35) / 5.0)) * 5) if timed else 0
        b = bs.Board()
        b.load_rows(rows)
        data = {
            "version": 2, "id": level_id, "name": TITLES[i], "world": 1 + i // 10, "boss": level_id % 10 == 0,
            "colors": colors, "shots": par, "time_limit": time_limit, "descent": d,
            "objective": objective, "star_scores": stars, "tip": TIPS.get(level_id, ""), "rows": rows,
        }
        json.dump(data, open(lvl_path, "w"), indent=1)
        lines.append("| %d | %s | %d | %d | %d | %s | %.1f / %.1f | %d | %s | %d%% | %d / %d |" % (
            level_id, TITLES[i], len(rows), len(b.grid), colors,
            objective["type"] + (" %d" % objective["target"] if "target" in objective else ""),
            d["shot"], d["miss"], par, ("%ds" % time_limit) if time_limit else "-", round(rep["rate"] * 100), stars[0], stars[1]))
        cache[str(level_id)] = lines[-1]
        json.dump(cache, open(cache_path, "w"))
        print(lines[-1], flush=True)
    with open(os.path.join(ROOT, "docs/LEVEL_REPORT.md"), "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
