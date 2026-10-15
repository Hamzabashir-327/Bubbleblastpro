#!/usr/bin/env python3
"""Rule tests for the Python mirror (same scenarios as tests/run_tests.gd _test_rules).
    python3 tools/test_rules.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import board_sim as bs  # noqa: E402

fails = 0
checks = 0


def check(ok, msg):
    global fails, checks
    checks += 1
    if not ok:
        fails += 1
        print("FAIL:", msg)


def board(rows):
    b = bs.Board()
    err = b.load_rows(rows)
    check(err == "", "board loads: " + err)
    return b


# geometry
check(bs.row_cols(0) == 10 and bs.row_cols(1) == 9, "row widths")
for r in range(12):
    for c in range(bs.row_cols(r)):
        cell = (c, r)
        for n in bs.neighbors(cell):
            check(cell in bs.neighbors(n), "neighbour symmetry")
            a, b2 = bs.cell_center(cell, (0, 0)), bs.cell_center(n, (0, 0))
            check(abs(math.dist(a, b2) - 2 * bs.R) < 0.01, "neighbours touch")
check(len(bs.neighbors((0, 0))) == 2, "corner has 2 neighbours")

b = bs.Board()
check(b.load_rows(["00", "0"]) != "", "reject wrong row length")
check(b.load_rows(["0000000000", "x00000000"]) != "", "reject unknown symbol")
check(b.load_rows(["01a#*AB...", "........."]) == "", "accept every symbol")

# T1 three in a row pop
b = board(["11........", "........."])
r = b.resolve_landing((2, 0), bs.P_NORMAL, 1)
check(r["pop_count"] == 3 and not b.grid, "three pop")
# T2 pair stays
b = board(["1........."])
r = b.resolve_landing((1, 0), bs.P_NORMAL, 1)
check(r["pop_count"] == 0 and r["landed"] and len(b.grid) == 2, "pair stays")
# T3 floating drop
b = board(["11........", ".2.......", ".3........"])
r = b.resolve_landing((2, 0), bs.P_NORMAL, 1)
check(r["pop_count"] == 3 and r["drop_count"] == 2, "unsupported drop (%s/%s)" % (r["pop_count"], r["drop_count"]))
# T4 ice cracks
b = board(["0a........"])
r = b.resolve_landing((2, 0), bs.P_NORMAL, 0)
check(len(r["cracked"]) == 1 and b.grid.get((1, 0)) == (0, bs.NORMAL) and r["pop_count"] == 2, "ice cracks once, others pop")
# T5 stone not matchable
b = board(["##........"])
r = b.resolve_landing((2, 0), bs.P_NORMAL, 0)
check(r["pop_count"] == 0 and r["landed"], "stone never matches")
# T6 lock opens
b = board(["11.A......"])
r = b.resolve_landing((2, 0), bs.P_NORMAL, 1)
check(r["pop_count"] == 3 and len(r["unlocked"]) == 1 and b.grid[(3, 0)][1] == bs.NORMAL, "lock opens")
# T7 critter freed
b = board(["11.*......"])
r = b.resolve_landing((2, 0), bs.P_NORMAL, 1)
check(r["rescued"] == 1 and len(r["freed"]) == 1 and (3, 0) not in b.grid, "critter freed")
# T7b critter dropped counts as rescued
b = board(["11........", ".*......."])
r = b.resolve_landing((2, 0), bs.P_NORMAL, 1)
check(r["rescued"] == 1, "critter freed (neighbour pop)")
# T8 bomb
b = board(["0123450123", "012345012", "012345...."])
n0 = len(b.grid)
r = b.resolve_landing((7, 2), bs.P_BOMB, 0)
check(r["pop_count"] >= 5 and len(b.grid) == n0 - r["pop_count"] - r["drop_count"], "bomb clears a cluster (%d)" % r["pop_count"])
# T9 lightning cap + stone
b = board(["0123450123", "01#345012", "0123450..."])
r = b.resolve_landing((8, 2), bs.P_LIGHTNING, 0)
check(0 < len(r["popped"]) <= bs.LIGHTNING_CHAIN and (2, 1) in b.grid, "lightning cap/stone (%d)" % len(r["popped"]))
# T10 rainbow
b = board(["33........"])
r = b.resolve_landing((2, 0), bs.P_RAINBOW, 5)
check(r["final_color"] == 3 and r["pop_count"] == 3, "rainbow joins best group")
# T11 bounce
b = board(["0000000000"])
o = (20.0, 170.0)
tr = b.trace_shot((360.0, 1050.0), (math.cos(math.radians(20)), -math.sin(math.radians(20))), o)
check(len(tr["points"]) >= 3, "shallow shot bounces")
check(all(o[0] + bs.R - 0.01 <= p[0] <= o[0] + 680 - bs.R + 0.01 for p in tr["points"]), "stays inside walls")
# T12 fireball
b = board(["0123450123", "012345012", "0123450123", "012345012"])
tr = b.trace_fireball((360.0, 1050.0), (0.0, -1.0), o)
check(0 < len(tr["destroyed"]) <= bs.FIREBALL_MAX_HITS, "fireball hits 1..6 (%d)" % len(tr["destroyed"]))
r = b.resolve_fireball(tr["destroyed"])
check(r["pop_count"] + r["rescued"] >= len(tr["destroyed"]) - 0, "fireball removes what it hit")
# T13 invariant: after any shot no floating bubbles remain (random fuzz)
import random
rng = random.Random(3)
for i in range(200):
    rows = []
    for rr in range(rng.randint(2, 7)):
        rows.append("".join(rng.choice("0123..") for _ in range(bs.row_cols(rr))))
    bb = bs.Board()
    if bb.load_rows(rows) != "":
        continue
    tmp = bb._new_result()
    bb._drop_floating(tmp)
    ang = math.radians(rng.uniform(15, 165))
    tr = bb.trace_shot(bs.SHOOTER, (math.cos(ang), -math.sin(ang)), bs.ORIGIN)
    cell = bb.landing_cell(tr["end"], bs.ORIGIN)
    if cell == (-1, -1):
        continue
    bb.resolve_landing(cell, rng.choice([bs.P_NORMAL, bs.P_BOMB, bs.P_LIGHTNING, bs.P_RAINBOW]), rng.randrange(4))
    chk = bb._new_result()
    bb._drop_floating(chk)
    check(not chk["dropped"], "fuzz %d: nothing floats after a shot" % i)
# T14 descent model (v2): room shrinks, the bot can lose to the danger line, and wins gentle levels
bd = bs.Board(); bd.load_rows(["0123450123", "012345012"])
r0 = bs.room_px(bd, 0.0); r1 = bs.room_px(bd, 100.0)
check(abs((r0 - r1) - 100.0) < 1e-9, "room_px shrinks 1:1 with the sinking ceiling")
check(bs.room_px(bs.Board(), 500.0) > 9000, "empty board has unlimited room")
harsh = bs.bot_play_descent(["0123450123", "012345012", "0123450123", "012345012"], {"type": "clear"}, {"shot": 400.0, "miss": 400.0}, random.Random(1))
check((not harsh["won"]) and harsh["reason"] == "danger", "an absurd descent ends in 'danger' (game over)")
gentle = bs.bot_play_descent(["000"+"."*7, "."*9], {"type": "clear"}, {"shot": 0.0, "miss": 0.0}, random.Random(1))
check(gentle["won"], "a trivial board with no descent is won")
print("%d checks, %d failed" % (checks, fails))
sys.exit(1 if fails else 0)
