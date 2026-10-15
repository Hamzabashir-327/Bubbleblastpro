extends Screen

var _debug_label: Label


func _ready() -> void:
	var vb := setup_layout(1, false)
	vb.add_child(header("Settings", true, "settings"))
	vb.add_child(_toggle("Sound effects", "sound"))
	vb.add_child(_toggle("Music", "music"))
	vb.add_child(_toggle("Vibration", "vibration"))

	var privacy := UIKit.button("Privacy Policy", UIKit.C_BLUE, Vector2(0, 96), 32)
	privacy.pressed.connect(func() -> void:
		AudioManager.play("click")
		if not GameManager.open_privacy_policy():
			_toast("Privacy policy link is not configured yet."))
	vb.add_child(privacy)
	if AdManager.privacy_options_required:
		var opts := UIKit.button("Ad privacy options", UIKit.C_BLUE, Vector2(0, 96), 32)
		opts.pressed.connect(func() -> void: AdManager.show_privacy_options())
		vb.add_child(opts)
	var reset := UIKit.button("Reset progress", UIKit.C_PINK.darkened(0.2), Vector2(0, 96), 32)
	reset.pressed.connect(_confirm_reset)
	vb.add_child(reset)
	vb.add_child(UIKit.label("Bubble Blast Pro - Mystic Worlds v%s\nAll art and sound generated for this game." % str(GameManager.config.get("version_name", "0.1")), 22, UIKit.C_MUTED))
	if GameManager.is_debug_tools_enabled():
		_build_debug(vb)


func _toggle(title: String, key: String) -> Control:
	var p := UIKit.panel(UIKit.C_PANEL, 28)
	var hb := HBoxContainer.new()
	p.add_child(hb)
	var l := UIKit.label(title, 34, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	var b := UIKit.button("ON" if SaveManager.get_setting(key) else "OFF", UIKit.C_TEAL if SaveManager.get_setting(key) else UIKit.C_GRAY, Vector2(160, 84), 32)
	b.pressed.connect(func() -> void:
		var v := not SaveManager.get_setting(key)
		SaveManager.set_setting(key, v)
		b.text = "ON" if v else "OFF"
		b.add_theme_stylebox_override("normal", UIKit.style(UIKit.C_TEAL if v else UIKit.C_GRAY))
		AudioManager.apply_settings()
		AudioManager.play("click")
		if key == "vibration" and v:
			GameManager.vibrate(60))
	hb.add_child(b)
	return p


func _confirm_reset() -> void:
	var m := ModalPanel.create("Reset progress?", self)
	m.body.add_child(UIKit.label("This deletes levels, coins and power-ups on this device.", 28))
	m.add_button("Cancel", UIKit.C_TEAL, m.close)
	m.add_button("Yes, reset", UIKit.C_PINK, func() -> void:
		SaveManager.reset_all()
		m.close()
		GameManager.go_to("main_menu"))


func _toast(text: String) -> void:
	var m := ModalPanel.create("", self)
	m.body.add_child(UIKit.label(text, 30))
	m.add_button("OK", UIKit.C_TEAL, m.close)


func _build_debug(vb: VBoxContainer) -> void:
	vb.add_child(UIKit.label("DEBUG TOOLS (debug builds only)", 24, UIKit.C_ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var unlock := UIKit.button("Unlock all", UIKit.C_PANEL_LIGHT, Vector2(0, 80), 24)
	unlock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock.pressed.connect(func() -> void:
		SaveManager.data["unlocked_level"] = LevelManager.level_count
		SaveManager.save_game()
		_debug_label.text = "All levels unlocked")
	row.add_child(unlock)
	var coins := UIKit.button("+1000 coins", UIKit.C_PANEL_LIGHT, Vector2(0, 80), 24)
	coins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coins.pressed.connect(func() -> void: CoinManager.add(1000))
	row.add_child(coins)
	var check := UIKit.button("Validate levels", UIKit.C_PANEL_LIGHT, Vector2(0, 80), 24)
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.pressed.connect(func() -> void: _debug_label.text = LevelManager.validate_all())
	row.add_child(check)
	_debug_label = UIKit.label("Ads: %s" % AdManager.status_text, 22, UIKit.C_MUTED)
	vb.add_child(_debug_label)


func on_back() -> void:
	GameManager.go_to("main_menu")
