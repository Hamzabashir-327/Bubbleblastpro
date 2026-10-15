extends Node
## Scene navigation with a fade, shared config access, safe-area insets, haptics.

const CONFIG_PATH := "res://data/config/game_config.json"
const SCENES := {
	"splash": "res://scenes/main/splash.tscn",
	"main_menu": "res://scenes/main/main_menu.tscn",
	"level_map": "res://scenes/world/level_map.tscn",
	"game": "res://scenes/game/game.tscn",
	"shop": "res://scenes/ui/shop.tscn",
	"daily_reward": "res://scenes/ui/daily_reward.tscn",
	"settings": "res://scenes/ui/settings.tscn",
	"achievements": "res://scenes/ui/achievements.tscn",
}

var config: Dictionary = {}
var current_level_id: int = 1
var last_won_level: int = 0   # set when a level is won; the level map animates the marker from it
var _fade: ColorRect
var _transitioning := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.08, 0.04, 0.18, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)


func _load_config() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		push_error("game_config.json missing - using built-in defaults")
		config = {}
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	config = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if config.is_empty():
		push_error("game_config.json is invalid - using built-in defaults")


func config_int(key: String, default_value: int) -> int:
	return int(config.get(key, default_value))


func config_get(path: Array, default_value: Variant = null) -> Variant:
	var cur: Variant = config
	for k in path:
		if typeof(cur) == TYPE_DICTIONARY and cur.has(k):
			cur = cur[k]
		else:
			return default_value
	return cur


func is_debug_tools_enabled() -> bool:
	return OS.is_debug_build() and bool(config.get("debug_tools_in_debug_builds", true))


# ------------------------------------------------------------------ navigation
func go_to(key: String) -> void:
	if _transitioning or not SCENES.has(key):
		return
	_transitioning = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP  # blocks taps during the fade
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.16)
	await tw.finished
	var err := get_tree().change_scene_to_file(SCENES[key])
	if err != OK:
		push_error("Could not open scene %s (error %d)" % [key, err])
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.2)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false


func start_level(id: int) -> void:
	current_level_id = id
	go_to("game")


# ------------------------------------------------------------------ device helpers
## Notch / gesture-bar insets expressed in viewport pixels.
func get_safe_insets() -> Dictionary:
	var out := {"top": 0.0, "bottom": 0.0}
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or OS.get_name() != "Android":
		return out
	var vp := get_viewport().get_visible_rect().size
	var scale_y := vp.y / float(win.y)
	out["top"] = clampf(float(safe.position.y) * scale_y, 0.0, 160.0)
	out["bottom"] = clampf(float(win.y - (safe.position.y + safe.size.y)) * scale_y, 0.0, 160.0)
	return out


func vibrate(ms: int = 30) -> void:
	if SaveManager.get_setting("vibration"):
		Input.vibrate_handheld(ms)


## Opens the privacy policy. Returns false if the owner has not set a real URL yet.
func open_privacy_policy() -> bool:
	var url := str(config.get("privacy_policy_url", ""))
	if url == "" or url.contains("REPLACE"):
		return false
	OS.shell_open(url)
	return true
