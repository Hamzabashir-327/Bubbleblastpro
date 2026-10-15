class_name BoardLogic
extends RefCounted
## Pure game rules for the hex bubble grid. No nodes, no autoloads, no rendering,
## so it can be unit-tested headless (tests/run_tests.gd) and mirrored by the
## Python level validator (tools/board_sim.py).
##
## Grid cell value: Vector2i(color, kind). Even rows have COLS cells, odd rows
## COLS-1 cells shifted right by one radius.
## NOTE: shot tracing deliberately uses plain floats (64-bit) instead of Vector2
## (32-bit) so results match the Python validator exactly.

const COLS := 10
const MAX_ROWS := 28
const R := 34.0
const ROW_H := 58.88972745734183  # R * sqrt(3)
const STEP := 17.0                # R * 0.5, shot-tracing step in pixels
const COLLIDE_FACTOR := 0.9       # collision when centre distance < 2R * factor
const MAX_STEPS := 600
const NUM_COLORS := 6
const LIGHTNING_CHAIN := 8
const FIREBALL_MAX_HITS := 6
const FIREBALL_RADIUS := 1.5      # in units of R

enum Kind { NORMAL, ICE, STONE, LOCKED, RESCUE }
enum Proj { NORMAL, RAINBOW, BOMB, LIGHTNING, FIREBALL }

const SCORE_POP := 10
const SCORE_DROP := 20
const SCORE_RESCUE := 100

var grid: Dictionary = {}  # Vector2i(col,row) -> Vector2i(color, kind)


# ------------------------------------------------------------------ geometry
static func row_cols(row: int) -> int:
	return COLS if row % 2 == 0 else COLS - 1


static func in_bounds(cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < MAX_ROWS and cell.x >= 0 and cell.x < row_cols(cell.y)


static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c := cell.x
	var r := cell.y
	var cand: Array[Vector2i] = [Vector2i(c - 1, r), Vector2i(c + 1, r)]
	if r % 2 == 0:
		cand.append_array([Vector2i(c - 1, r - 1), Vector2i(c, r - 1), Vector2i(c - 1, r + 1), Vector2i(c, r + 1)])
	else:
		cand.append_array([Vector2i(c, r - 1), Vector2i(c + 1, r - 1), Vector2i(c, r + 1), Vector2i(c + 1, r + 1)])
	for n in cand:
		if in_bounds(n):
			out.append(n)
	return out


static func board_width() -> float:
	return 2.0 * R * COLS


static func cell_center(cell: Vector2i, origin: Vector2) -> Vector2:
	var shift := R if cell.y % 2 == 1 else 0.0
	return Vector2(origin.x + R + shift + 2.0 * R * cell.x, origin.y + R + cell.y * ROW_H)


# ------------------------------------------------------------------ loading
func clear() -> void:
	grid.clear()


## rows: Array of Strings. '.' empty, '0'-'5' normal, 'a'-'f' ice, 'A'-'F' locked,
## '#' stone, '*' rescue critter. Returns "" on success or an error message.
func load_rows(rows: Array) -> String:
	grid.clear()
	for r in rows.size():
		var line: String = rows[r]
		if line.length() != row_cols(r):
			return "row %d has %d chars, expected %d" % [r, line.length(), row_cols(r)]
		for c in line.length():
			var ch := line[c]
			var cell := Vector2i(c, r)
			if ch == ".":
				continue
			elif ch >= "0" and ch <= "5":
				grid[cell] = Vector2i(int(ch), Kind.NORMAL)
			elif ch >= "a" and ch <= "f":
				grid[cell] = Vector2i(ch.unicode_at(0) - 97, Kind.ICE)
			elif ch >= "A" and ch <= "F":
				grid[cell] = Vector2i(ch.unicode_at(0) - 65, Kind.LOCKED)
			elif ch == "#":
				grid[cell] = Vector2i(-1, Kind.STONE)
			elif ch == "*":
				grid[cell] = Vector2i(-1, Kind.RESCUE)
			else:
				return "row %d col %d: unknown symbol '%s'" % [r, c, ch]
	return ""


func place(cell: Vector2i, color: int, kind: int = Kind.NORMAL) -> void:
	grid[cell] = Vector2i(color, kind)


# ------------------------------------------------------------------ queries
static func _matchable(v: Vector2i) -> bool:
	return v.y == Kind.NORMAL or v.y == Kind.ICE


## Colours still obtainable on the board. matchable_only ignores locked bubbles.
func colors_present(matchable_only: bool = true) -> Array[int]:
	var seen := {}
	for cell in grid:
		var v: Vector2i = grid[cell]
		if v.x < 0:
			continue
		if matchable_only and not _matchable(v):
			continue
		seen[v.x] = true
	var out: Array[int] = []
	for c in range(NUM_COLORS):
		if seen.has(c):
			out.append(c)
	return out


## Bubbles that must be removed for a "clear" objective (stone and critters excluded).
func count_colored() -> int:
	var n := 0
	for cell in grid:
		if grid[cell].x >= 0:
			n += 1
	return n


func count_kind(kind: int) -> int:
	var n := 0
	for cell in grid:
		if grid[cell].y == kind:
			n += 1
	return n


func lowest_row() -> int:
	var low := -1
	for cell in grid:
		if cell.y > low:
			low = cell.y
	return low


func has_neighbor_bubble(cell: Vector2i) -> bool:
	for n in neighbors(cell):
		if grid.has(n):
			return true
	return false


# ------------------------------------------------------------------ shot tracing
func _collides(px: float, py: float, origin: Vector2) -> bool:
	var rr := int(floor((py - origin.y - R) / ROW_H + 0.5))
	var thr := (2.0 * R * COLLIDE_FACTOR) * (2.0 * R * COLLIDE_FACTOR)
	for r in range(rr - 1, rr + 2):
		if r < 0 or r >= MAX_ROWS:
			continue
		var base_x := origin.x + R + (R if r % 2 == 1 else 0.0)
		var cc := int(floor((px - base_x) / (2.0 * R) + 0.5))
		for c in range(cc - 1, cc + 2):
			if c < 0 or c >= row_cols(r):
				continue
			if grid.has(Vector2i(c, r)):
				var cx := base_x + 2.0 * R * c
				var cy := origin.y + R + r * ROW_H
				var ddx := px - cx
				var ddy := py - cy
				if ddx * ddx + ddy * ddy < thr:
					return true
	return false


## Straight shot with wall bounces. Returns {points, end: Vector2, hit_ceiling: bool}.
## `points` are the polyline corners (start, wall bounces, end) used for both the
## aim guide and the projectile animation.
func trace_shot(start: Vector2, dir: Vector2, origin: Vector2) -> Dictionary:
	var mag := sqrt(float(dir.x) * dir.x + float(dir.y) * dir.y)
	var dx: float = dir.x / mag
	var dy: float = dir.y / mag
	var min_x: float = origin.x + R
	var max_x: float = origin.x + 2.0 * R * COLS - R
	var min_y: float = origin.y + R
	var px: float = start.x
	var py: float = start.y
	var pts := PackedVector2Array([Vector2(px, py)])
	var hit_ceiling := false
	var steps := 0
	while steps < MAX_STEPS:
		steps += 1
		var nx := px + dx * STEP
		var ny := py + dy * STEP
		if (nx < min_x or nx > max_x) and absf(dx) > 1e-9:
			var wx := min_x if nx < min_x else max_x
			var t := (wx - px) / dx
			var cy := py + dy * t
			pts.append(Vector2(wx, cy))
			px = wx
			py = cy
			dx = -dx
			continue
		var prev_y := py
		var prev_x := px
		px = nx
		py = ny
		if py <= min_y:
			var tt := (min_y - prev_y) / dy if absf(dy) > 1e-9 else 0.0
			px = prev_x + dx * tt
			py = min_y
			hit_ceiling = true
			break
		if _collides(px, py, origin):
			break
	pts.append(Vector2(px, py))
	return {"points": pts, "end": Vector2(px, py), "hit_ceiling": hit_ceiling}


## Nearest empty, attachable cell to a landing position.
func landing_cell(pos: Vector2, origin: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	var rr := int(floor((pos.y - origin.y - R) / ROW_H + 0.5))
	for r in range(maxi(rr - 2, 0), mini(rr + 3, MAX_ROWS)):
		for c in row_cols(r):
			var cell := Vector2i(c, r)
			if grid.has(cell):
				continue
			if r > 0 and not has_neighbor_bubble(cell):
				continue
			var d := cell_center(cell, origin).distance_squared_to(pos)
			if d < best_d:
				best_d = d
				best = cell
	return best


## Fireball path: passes through bubbles instead of colliding. Returns
## {points, end, destroyed: Array[Vector2i]}.
func trace_fireball(start: Vector2, dir: Vector2, origin: Vector2) -> Dictionary:
	var mag := sqrt(float(dir.x) * dir.x + float(dir.y) * dir.y)
	var dx: float = dir.x / mag
	var dy: float = dir.y / mag
	var min_x: float = origin.x + R
	var max_x: float = origin.x + 2.0 * R * COLS - R
	var min_y: float = origin.y + R
	var px: float = start.x
	var py: float = start.y
	var pts := PackedVector2Array([Vector2(px, py)])
	var destroyed: Array[Vector2i] = []
	var hit_set := {}
	var steps := 0
	var limit := (FIREBALL_RADIUS * R) * (FIREBALL_RADIUS * R)
	while steps < MAX_STEPS and destroyed.size() < FIREBALL_MAX_HITS:
		steps += 1
		var nx := px + dx * STEP
		var ny := py + dy * STEP
		if (nx < min_x or nx > max_x) and absf(dx) > 1e-9:
			var wx := min_x if nx < min_x else max_x
			var t := (wx - px) / dx
			var cy := py + dy * t
			pts.append(Vector2(wx, cy))
			px = wx
			py = cy
			dx = -dx
			continue
		px = nx
		py = ny
		if py <= min_y:
			py = min_y
			break
		var rr := int(floor((py - origin.y - R) / ROW_H + 0.5))
		for r in range(rr - 1, rr + 2):
			if r < 0 or r >= MAX_ROWS:
				continue
			for c in row_cols(r):
				var cell := Vector2i(c, r)
				if grid.has(cell) and not hit_set.has(cell):
					var cc := cell_center(cell, origin)
					var ddx := px - cc.x
					var ddy := py - cc.y
					if ddx * ddx + ddy * ddy < limit and destroyed.size() < FIREBALL_MAX_HITS:
						hit_set[cell] = true
						destroyed.append(cell)
	pts.append(Vector2(px, py))
	return {"points": pts, "end": Vector2(px, py), "destroyed": destroyed}


# ------------------------------------------------------------------ resolution
static func _new_result() -> Dictionary:
	return {
		"landed": false,        # the shot bubble stayed on the board
		"cell": Vector2i(-1, -1),
		"final_color": -1,
		"popped": [],           # [{cell, color, kind}] removed by a match / power
		"dropped": [],          # [{cell, color, kind}] fell because unsupported
		"cracked": [],          # [cell] ice shells that cracked
		"unlocked": [],         # [cell] locked bubbles that were freed
		"freed": [],            # [{cell, color, kind}] critters freed by a neighbour pop
		"rescued": 0,
		"pop_count": 0,
		"drop_count": 0,
		"score": 0,
	}


func find_group(start: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not grid.has(start):
		return out
	var col: int = grid[start].x
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		out.append(cur)
		for n in neighbors(cur):
			if seen.has(n) or not grid.has(n):
				continue
			var v: Vector2i = grid[n]
			if _matchable(v) and v.x == col:
				seen[n] = true
				queue.append(n)
	return out


func _remove(cell: Vector2i, list: Array) -> void:
	var v: Vector2i = grid[cell]
	grid.erase(cell)
	list.append({"cell": cell, "color": v.x, "kind": v.y})


## After cells were removed: unlock / free neighbours, then drop unsupported bubbles.
func _after_removal(removed_cells: Array, res: Dictionary) -> void:
	for cell in removed_cells:
		for n in neighbors(cell):
			if not grid.has(n):
				continue
			var v: Vector2i = grid[n]
			if v.y == Kind.LOCKED:
				grid[n] = Vector2i(v.x, Kind.NORMAL)
				res.unlocked.append(n)
			elif v.y == Kind.RESCUE:
				_remove(n, res.freed)
				res.rescued += 1
	_drop_floating(res)


func _drop_floating(res: Dictionary) -> void:
	var seen := {}
	var queue: Array[Vector2i] = []
	for c in range(row_cols(0)):
		var cell := Vector2i(c, 0)
		if grid.has(cell):
			seen[cell] = true
			queue.append(cell)
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for n in neighbors(cur):
			if grid.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	for cell in grid.keys():
		if not seen.has(cell):
			var v: Vector2i = grid[cell]
			_remove(cell, res.dropped)
			if v.y == Kind.RESCUE:
				res.rescued += 1


func _finish_score(res: Dictionary) -> void:
	var rescued_drops := 0
	for d in res.dropped:
		if d.kind == Kind.RESCUE:
			rescued_drops += 1
	res.pop_count = res.popped.size()
	res.drop_count = res.dropped.size() - rescued_drops
	res.score = res.pop_count * SCORE_POP + res.drop_count * SCORE_DROP + res.rescued * SCORE_RESCUE


## Colour a rainbow orb becomes: the neighbouring colour giving the biggest group.
func _pick_rainbow_color(cell: Vector2i) -> int:
	var best_color := -1
	var best_size := -1
	for col in range(NUM_COLORS):
		var touches := false
		for n in neighbors(cell):
			if grid.has(n) and _matchable(grid[n]) and grid[n].x == col:
				touches = true
		if not touches:
			continue
		grid[cell] = Vector2i(col, Kind.NORMAL)
		var size := find_group(cell).size()
		grid.erase(cell)
		if size > best_size:
			best_size = size
			best_color = col
	if best_color < 0:
		var present := colors_present(true)
		best_color = present[0] if not present.is_empty() else 0
	return best_color


## Applies a landed shot. `cell` must be the result of landing_cell().
func resolve_landing(cell: Vector2i, proj: int, color: int) -> Dictionary:
	var res := _new_result()
	res.cell = cell
	match proj:
		Proj.NORMAL, Proj.RAINBOW:
			var col := color
			if proj == Proj.RAINBOW:
				col = _pick_rainbow_color(cell)
			res.final_color = col
			place(cell, col, Kind.NORMAL)
			var group := find_group(cell)
			if group.size() >= 3:
				var removed: Array = []
				for g in group:
					var v: Vector2i = grid[g]
					if v.y == Kind.ICE:
						grid[g] = Vector2i(v.x, Kind.NORMAL)
						res.cracked.append(g)
					else:
						_remove(g, res.popped)
						removed.append(g)
				_after_removal(removed, res)
			else:
				res.landed = true
		Proj.BOMB:
			var removed: Array = []
			var layer: Array[Vector2i] = [cell]
			var seen := {cell: true}
			for depth in range(2):
				var nxt: Array[Vector2i] = []
				for cur in layer:
					for n in neighbors(cur):
						if not seen.has(n):
							seen[n] = true
							nxt.append(n)
				layer = nxt
			for c2 in seen:
				if grid.has(c2):
					_remove(c2, res.popped)
					removed.append(c2)
			_after_removal(removed, res)
		Proj.LIGHTNING:
			var removed: Array = []
			var impact := cell_center(cell, Vector2.ZERO)
			var chain: Array[Vector2i] = []
			var cands: Array[Vector2i] = []
			for n in neighbors(cell):
				if grid.has(n) and grid[n].y != Kind.STONE:
					cands.append(n)
			while chain.size() < LIGHTNING_CHAIN and not cands.is_empty():
				var bi := 0
				for i in range(1, cands.size()):
					if _lightning_less(cands[i], cands[bi], impact):
						bi = i
				var pick: Vector2i = cands[bi]
				cands.remove_at(bi)
				chain.append(pick)
				for n in neighbors(pick):
					if grid.has(n) and grid[n].y != Kind.STONE and not chain.has(n) and not cands.has(n):
						cands.append(n)
			for c3 in chain:
				_remove(c3, res.popped)
				removed.append(c3)
			_after_removal(removed, res)
		_:
			pass
	_finish_score(res)
	return res


static func _lightning_less(a: Vector2i, b: Vector2i, impact: Vector2) -> bool:
	var da := cell_center(a, Vector2.ZERO).distance_squared_to(impact)
	var db := cell_center(b, Vector2.ZERO).distance_squared_to(impact)
	if absf(da - db) > 1e-6:
		return da < db
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


## Removes the cells a fireball destroyed (stone included).
func resolve_fireball(cells: Array) -> Dictionary:
	var res := _new_result()
	var removed: Array = []
	for c in cells:
		if grid.has(c):
			var v: Vector2i = grid[c]
			if v.y == Kind.RESCUE:
				_remove(c, res.freed)
				res.rescued += 1
			else:
				_remove(c, res.popped)
			removed.append(c)
	_after_removal(removed, res)
	_finish_score(res)
	return res


# ------------------------------------------------------------------ helpers
func duplicate_board() -> BoardLogic:
	var b := BoardLogic.new()
	b.grid = grid.duplicate()
	return b
