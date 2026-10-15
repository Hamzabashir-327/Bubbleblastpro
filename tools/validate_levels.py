#!/usr/bin/env python3
"""Independent level check (fresh bot seeds, not the ones used for tuning).

Checks schema + connectivity like LevelData.validate() in GDScript, then plays each level
N times with the greedy bot (no power-ups) and reports the win rate.

    python3 tools/validate_levels.py [trials]      # default 10
Exit code 1 if any level is malformed or the bot never wins it.
"""
import glob
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import board_sim as bs  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def schema_errors(d, expected_id):
    for key in ["id", "shots", "objective", "rows", "star_scores", "colors"]:
        if key not in d:
            return "missing field " + key
    if d["id"] != expected_id:
        return "id mismatch"
    if not (2 <= d["colors"] <= 6):
        return "colors out of range"
    if not (1 <= d["shots"] <= 300):
        return "shots (par) out of range"
    ds = d.get("descent", {})
    if not (0 <= ds.get("shot", 6) <= 60 and 0 <= ds.get("miss", 14) <= 120):
        return "descent out of range"
    obj = d["objective"]
    if obj.get("type") not in ("clear", "score", "rescue"):
        return "bad objective"
    if obj["type"] != "clear" and obj.get("target", 0) <= 0:
        return "objective needs target"
    s = d["star_scores"]
    if len(s) != 2 or s[0] <= 0 or s[1] < s[0]:
        return "bad star_scores"
    if not (1 <= len(d["rows"]) <= 14):
        return "bad row count"
    b = bs.Board()
    err = b.load_rows(d["rows"])
    if err:
        return err
    for v in b.grid.values():
        if v[0] >= d["colors"]:
            return "colour index >= declared colours"
    tmp = b._new_result()
    b.copy()._drop_floating(tmp)
    if tmp["dropped"]:
        return "%d bubbles not connected to ceiling" % len(tmp["dropped"])
    if obj["type"] == "rescue" and b.count_kind(bs.RESCUE) < obj["target"]:
        return "rescue target exceeds critters"
    return ""


def main():
    trials = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    paths = sorted(glob.glob(os.path.join(ROOT, "data/levels/level_*.json")))
    bad = 0
    print("| Lvl | schema | bot wins | median shots / par | sink px (shot/miss) |")
    print("|---:|---|---:|---|")
    for path in paths:
        d = json.load(open(path))
        lid = int(os.path.basename(path)[6:9])
        err = schema_errors(d, lid)
        if err:
            print("| %d | FAIL: %s | - | - |" % (lid, err))
            bad += 1
            continue
        wins, used = 0, []
        for t in range(trials):
            rng = random.Random(900000 + lid * 100 + t)
            r = bs.bot_play_descent(d["rows"], d["objective"], d.get("descent", {"shot": 6, "miss": 14}), rng)
            if r["won"]:
                wins += 1
                used.append(r["shots"])
        used.sort()
        med = used[len(used) // 2] if used else 0
        ds = d.get("descent", {})
        print("| %d | ok | %d/%d | %d / %d | %s / %s |" % (lid, wins, trials, med, d["shots"], ds.get("shot"), ds.get("miss")), flush=True)
        if wins == 0:
            bad += 1
    print("\n%d level files checked, %d problem(s)" % (len(paths), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
