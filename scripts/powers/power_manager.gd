class_name PowerManager
extends RefCounted
## Per-level bookkeeping for power-ups: use limits and shot-based cooldowns.
## Inventory itself lives in CoinManager; effects are implemented in BoardLogic
## (Proj.* resolution) and GameScreen (colour switch, time freeze).

const ORDER := ["rainbow", "bomb", "lightning", "fireball", "color_switch", "time_freeze"]

const DEFS := {
	"rainbow": {
		"name": "Rainbow Orb", "icon": "res://assets/icons/power_rainbow.png", "kind": "shot",
		"proj": BoardLogic.Proj.RAINBOW, "sfx": "power",
		"desc": "Your next bubble becomes the colour that makes the biggest match.",
	},
	"bomb": {
		"name": "Nova Bomb", "icon": "res://assets/icons/power_bomb.png", "kind": "shot",
		"proj": BoardLogic.Proj.BOMB, "sfx": "explosion",
		"desc": "Blasts every bubble within two cells of where it lands, stones included.",
	},
	"lightning": {
		"name": "Lightning Chain", "icon": "res://assets/icons/power_lightning.png", "kind": "shot",
		"proj": BoardLogic.Proj.LIGHTNING, "sfx": "lightning",
		"desc": "Chains through the 8 nearest bubbles around the impact (not stone).",
	},
	"fireball": {
		"name": "Fireball", "icon": "res://assets/icons/power_fireball.png", "kind": "shot",
		"proj": BoardLogic.Proj.FIREBALL, "sfx": "fire",
		"desc": "Burns straight through up to 6 bubbles along its path, stones included.",
	},
	"color_switch": {
		"name": "Colour Switch", "icon": "res://assets/icons/power_color_switch.png", "kind": "instant",
		"proj": BoardLogic.Proj.NORMAL, "sfx": "power",
		"desc": "Changes your current bubble to another colour on the board. Free action.",
	},
	"time_freeze": {
		"name": "Time Freeze", "icon": "res://assets/icons/power_time_freeze.png", "kind": "instant",
		"proj": BoardLogic.Proj.NORMAL, "sfx": "freeze",
		"desc": "Pauses the level timer for 10 seconds. Only useful on timed levels.",
	},
}

var uses: Dictionary = {}
var cooldown: Dictionary = {}


func _init() -> void:
	for id in ORDER:
		uses[id] = 0
		cooldown[id] = 0


static func limit_for(id: String) -> int:
	return int(GameManager.config_get(["powers", id, "max_per_level"], 2))


static func cooldown_for(id: String) -> int:
	return int(GameManager.config_get(["powers", id, "cooldown_shots"], 0))


## "" when usable, otherwise a short reason: "none", "limit", "cooldown".
func check(id: String) -> String:
	if CoinManager.power_count(id) <= 0:
		return "none"
	if int(uses[id]) >= limit_for(id):
		return "limit"
	if int(cooldown[id]) > 0:
		return "cooldown"
	return ""


## Call exactly once when the power is actually spent.
func register_use(id: String) -> void:
	uses[id] = int(uses[id]) + 1
	cooldown[id] = cooldown_for(id)


## Call after every fired shot.
func tick_shot() -> void:
	for id in ORDER:
		if int(cooldown[id]) > 0:
			cooldown[id] = int(cooldown[id]) - 1


func uses_left(id: String) -> int:
	return maxi(0, limit_for(id) - int(uses[id]))
