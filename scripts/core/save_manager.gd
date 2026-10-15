extends Node
## Local persistence. The file stores {payload: "<json string>", checksum: int}.
## On load the checksum is verified; a corrupt/missing save falls back to the
## backup, then to defaults. Every field is sanitised so bad values can't crash
## the game. Versioned: _migrate() upgrades older saves step by step.

signal changed

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak.json"
const SAVE_VERSION := 2
const POWER_IDS := ["rainbow", "bomb", "lightning", "fireball", "color_switch", "time_freeze"]

var data: Dictionary = {}
var recovered_from_corruption := false


func _ready() -> void:
	load_game()


func default_data() -> Dictionary:
	var start_coins := 100
	var powers := {}
	for id in POWER_IDS:
		powers[id] = 0
	powers["color_switch"] = 2
	powers["rainbow"] = 1
	powers["bomb"] = 1
	powers["lightning"] = 1
	powers["fireball"] = 1
	powers["time_freeze"] = 1
	return {
		"version": SAVE_VERSION,
		"coins": start_coins,
		"unlocked_level": 1,
		"levels": {},  # "7": {"stars": 2, "best": 1450}
		"settings": {"sound": true, "music": true, "vibration": true},
		"powers": powers,
		"daily": {"last_day": -1, "streak": 0},
		"achievements": {},
		"stats": {"pops": 0, "levels_won": 0, "high_score": 0, "powers_used": 0, "rewarded_today": 0, "rewarded_day": -1},
	}


# ------------------------------------------------------------------ load / save
func load_game() -> void:
	recovered_from_corruption = false
	var loaded: Variant = _read_file(SAVE_PATH)
	if loaded == null and FileAccess.file_exists(SAVE_PATH):
		recovered_from_corruption = true
		push_warning("Save corrupt, trying backup")
		loaded = _read_file(BACKUP_PATH)
	if loaded == null:
		if FileAccess.file_exists(SAVE_PATH):
			recovered_from_corruption = true
		data = default_data()
		if recovered_from_corruption:
			save_game()
		return
	data = _sanitize(_migrate(loaded))


func _read_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var outer: Variant = JSON.parse_string(f.get_as_text())
	if typeof(outer) != TYPE_DICTIONARY or not outer.has("payload") or not outer.has("checksum"):
		return null
	var payload_text := str(outer["payload"])
	if payload_text.hash() != int(outer["checksum"]):
		return null
	var inner: Variant = JSON.parse_string(payload_text)
	if typeof(inner) != TYPE_DICTIONARY:
		return null
	return inner


func save_game() -> void:
	data["version"] = SAVE_VERSION
	var payload_text := JSON.stringify(data)
	var outer := JSON.stringify({"payload": payload_text, "checksum": payload_text.hash()})
	# keep the previous good file as a backup, then write atomically via a temp file
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write save file")
		return
	f.store_string(outer)
	f.close()
	DirAccess.rename_absolute(tmp, SAVE_PATH)
	changed.emit()


func _migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v < 2:
		# v1 had no stats / achievements / daily block
		if not d.has("stats"):
			d["stats"] = {}
		if not d.has("achievements"):
			d["achievements"] = {}
		if not d.has("daily"):
			d["daily"] = {}
		v = 2
	d["version"] = v
	return d


func _sanitize(d: Dictionary) -> Dictionary:
	var out := default_data()
	out["coins"] = clampi(int(d.get("coins", out["coins"])), 0, 99999999)
	out["unlocked_level"] = clampi(int(d.get("unlocked_level", 1)), 1, 1000)
	if typeof(d.get("levels")) == TYPE_DICTIONARY:
		for k in d["levels"]:
			var e: Variant = d["levels"][k]
			if typeof(e) == TYPE_DICTIONARY and str(k).is_valid_int():
				out["levels"][str(int(str(k)))] = {
					"stars": clampi(int(e.get("stars", 0)), 0, 3),
					"best": clampi(int(e.get("best", 0)), 0, 99999999),
				}
	if typeof(d.get("settings")) == TYPE_DICTIONARY:
		for k in ["sound", "music", "vibration"]:
			out["settings"][k] = bool(d["settings"].get(k, true))
	if typeof(d.get("powers")) == TYPE_DICTIONARY:
		for k in POWER_IDS:
			out["powers"][k] = clampi(int(d["powers"].get(k, out["powers"][k])), 0, 999)
	if typeof(d.get("daily")) == TYPE_DICTIONARY:
		out["daily"]["last_day"] = int(d["daily"].get("last_day", -1))
		out["daily"]["streak"] = clampi(int(d["daily"].get("streak", 0)), 0, 3650)
	if typeof(d.get("achievements")) == TYPE_DICTIONARY:
		for k in d["achievements"]:
			out["achievements"][str(k)] = bool(d["achievements"][k])
	if typeof(d.get("stats")) == TYPE_DICTIONARY:
		for k in out["stats"]:
			out["stats"][k] = clampi(int(d["stats"].get(k, out["stats"][k])), -1, 999999999)
	# a level can't be unlocked beyond (highest completed + 1)
	var highest := 0
	for k in out["levels"]:
		if out["levels"][k]["stars"] > 0:
			highest = maxi(highest, int(k))
	out["unlocked_level"] = clampi(out["unlocked_level"], 1, maxi(highest + 1, 1)) if not OS.is_debug_build() else out["unlocked_level"]
	return out


func reset_all() -> void:
	data = default_data()
	save_game()


# ------------------------------------------------------------------ accessors
func get_setting(key: String) -> bool:
	return bool(data["settings"].get(key, true))


func set_setting(key: String, value: bool) -> void:
	data["settings"][key] = value
	save_game()


func level_stars(id: int) -> int:
	return int(data["levels"].get(str(id), {}).get("stars", 0))


func level_best(id: int) -> int:
	return int(data["levels"].get(str(id), {}).get("best", 0))


func is_level_unlocked(id: int) -> bool:
	return id <= int(data["unlocked_level"])


## Records a win. Returns true when this was the first completion.
func record_win(id: int, stars: int, score: int) -> bool:
	var key := str(id)
	var first: bool = not data["levels"].has(key) or int(data["levels"][key]["stars"]) == 0
	var old: Dictionary = data["levels"].get(key, {"stars": 0, "best": 0})
	data["levels"][key] = {"stars": maxi(int(old["stars"]), stars), "best": maxi(int(old["best"]), score)}
	data["unlocked_level"] = maxi(int(data["unlocked_level"]), id + 1)
	data["stats"]["levels_won"] = int(data["stats"]["levels_won"]) + 1
	data["stats"]["high_score"] = maxi(int(data["stats"]["high_score"]), score)
	save_game()
	return first


func total_stars() -> int:
	var n := 0
	for k in data["levels"]:
		n += int(data["levels"][k]["stars"])
	return n
