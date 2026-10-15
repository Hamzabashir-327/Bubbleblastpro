class_name LevelData
extends RefCounted
## Static helpers to parse and validate one level JSON document. Pure functions
## (no autoloads) so they also run inside tests/run_tests.gd.

const OBJECTIVES := ["clear", "score", "rescue"]


## Returns {"ok": bool, "error": String, "level": Dictionary}. The returned
## level dictionary is normalised (ints, defaults filled in).
static func parse(json_text: String, expected_id: int = -1) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("not a JSON object")
	return validate(parsed, expected_id)


static func validate(d: Dictionary, expected_id: int = -1) -> Dictionary:
	for key in ["id", "shots", "objective", "rows", "star_scores", "colors"]:
		if not d.has(key):
			return _fail("missing field '%s'" % key)
	var lvl := {}
	lvl["id"] = int(d["id"])
	if expected_id >= 0 and lvl["id"] != expected_id:
		return _fail("id %d does not match file number %d" % [lvl["id"], expected_id])
	lvl["name"] = str(d.get("name", "Level %d" % lvl["id"]))
	lvl["world"] = clampi(int(d.get("world", 1)), 1, 99)
	lvl["boss"] = bool(d.get("boss", false))
	lvl["tip"] = str(d.get("tip", ""))
	lvl["colors"] = int(d["colors"])
	if lvl["colors"] < 2 or lvl["colors"] > BoardLogic.NUM_COLORS:
		return _fail("colors must be 2..%d" % BoardLogic.NUM_COLORS)
	lvl["shots"] = int(d["shots"])
	if lvl["shots"] < 1 or lvl["shots"] > 300:
		return _fail("shots out of range")
	lvl["time_limit"] = maxi(0, int(d.get("time_limit", 0)))
	# v2 rules: the ceiling sinks `shot` px after every shot (+`miss` px more after a shot that popped nothing)
	var ds: Dictionary = d.get("descent", {"shot": 6.0, "miss": 14.0}) if typeof(d.get("descent", null)) == TYPE_DICTIONARY else {"shot": 6.0, "miss": 14.0}
	lvl["descent"] = {"shot": clampf(float(ds.get("shot", 6.0)), 0.0, 60.0), "miss": clampf(float(ds.get("miss", 14.0)), 0.0, 120.0)}
	if typeof(d["objective"]) != TYPE_DICTIONARY or not d["objective"].has("type"):
		return _fail("objective needs a type")
	var obj: Dictionary = d["objective"]
	var otype := str(obj["type"])
	if not OBJECTIVES.has(otype):
		return _fail("unknown objective '%s'" % otype)
	var target := int(obj.get("target", 0))
	if otype != "clear" and target <= 0:
		return _fail("objective '%s' needs target > 0" % otype)
	lvl["objective"] = {"type": otype, "target": target}
	if typeof(d["star_scores"]) != TYPE_ARRAY or d["star_scores"].size() != 2:
		return _fail("star_scores must be [two_star, three_star]")
	lvl["star_scores"] = [int(d["star_scores"][0]), int(d["star_scores"][1])]
	if lvl["star_scores"][0] <= 0 or lvl["star_scores"][1] < lvl["star_scores"][0]:
		return _fail("star_scores must be increasing and positive")
	if typeof(d["rows"]) != TYPE_ARRAY or d["rows"].is_empty() or d["rows"].size() > 14:
		return _fail("rows must be an array of 1..14 strings")
	var rows: Array = []
	for r in d["rows"]:
		rows.append(str(r))
	var board := BoardLogic.new()
	var err := board.load_rows(rows)
	if err != "":
		return _fail(err)
	for cell in board.grid:
		var v: Vector2i = board.grid[cell]
		if v.x >= lvl["colors"]:
			return _fail("colour %d used but level declares %d colours" % [v.x, lvl["colors"]])
	# every bubble must hang from the ceiling, otherwise it would fall at the first shot
	var res := BoardLogic._new_result()
	var test := board.duplicate_board()
	test._drop_floating(res)
	if not res.dropped.is_empty():
		return _fail("%d bubbles are not connected to the ceiling" % res.dropped.size())
	if board.count_colored() == 0:
		return _fail("level has no colored bubbles")
	if otype == "rescue" and board.count_kind(BoardLogic.Kind.RESCUE) < target:
		return _fail("rescue target %d exceeds critters on board (%d)" % [target, board.count_kind(BoardLogic.Kind.RESCUE)])
	lvl["rows"] = rows
	return {"ok": true, "error": "", "level": lvl}


static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "level": {}}
