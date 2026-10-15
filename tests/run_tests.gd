extends SceneTree
## Headless test runner:
##     godot --headless --path . -s tests/run_tests.gd
## (run `godot --headless --path . --import` once first so global classes exist)
## Exit code 0 = all passed.

var _fails := 0
var _checks := 0


func _init() -> void:
	_test_geometry()
	_test_load_rows()
	_test_rules()
	_test_all_levels()
	_test_vectors()
	print("")
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("FAIL: " + msg)


# ------------------------------------------------------------------ geometry
func _test_geometry() -> void:
	_check(BoardLogic.row_cols(0) == 10 and BoardLogic.row_cols(1) == 9, "row widths")
	for r in range(12):
		for c in range(BoardLogic.row_cols(r)):
			var cell := Vector2i(c, r)
			for n in BoardLogic.neighbors(cell):
				_check(BoardLogic.neighbors(n).has(cell), "neighbour symmetry %s <-> %s" % [cell, n])
				var d := BoardLogic.cell_center(cell, Vector2.ZERO).distance_to(BoardLogic.cell_center(n, Vector2.ZERO))
				_check(absf(d - 2.0 * BoardLogic.R) < 0.01, "neighbours touch: %s %s dist %f" % [cell, n, d])
	_check(BoardLogic.neighbors(Vector2i(0, 0)).size() == 2, "corner cell has 2 neighbours")


func _test_load_rows() -> void:
	var b := BoardLogic.new()
	_check(b.load_rows(["00", "0"]) != "", "reject wrong row length")
	_check(b.load_rows(["0000000000", "x00000000"]) != "", "reject unknown symbol")
	_check(b.load_rows(["01a#*AB...", "........."]) == "", "accept every symbol")
	_check(b.grid[Vector2i(2, 0)] == Vector2i(0, BoardLogic.Kind.ICE), "ice parsed")
	_check(b.grid[Vector2i(5, 0)] == Vector2i(0, BoardLogic.Kind.LOCKED), "locked parsed")


# ------------------------------------------------------------------ hand-made rule checks
# (identical scenarios run in tools/test_rules.py against the Python mirror)
func _board(rows: Array) -> BoardLogic:
	var b := BoardLogic.new()
	var err := b.load_rows(rows)
	_check(err == "", "board loads: " + err)
	return b


func _test_rules() -> void:
	var b := _board(["11........", "........."])
	var r := b.resolve_landing(Vector2i(2, 0), BoardLogic.Proj.NORMAL, 1)
	_check(r.pop_count == 3 and b.grid.is_empty(), "three in a row pop")

	b = _board(["1........."])
	r = b.resolve_landing(Vector2i(1, 0), BoardLogic.Proj.NORMAL, 1)
	_check(r.pop_count == 0 and r.landed and b.grid.size() == 2, "pair stays")

	b = _board(["11........", ".2.......", ".3........"])
	r = b.resolve_landing(Vector2i(2, 0), BoardLogic.Proj.NORMAL, 1)
	_check(r.pop_count == 3 and r.drop_count == 2, "unsupported bubbles drop (%d popped / %d dropped)" % [r.pop_count, r.drop_count])

	b = _board(["0a........"])
	r = b.resolve_landing(Vector2i(2, 0), BoardLogic.Proj.NORMAL, 0)
	_check(r.cracked.size() == 1 and r.pop_count == 2 and b.grid.has(Vector2i(1, 0)) and b.grid[Vector2i(1, 0)].y == BoardLogic.Kind.NORMAL, "ice cracks once, others pop")

	b = _board(["##........"])
	r = b.resolve_landing(Vector2i(2, 0), BoardLogic.Proj.NORMAL, 0)
	_check(r.pop_count == 0 and r.landed, "stone is never matched")

	b = _board(["11.A......"])
	r = b.resolve_landing(Vector2i(2, 0), BoardLogic.Proj.NORMAL, 1)
	_check(r.pop_count == 3 and r.unlocked.size() == 1 and b.grid[Vector2i(3, 0)].y == BoardLogic.Kind.NORMAL, "lock opens when a neighbour pops")

	b = _board(["11.*......"])
	r = b.resolve_landing(Vector2i(2, 0), BoardLogic.Proj.NORMAL, 1)
	_check(r.rescued == 1 and r.freed.size() == 1 and not b.grid.has(Vector2i(3, 0)), "critter freed by neighbour pop")

	b = _board(["11........", ".*......."])
	r = b.resolve_landing(Vector2i(2, 0), BoardLogic.Proj.NORMAL, 1)
	_check(r.rescued == 1, "critter below a popped match is rescued")

	b = _board(["0123450123", "012345012", "012345...."])
	var before := b.grid.size()
	r = b.resolve_landing(Vector2i(7, 2), BoardLogic.Proj.BOMB, 0)
	_check(r.pop_count >= 5 and b.grid.size() == before - r.pop_count - r.drop_count, "bomb clears a cluster (%d)" % r.pop_count)

	b = _board(["0123450123", "01#345012", "0123450..."])
	r = b.resolve_landing(Vector2i(8, 2), BoardLogic.Proj.LIGHTNING, 0)
	_check(r.popped.size() > 0 and r.popped.size() <= BoardLogic.LIGHTNING_CHAIN and b.grid.has(Vector2i(2, 1)), "lightning respects cap and skips stone (%d)" % r.popped.size())

	b = _board(["33........"])
	r = b.resolve_landing(Vector2i(2, 0), BoardLogic.Proj.RAINBOW, 5)
	_check(r.final_color == 3 and r.pop_count == 3, "rainbow joins the best group")

	b = _board(["0000000000"])
	var o := Vector2(20, 170)
	var tr := b.trace_shot(Vector2(360, 1050), Vector2(cos(deg_to_rad(20)), -sin(deg_to_rad(20))), o)
	_check(tr.points.size() >= 3, "shallow shot bounces off a wall")
	var inside := true
	for p in tr.points:
		if p.x < o.x + BoardLogic.R - 0.01 or p.x > o.x + 680.0 - BoardLogic.R + 0.01:
			inside = false
	_check(inside, "shot stays inside the walls")

	b = _board(["0123450123", "012345012", "0123450123", "012345012"])
	var fb := b.trace_fireball(Vector2(360, 1050), Vector2(0, -1), o)
	_check(fb.destroyed.size() > 0 and fb.destroyed.size() <= BoardLogic.FIREBALL_MAX_HITS, "fireball hits 1..6 bubbles (%d)" % fb.destroyed.size())
	r = b.resolve_fireball(fb.destroyed)
	_check(r.pop_count + r.rescued >= fb.destroyed.size(), "fireball removes what it hit")


# ------------------------------------------------------------------ shipped levels
func _test_all_levels() -> void:
	var count := 0
	var dir := DirAccess.open("res://data/levels")
	_check(dir != null, "levels directory opens")
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		count += 1
		var id := int(f.get_basename().trim_prefix("level_"))
		var txt := FileAccess.get_file_as_string("res://data/levels/" + f)
		var res := LevelData.parse(txt, id)
		_check(res.ok, "%s valid (%s)" % [f, res.error])
	_check(count == 30, "30 level files present (found %d)" % count)


# ------------------------------------------------------------------ Python <-> GDScript agreement
func _cells(list: Array) -> Array:
	var out: Array = []
	for x in list:
		var c: Vector2i = x["cell"] if typeof(x) == TYPE_DICTIONARY else x
		out.append([c.x, c.y])
	out.sort()
	return out


func _norm(list: Array) -> Array:
	var out: Array = []
	for c in list:
		out.append([int(c[0]), int(c[1])])
	out.sort()
	return out


func _test_vectors() -> void:
	var path := "res://tests/vectors/cases.json"
	if not FileAccess.file_exists(path):
		print("(no vectors file - run tools/make_test_vectors.py)")
		return
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	var bad := 0
	for cs in cases:
		var msg := _run_case(cs)
		if msg != "":
			bad += 1
			print("FAIL vector #%d: %s" % [int(cs["id"]), msg])
	_check(bad == 0, "%d of %d Python-mirror vectors differ" % [bad, cases.size()])
	print("vectors: %d cases, %d mismatches" % [cases.size(), bad])


func _run_case(cs: Dictionary) -> String:
	var b := BoardLogic.new()
	var err := b.load_rows(cs["rows"])
	if err != "":
		return "load " + err
	var origin := Vector2(cs["origin"][0], cs["origin"][1])
	var start := Vector2(cs["start"][0], cs["start"][1])
	var dir := Vector2(cs["dir"][0], cs["dir"][1])
	var proj := int(cs["proj"])
	var ex: Dictionary = cs["expect"]
	var res: Dictionary
	var end: Vector2
	if proj == BoardLogic.Proj.FIREBALL:
		var tr := b.trace_fireball(start, dir, origin)
		end = tr.end
		if _cells(tr.destroyed) != _norm(ex["destroyed"]):
			return "fireball destroyed cells differ"
		res = b.resolve_fireball(tr.destroyed)
	else:
		var tr2 := b.trace_shot(start, dir, origin)
		end = tr2.end
		if tr2.points.size() != int(ex["points"]):
			return "path corners %d vs %d" % [tr2.points.size(), int(ex["points"])]
		var cell := b.landing_cell(tr2.end, origin)
		if [cell.x, cell.y] != _norm([ex["cell"]])[0]:
			return "landing cell %s vs %s" % [cell, ex["cell"]]
		res = b.resolve_landing(cell, proj, int(cs["color"]))
	if absf(end.x - float(ex["end"][0])) > 0.05 or absf(end.y - float(ex["end"][1])) > 0.05:
		return "end point %s vs %s" % [end, ex["end"]]
	for key in ["popped", "dropped", "freed", "cracked", "unlocked"]:
		if _cells(res[key]) != _norm(ex[key]):
			return "%s differ" % key
	for key in ["rescued", "pop_count", "drop_count", "score"]:
		if int(res[key]) != int(ex[key]):
			return "%s %d vs %d" % [key, int(res[key]), int(ex[key])]
	if b.grid.size() != int(ex["remaining"]):
		return "remaining bubbles %d vs %d" % [b.grid.size(), int(ex["remaining"])]
	return ""
