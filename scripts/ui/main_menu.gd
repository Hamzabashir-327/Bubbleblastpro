extends Screen


func _ready() -> void:
	banner_key = "main_menu"
	var vb := setup_layout(1, true)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(UIKit.coin_chip())
	vb.add_child(top)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.custom_minimum_size = Vector2(620, 370)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(logo)
	UIKit.pop_in(logo, 0.0)
	UIKit.sway(logo, 1.8)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var next := mini(int(SaveManager.data["unlocked_level"]), LevelManager.level_count)
	var play := UIKit.button("PLAY  -  Level %d" % next, UIKit.C_TEAL, Vector2(0, 136), 48)
	play.pressed.connect(func() -> void:
		AudioManager.play("click")
		GameManager.go_to("level_map"))
	vb.add_child(play)
	UIKit.pop_in(play, 0.15)
	UIKit.pulse(play, 0.035, 0.9)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 18)
	vb.add_child(row1)
	var daily := _menu_button("Daily Reward", UIKit.C_ORANGE, "daily_reward")
	if RewardManager.daily_state() == "ready":
		daily.text = "Daily Reward!"
		UIKit.pulse(daily, 0.04, 1.0)
	row1.add_child(daily)
	row1.add_child(_menu_button("Shop", UIKit.C_BLUE, "shop"))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 18)
	vb.add_child(row2)
	row2.add_child(_menu_button("Trophies", UIKit.C_VIOLET, "achievements"))
	row2.add_child(_menu_button("Settings", UIKit.C_GRAY, "settings"))
	UIKit.pop_in(row1, 0.3)
	UIKit.pop_in(row2, 0.42)



func _menu_button(text: String, color: Color, scene_key: String) -> Button:
	var b := UIKit.button(text, color, Vector2(0, 104), 32)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		AudioManager.play("click")
		GameManager.go_to(scene_key))
	return b


func on_back() -> void:
	get_tree().quit()
