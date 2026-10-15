extends Node
## Daily login reward (timezone-aware), achievements, and the capped
## "watch an ad for coins" allowance. Rewarded-ad grants themselves happen in the
## caller, only after AdManager reports a verified earned reward.

signal achievement_unlocked(id: String)

const ACHIEVEMENTS := [
	{"id": "first_win", "name": "First Pop", "desc": "Win your first level", "coins": 20},
	{"id": "pops_100", "name": "Popper", "desc": "Pop 100 bubbles", "coins": 30},
	{"id": "pops_1000", "name": "Bubble Master", "desc": "Pop 1000 bubbles", "coins": 100},
	{"id": "levels_10", "name": "Explorer", "desc": "Win 10 levels", "coins": 50},
	{"id": "stars_30", "name": "Star Collector", "desc": "Earn 30 stars", "coins": 80},
	{"id": "score_3000", "name": "High Roller", "desc": "Score 3000 in one level", "coins": 60},
	{"id": "power_10", "name": "Power Player", "desc": "Use 10 power-ups", "coins": 40},
	{"id": "daily_7", "name": "Regular", "desc": "Reach a 7-day login streak", "coins": 70},
]


# ------------------------------------------------------------------ day helpers
## Whole days since the Unix epoch in the player's LOCAL time zone.
func local_day() -> int:
	var bias_minutes := int(Time.get_time_zone_from_system().get("bias", 0))
	var local_unix := int(Time.get_unix_time_from_system()) + bias_minutes * 60
	return int(floor(local_unix / 86400.0))


# ------------------------------------------------------------------ daily reward
func daily_table() -> Array:
	var t: Variant = GameManager.config_get(["daily_rewards"], [])
	return t if typeof(t) == TYPE_ARRAY and not t.is_empty() else [{"coins": 30}]


func daily_state() -> String:
	var last := int(SaveManager.data["daily"]["last_day"])
	var today := local_day()
	if last < 0 or today > last:
		return "ready"
	if today == last:
		return "claimed"
	return "clock_back"  # device clock moved backwards: don't allow farming


## Index (0-based) of the reward the next claim would give.
func next_index() -> int:
	var last := int(SaveManager.data["daily"]["last_day"])
	var streak := int(SaveManager.data["daily"]["streak"])
	var today := local_day()
	if last >= 0 and today - last == 1:
		streak += 1
	else:
		streak = 1
	return (streak - 1) % daily_table().size()


func current_streak() -> int:
	return int(SaveManager.data["daily"]["streak"])


## Claims today's reward. Returns {} when not claimable.
func claim_daily() -> Dictionary:
	if daily_state() != "ready":
		return {}
	var last := int(SaveManager.data["daily"]["last_day"])
	var today := local_day()
	var streak := int(SaveManager.data["daily"]["streak"])
	streak = streak + 1 if (last >= 0 and today - last == 1) else 1
	var reward: Dictionary = daily_table()[(streak - 1) % daily_table().size()]
	SaveManager.data["daily"]["last_day"] = today
	SaveManager.data["daily"]["streak"] = streak
	SaveManager.save_game()
	CoinManager.add(int(reward.get("coins", 0)))
	if reward.has("power"):
		CoinManager.add_power(str(reward["power"]), 1)
	check_achievements()
	return reward


# ------------------------------------------------------------------ rewarded-ad coin allowance
func rewarded_coins_left_today() -> int:
	var cap := int(GameManager.config_get(["economy", "rewarded_coin_daily_cap"], 5))
	var stats: Dictionary = SaveManager.data["stats"]
	if int(stats["rewarded_day"]) != local_day():
		return cap
	return maxi(0, cap - int(stats["rewarded_today"]))


func note_rewarded_coin_claim() -> void:
	var stats: Dictionary = SaveManager.data["stats"]
	if int(stats["rewarded_day"]) != local_day():
		stats["rewarded_day"] = local_day()
		stats["rewarded_today"] = 0
	stats["rewarded_today"] = int(stats["rewarded_today"]) + 1
	SaveManager.save_game()


# ------------------------------------------------------------------ achievements
func is_unlocked(id: String) -> bool:
	return bool(SaveManager.data["achievements"].get(id, false))


func _condition_met(id: String) -> bool:
	var st: Dictionary = SaveManager.data["stats"]
	match id:
		"first_win": return int(st["levels_won"]) >= 1
		"pops_100": return int(st["pops"]) >= 100
		"pops_1000": return int(st["pops"]) >= 1000
		"levels_10": return int(st["levels_won"]) >= 10
		"stars_30": return SaveManager.total_stars() >= 30
		"score_3000": return int(st["high_score"]) >= 3000
		"power_10": return int(st["powers_used"]) >= 10
		"daily_7": return int(SaveManager.data["daily"]["streak"]) >= 7
	return false


## Unlocks anything newly earned, pays the coins, returns the list of new ids.
func check_achievements() -> Array[String]:
	var fresh: Array[String] = []
	for a in ACHIEVEMENTS:
		var id: String = a["id"]
		if not is_unlocked(id) and _condition_met(id):
			SaveManager.data["achievements"][id] = true
			fresh.append(id)
	if not fresh.is_empty():
		SaveManager.save_game()
		for id in fresh:
			for a in ACHIEVEMENTS:
				if a["id"] == id:
					CoinManager.add(int(a["coins"]))
			achievement_unlocked.emit(id)
	return fresh
