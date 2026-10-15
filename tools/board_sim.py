"""Python mirror of scripts/gameplay/board_logic.gd.

Used for two things only:
  1. tools/generate_levels.py  - validates/tunes levels with a greedy bot.
  2. tools/make_test_vectors.py - emits JSON cases that tests/run_tests.gd
     replays inside Godot to prove the GDScript rules match this mirror.

KEEP IN SYNC with board_logic.gd (same constants, same algorithms).
"""
import copy
import math
import random

COLS = 10
MAX_ROWS = 28
R = 34.0
ROW_H = R * math.sqrt(3.0)
STEP = 17.0
COLLIDE_FACTOR = 0.9
MAX_STEPS = 600
NUM_COLORS = 6
LIGHTNING_CHAIN = 8
FIREBALL_MAX_HITS = 6
FIREBALL_RADIUS = 1.5

NORMAL, ICE, STONE, LOCKED, RESCUE = range(5)
P_NORMAL, P_RAINBOW, P_BOMB, P_LIGHTNING, P_FIREBALL = range(5)

SCORE_POP = 10
SCORE_DROP = 20
SCORE_RESCUE = 100


def row_cols(row):
    return COLS if row % 2 == 0 else COLS - 1


def in_bounds(cell):
    c, r = cell
    return 0 <= r < MAX_ROWS and 0 <= c < row_cols(r)


def neighbors(cell):
    c, r = cell
    cand = [(c - 1, r), (c + 1, r)]
    if r % 2 == 0:
        cand += [(c - 1, r - 1), (c, r - 1), (c - 1, r + 1), (c, r + 1)]
    else:
        cand += [(c, r - 1), (c + 1, r - 1), (c, r + 1), (c + 1, r + 1)]
    return [n for n in cand if in_bounds(n)]


def cell_center(cell, origin):
    c, r = cell
    shift = R if r % 2 == 1 else 0.0
    return (origin[0] + R + shift + 2.0 * R * c, origin[1] + R + r * ROW_H)


def matchable(v):
    return v[1] in (NORMAL, ICE)


class Board:
    def __init__(self):
        self.grid = {}

    # ---- loading
    def load_rows(self, rows):
        self.grid = {}
        for r, line in enumerate(rows):
            if len(line) != row_cols(r):
                return "row %d has %d chars, expected %d" % (r, len(line), row_cols(r))
            for c, ch in enumerate(line):
                cell = (c, r)
                if ch == ".":
                    continue
                if "0" <= ch <= "5":
                    self.grid[cell] = (int(ch), NORMAL)
                elif "a" <= ch <= "f":
                    self.grid[cell] = (ord(ch) - 97, ICE)
                elif "A" <= ch <= "F":
                    self.grid[cell] = (ord(ch) - 65, LOCKED)
                elif ch == "#":
                    self.grid[cell] = (-1, STONE)
                elif ch == "*":
                    self.grid[cell] = (-1, RESCUE)
                else:
                    return "row %d col %d: unknown symbol '%s'" % (r, c, ch)
        return ""

    def copy(self):
        b = Board()
        b.grid = dict(self.grid)
        return b

    # ---- queries
    def colors_present(self, matchable_only=True):
        seen = set()
        for v in self.grid.values():
            if v[0] < 0:
                continue
            if matchable_only and not matchable(v):
                continue
            seen.add(v[0])
        return [c for c in range(NUM_COLORS) if c in seen]

    def count_colored(self):
        return sum(1 for v in self.grid.values() if v[0] >= 0)

    def count_kind(self, kind):
        return sum(1 for v in self.grid.values() if v[1] == kind)

    def lowest_row(self):
        return max((c[1] for c in self.grid), default=-1)

    def has_neighbor_bubble(self, cell):
        return any(n in self.grid for n in neighbors(cell))

    # ---- tracing
    def _collides(self, px, py, origin):
        rr = int(math.floor((py - origin[1] - R) / ROW_H + 0.5))
        thr = (2.0 * R * COLLIDE_FACTOR) * (2.0 * R * COLLIDE_FACTOR)
        for r in range(rr - 1, rr + 2):
            if r < 0 or r >= MAX_ROWS:
                continue
            base_x = origin[0] + R + (R if r % 2 == 1 else 0.0)
            cc = int(math.floor((px - base_x) / (2.0 * R) + 0.5))
            for c in range(cc - 1, cc + 2):
                if c < 0 or c >= row_cols(r):
                    continue
                if (c, r) in self.grid:
                    cx = base_x + 2.0 * R * c
                    cy = origin[1] + R + r * ROW_H
                    ddx = px - cx
                    ddy = py - cy
                    if ddx * ddx + ddy * ddy < thr:
                        return True
        return False

    def trace_shot(self, start, direction, origin):
        mag = math.sqrt(direction[0] * direction[0] + direction[1] * direction[1])
        dx = direction[0] / mag
        dy = direction[1] / mag
        min_x = origin[0] + R
        max_x = origin[0] + 2.0 * R * COLS - R
        min_y = origin[1] + R
        px, py = start
        pts = [(px, py)]
        hit_ceiling = False
        steps = 0
        while steps < MAX_STEPS:
            steps += 1
            nx = px + dx * STEP
            ny = py + dy * STEP
            if (nx < min_x or nx > max_x) and abs(dx) > 1e-9:
                wx = min_x if nx < min_x else max_x
                t = (wx - px) / dx
                cy = py + dy * t
                pts.append((wx, cy))
                px, py = wx, cy
                dx = -dx
                continue
            prev_y, prev_x = py, px
            px, py = nx, ny
            if py <= min_y:
                tt = (min_y - prev_y) / dy if abs(dy) > 1e-9 else 0.0
                px = prev_x + dx * tt
                py = min_y
                hit_ceiling = True
                break
            if self._collides(px, py, origin):
                break
        pts.append((px, py))
        return {"points": pts, "end": (px, py), "hit_ceiling": hit_ceiling}

    def landing_cell(self, pos, origin):
        best = (-1, -1)
        best_d = float("inf")
        rr = int(math.floor((pos[1] - origin[1] - R) / ROW_H + 0.5))
        for r in range(max(rr - 2, 0), min(rr + 3, MAX_ROWS)):
            for c in range(row_cols(r)):
                cell = (c, r)
                if cell in self.grid:
                    continue
                if r > 0 and not self.has_neighbor_bubble(cell):
                    continue
                cc = cell_center(cell, origin)
                d = (cc[0] - pos[0]) ** 2 + (cc[1] - pos[1]) ** 2
                if d < best_d:
                    best_d = d
                    best = cell
        return best

    def trace_fireball(self, start, direction, origin):
        mag = math.sqrt(direction[0] * direction[0] + direction[1] * direction[1])
        dx = direction[0] / mag
        dy = direction[1] / mag
        min_x = origin[0] + R
        max_x = origin[0] + 2.0 * R * COLS - R
        min_y = origin[1] + R
        px, py = start
        pts = [(px, py)]
        destroyed = []
        hit_set = set()
        steps = 0
        limit = (FIREBALL_RADIUS * R) * (FIREBALL_RADIUS * R)
        while steps < MAX_STEPS and len(destroyed) < FIREBALL_MAX_HITS:
            steps += 1
            nx = px + dx * STEP
            ny = py + dy * STEP
            if (nx < min_x or nx > max_x) and abs(dx) > 1e-9:
                wx = min_x if nx < min_x else max_x
                t = (wx - px) / dx
                cy = py + dy * t
                pts.append((wx, cy))
                px, py = wx, cy
                dx = -dx
                continue
            px, py = nx, ny
            if py <= min_y:
                py = min_y
                break
            rr = int(math.floor((py - origin[1] - R) / ROW_H + 0.5))
            for r in range(rr - 1, rr + 2):
                if r < 0 or r >= MAX_ROWS:
                    continue
                for c in range(row_cols(r)):
                    cell = (c, r)
                    if cell in self.grid and cell not in hit_set:
                        cc = cell_center(cell, origin)
                        ddx = px - cc[0]
                        ddy = py - cc[1]
                        if ddx * ddx + ddy * ddy < limit and len(destroyed) < FIREBALL_MAX_HITS:
                            hit_set.add(cell)
                            destroyed.append(cell)
        pts.append((px, py))
        return {"points": pts, "end": (px, py), "destroyed": destroyed}

    # ---- resolution
    @staticmethod
    def _new_result():
        return {"landed": False, "cell": (-1, -1), "final_color": -1, "popped": [], "dropped": [], "cracked": [],
                "unlocked": [], "freed": [], "rescued": 0, "pop_count": 0, "drop_count": 0, "score": 0}

    def find_group(self, start):
        if start not in self.grid:
            return []
        col = self.grid[start][0]
        seen = {start}
        queue = [start]
        out = []
        while queue:
            cur = queue.pop()
            out.append(cur)
            for n in neighbors(cur):
                if n in seen or n not in self.grid:
                    continue
                v = self.grid[n]
                if matchable(v) and v[0] == col:
                    seen.add(n)
                    queue.append(n)
        return out

    def _remove(self, cell, lst):
        v = self.grid.pop(cell)
        lst.append({"cell": cell, "color": v[0], "kind": v[1]})

    def _after_removal(self, removed, res):
        for cell in removed:
            for n in neighbors(cell):
                if n not in self.grid:
                    continue
                v = self.grid[n]
                if v[1] == LOCKED:
                    self.grid[n] = (v[0], NORMAL)
                    res["unlocked"].append(n)
                elif v[1] == RESCUE:
                    self._remove(n, res["freed"])
                    res["rescued"] += 1
        self._drop_floating(res)

    def _drop_floating(self, res):
        seen = set()
        queue = []
        for c in range(row_cols(0)):
            if (c, 0) in self.grid:
                seen.add((c, 0))
                queue.append((c, 0))
        while queue:
            cur = queue.pop()
            for n in neighbors(cur):
                if n in self.grid and n not in seen:
                    seen.add(n)
                    queue.append(n)
        for cell in list(self.grid.keys()):
            if cell not in seen:
                v = self.grid[cell]
                self._remove(cell, res["dropped"])
                if v[1] == RESCUE:
                    res["rescued"] += 1

    def _finish_score(self, res):
        rescued_drops = sum(1 for d in res["dropped"] if d["kind"] == RESCUE)
        res["pop_count"] = len(res["popped"])
        res["drop_count"] = len(res["dropped"]) - rescued_drops
        res["score"] = res["pop_count"] * SCORE_POP + res["drop_count"] * SCORE_DROP + res["rescued"] * SCORE_RESCUE

    def _pick_rainbow_color(self, cell):
        best_color, best_size = -1, -1
        for col in range(NUM_COLORS):
            touches = any(n in self.grid and matchable(self.grid[n]) and self.grid[n][0] == col for n in neighbors(cell))
            if not touches:
                continue
            self.grid[cell] = (col, NORMAL)
            size = len(self.find_group(cell))
            del self.grid[cell]
            if size > best_size:
                best_size, best_color = size, col
        if best_color < 0:
            present = self.colors_present(True)
            best_color = present[0] if present else 0
        return best_color

    @staticmethod
    def _lightning_key(cell, impact):
        cc = cell_center(cell, (0.0, 0.0))
        return ((cc[0] - impact[0]) ** 2 + (cc[1] - impact[1]) ** 2, cell[1], cell[0])

    def resolve_landing(self, cell, proj, color):
        res = self._new_result()
        res["cell"] = cell
        if proj in (P_NORMAL, P_RAINBOW):
            col = color
            if proj == P_RAINBOW:
                col = self._pick_rainbow_color(cell)
            res["final_color"] = col
            self.grid[cell] = (col, NORMAL)
            group = self.find_group(cell)
            if len(group) >= 3:
                removed = []
                for g in group:
                    v = self.grid[g]
                    if v[1] == ICE:
                        self.grid[g] = (v[0], NORMAL)
                        res["cracked"].append(g)
                    else:
                        self._remove(g, res["popped"])
                        removed.append(g)
                self._after_removal(removed, res)
            else:
                res["landed"] = True
        elif proj == P_BOMB:
            seen = {cell}
            layer = [cell]
            for _ in range(2):
                nxt = []
                for cur in layer:
                    for n in neighbors(cur):
                        if n not in seen:
                            seen.add(n)
                            nxt.append(n)
                layer = nxt
            removed = []
            for c2 in seen:
                if c2 in self.grid:
                    self._remove(c2, res["popped"])
                    removed.append(c2)
            self._after_removal(removed, res)
        elif proj == P_LIGHTNING:
            impact = cell_center(cell, (0.0, 0.0))
            chain = []
            cands = [n for n in neighbors(cell) if n in self.grid and self.grid[n][1] != STONE]
            while len(chain) < LIGHTNING_CHAIN and cands:
                bi = 0
                for i in range(1, len(cands)):
                    ka = self._lightning_key(cands[i], impact)
                    kb = self._lightning_key(cands[bi], impact)
                    if abs(ka[0] - kb[0]) > 1e-6:
                        less = ka[0] < kb[0]
                    elif ka[1] != kb[1]:
                        less = ka[1] < kb[1]
                    else:
                        less = ka[2] < kb[2]
                    if less:
                        bi = i
                pick = cands.pop(bi)
                chain.append(pick)
                for n in neighbors(pick):
                    if n in self.grid and self.grid[n][1] != STONE and n not in chain and n not in cands:
                        cands.append(n)
            removed = []
            for c3 in chain:
                self._remove(c3, res["popped"])
                removed.append(c3)
            self._after_removal(removed, res)
        self._finish_score(res)
        return res

    def resolve_fireball(self, cells):
        res = self._new_result()
        removed = []
        for c in cells:
            if c in self.grid:
                v = self.grid[c]
                if v[1] == RESCUE:
                    self._remove(c, res["freed"])
                    res["rescued"] += 1
                else:
                    self._remove(c, res["popped"])
                removed.append(c)
        self._after_removal(removed, res)
        self._finish_score(res)
        return res


# ---------------------------------------------------------------- bot / level play
ORIGIN = (20.0, 170.0)
SHOOTER = (ORIGIN[0] + COLS * R, ORIGIN[1] + 880.0)  # same geometry the game uses on a 720x1280 screen
LOSE_ROW = int((SHOOTER[1] - 110.0 - ORIGIN[1] - R) / ROW_H)
ANGLES = [math.radians(a) for a in range(14, 167, 6)]


def pick_color(board, rng):
    present = board.colors_present(True) or board.colors_present(False)
    return rng.choice(present) if present else 0


def bot_play(rows, objective, max_shots, rng, drop_every=0):
    """Greedy bot. Returns dict(won, shots, score, rescued, reason).
    drop_every > 0: after every N fired shots the whole board (ceiling) moves down one row;
    a bubble reaching LOSE_ROW (row + drops) ends the game."""
    b = Board()
    err = b.load_rows(rows)
    if err:
        raise ValueError(err)
    score = 0
    rescued = 0
    combo = 0
    drops = 0
    cur = pick_color(b, rng)
    nxt = pick_color(b, rng)
    shots = 0
    while shots < max_shots:
        origin = (ORIGIN[0], ORIGIN[1] + drops * ROW_H)
        best = None
        for ang in ANGLES:
            direction = (math.cos(ang), -math.sin(ang))
            tr = b.trace_shot(SHOOTER, direction, origin)
            cell = b.landing_cell(tr["end"], origin)
            if cell == (-1, -1):
                continue
            sim = b.copy()
            r = sim.resolve_landing(cell, P_NORMAL, cur)
            value = r["pop_count"] * 10 + r["drop_count"] * 22 + r["rescued"] * 80 + len(r["cracked"]) * 4 + len(r["unlocked"]) * 6
            if r["landed"]:
                value = -0.5 * cell[1] + (3 if any(sim.grid.get(n, (-9, 0))[0] == cur for n in neighbors(cell)) else 0)
            if best is None or value > best[0] + 1e-9 or (abs(value - best[0]) < 1e-9 and rng.random() < 0.3):
                best = (value, cell)
        if best is None:
            break
        shots += 1
        res = b.resolve_landing(best[1], P_NORMAL, cur)
        combo = combo + 1 if res["pop_count"] + res["drop_count"] + res["rescued"] > 0 else 0
        mult = 1.0 + 0.5 * min(max(combo - 1, 0), 6)
        score += int(res["score"] * mult)
        rescued += res["rescued"]
        if _objective_met(b, objective, score, rescued):
            return {"won": True, "shots": shots, "score": score, "rescued": rescued, "reason": ""}
        if drop_every and shots % drop_every == 0:
            drops += 1
        if b.lowest_row() + drops >= LOSE_ROW:
            return {"won": False, "shots": shots, "score": score, "rescued": rescued, "reason": "overflow"}
        if b.count_colored() == 0:
            return {"won": False, "shots": shots, "score": score, "rescued": rescued, "reason": "empty"}
        cur, nxt = nxt, pick_color(b, rng)
        if cur not in (b.colors_present(True) or b.colors_present(False)):
            cur = pick_color(b, rng)
    return {"won": False, "shots": shots, "score": score, "rescued": rescued, "reason": "shots"}


def _objective_met(board, objective, score, rescued):
    t = objective["type"]
    if t == "clear":
        return board.count_colored() == 0
    if t == "score":
        return score >= objective["target"]
    if t == "rescue":
        return rescued >= objective["target"]
    return False


# ---------------------------------------------------------------- descent model (v2 rules)
DANGER_Y = 940.0


def room_px(board, drop):
    """Pixels between the lowest bubble's bottom edge and the red danger line."""
    low = board.lowest_row()
    if low < 0:
        return 9999.0
    return DANGER_Y - (ORIGIN[1] + drop + 2 * R + low * ROW_H)


def bot_play_descent(rows, objective, descent, rng, max_shots=160):
    """Greedy bot under the sinking-ceiling rules.
    descent = {"shot": px per shot, "miss": extra px when the shot did not pop/drop anything}.
    Returns dict(won, shots, score, rescued, reason, drop)."""
    b = Board()
    err = b.load_rows(rows)
    if err:
        raise ValueError(err)
    score = rescued = combo = shots = 0
    drop = 0.0
    cur = pick_color(b, rng)
    nxt = pick_color(b, rng)
    while shots < max_shots:
        origin = (ORIGIN[0], ORIGIN[1] + drop)
        best = None
        for ang in ANGLES:
            direction = (math.cos(ang), -math.sin(ang))
            tr = b.trace_shot(SHOOTER, direction, origin)
            cell = b.landing_cell(tr["end"], origin)
            if cell == (-1, -1):
                continue
            sim = b.copy()
            r = sim.resolve_landing(cell, P_NORMAL, cur)
            value = r["pop_count"] * 10 + r["drop_count"] * 22 + r["rescued"] * 80 + len(r["cracked"]) * 4 + len(r["unlocked"]) * 6
            if r["landed"]:
                value = -0.5 * cell[1] + (3 if any(sim.grid.get(n, (-9, 0))[0] == cur for n in neighbors(cell)) else 0)
            if best is None or value > best[0] + 1e-9 or (abs(value - best[0]) < 1e-9 and rng.random() < 0.3):
                best = (value, cell)
        if best is None:
            break
        shots += 1
        res = b.resolve_landing(best[1], P_NORMAL, cur)
        progressed = res["pop_count"] + res["drop_count"] + res["rescued"] > 0
        combo = combo + 1 if progressed else 0
        score += int(res["score"] * (1.0 + 0.5 * min(max(combo - 1, 0), 6)))
        rescued += res["rescued"]
        if _objective_met(b, objective, score, rescued):
            return {"won": True, "shots": shots, "score": score, "rescued": rescued, "reason": "", "drop": drop}
        drop += descent["shot"] + (0.0 if progressed else descent["miss"])
        if room_px(b, drop) <= 0:
            return {"won": False, "shots": shots, "score": score, "rescued": rescued, "reason": "danger", "drop": drop}
        if b.count_colored() == 0:
            return {"won": False, "shots": shots, "score": score, "rescued": rescued, "reason": "empty", "drop": drop}
        cur, nxt = nxt, pick_color(b, rng)
        present = b.colors_present(True) or b.colors_present(False)
        if cur not in present:
            cur = pick_color(b, rng)
    return {"won": False, "shots": shots, "score": score, "rescued": rescued, "reason": "shots", "drop": drop}
