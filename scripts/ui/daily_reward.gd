extends Screen

var _claim_btn: Button
var _info: Label


func _ready() -> void:
	banner_key = "daily_reward"
	var vb := setup_layout(1, true)
	vb.add_child(header("Daily Reward", true, "daily"))
	vb.add_child(UIKit.label("Come back every day for bigger rewards!", 28, UIKit.C_MUTED))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(grid)
	var table := RewardManager.daily_table()
	var state := RewardManager.daily_state()
	var next_idx := RewardManager.next_index() if state == "ready" else -1
	var streak := RewardManager.current_streak()
	var done_upto := next_idx - 1 if state == "ready" else (streak - 1) % table.size()
	for i in table.size():
		grid.add_child(_day_card(i, table[i], i == next_idx, i <= done_upto))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	_info = UIKit.label("", 28, UIKit.C_MUTED)
	vb.add_child(_info)
	_claim_btn = UIKit.button("Claim", UIKit.C_PINK, Vector2(0, 120), 44)
	_claim_btn.pressed.connect(_on_claim)
	vb.add_child(_claim_btn)
	_update_state(state)


func _day_card(index: int, reward: Dictionary, is_next: bool, claimed: bool) -> Control:
	var color := UIKit.C_ACCENT.darkened(0.25) if is_next else (UIKit.C_GRAY if claimed else UIKit.C_PANEL_LIGHT)
	var p := UIKit.panel(color, 24)
	p.custom_minimum_size = Vector2(140, 190)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	v.add_child(UIKit.label("Day %d" % (index + 1), 24))
	v.add_child(UIKit.icon("res://assets/ui/coin.png", Vector2(56, 56)))
	v.add_child(UIKit.label("%d" % int(reward.get("coins", 0)), 30, UIKit.C_ACCENT))
	if reward.has("power"):
		var def: Dictionary = PowerManager.DEFS.get(str(reward["power"]), {})
		if not def.is_empty():
			v.add_child(UIKit.icon(def.icon, Vector2(44, 44)))
	if claimed:
		v.add_child(UIKit.label("Done", 20, UIKit.C_TEAL))
	return p


func _update_state(state: String) -> void:
	match state:
		"ready":
			_claim_btn.disabled = false
			_claim_btn.text = "Claim"
			_info.text = ""
		"claimed":
			_claim_btn.disabled = true
			_claim_btn.text = "Come back tomorrow"
			_info.text = "Streak: %d day(s)" % RewardManager.current_streak()
		_:
			_claim_btn.disabled = true
			_claim_btn.text = "Unavailable"
			_info.text = "Your device clock looks wrong. Fix the date to claim."


func _on_claim() -> void:
	var reward := RewardManager.claim_daily()
	if reward.is_empty():
		_update_state(RewardManager.daily_state())
		return
	AudioManager.play("coin")
	GameManager.vibrate(40)
	_info.text = "+%d coins!" % int(reward.get("coins", 0))
	_claim_btn.disabled = true
	_claim_btn.text = "Claimed!"
	await get_tree().create_timer(1.0).timeout
	GameManager.go_to("main_menu")


func on_back() -> void:
	GameManager.go_to("main_menu")
