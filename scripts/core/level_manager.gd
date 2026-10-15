extends Node
## Loads, validates and caches level files. Invalid files never crash the game:
## get_level() returns {"ok": false, "error": ...} and the UI shows a safe message.

const LEVEL_DIR := "res://data/levels/level_%03d.json"

var level_count: int = 30
var _cache: Dictionary = {}


func _ready() -> void:
	level_count = GameManager.config_int("level_count", 30)


func get_level(id: int) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var path := LEVEL_DIR % id
	var result: Dictionary
	if not FileAccess.file_exists(path):
		result = {"ok": false, "error": "level file missing: %s" % path, "level": {}}
	else:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			result = {"ok": false, "error": "cannot open %s" % path, "level": {}}
		else:
			result = LevelData.parse(f.get_as_text(), id)
	if not result.ok:
		push_warning("Level %d invalid: %s" % [id, result.error])
	_cache[id] = result
	return result


func has_level(id: int) -> bool:
	return id >= 1 and id <= level_count


## Development helper: validates every level, returns a human-readable report.
func validate_all() -> String:
	_cache.clear()
	var bad: Array[String] = []
	for i in range(1, level_count + 1):
		var r := get_level(i)
		if not r.ok:
			bad.append("L%d: %s" % [i, r.error])
	if bad.is_empty():
		return "All %d levels valid." % level_count
	return "%d invalid:\n%s" % [bad.size(), "\n".join(bad)]


func star_rating(level: Dictionary, score: int) -> int:
	var s: Array = level.star_scores
	if score >= s[1]:
		return 3
	if score >= s[0]:
		return 2
	return 1
