extends Screen


func _ready() -> void:
	var vb := setup_layout(1, false)
	vb.add_child(header("Trophies", true, "trophies"))
	var st: Dictionary = SaveManager.data["stats"]
	vb.add_child(UIKit.label("Stars: %d    High score: %d    Levels won: %d" % [SaveManager.total_stars(), int(st["high_score"]), int(st["levels_won"])], 26, UIKit.C_MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for a in RewardManager.ACHIEVEMENTS:
		var done := RewardManager.is_unlocked(a["id"])
		var p := UIKit.panel(UIKit.C_PANEL_LIGHT if done else UIKit.C_PANEL, 26)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		p.add_child(hb)
		hb.add_child(UIKit.icon("res://assets/ui/star_on.png" if done else "res://assets/ui/star_off.png", Vector2(72, 72)))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(a["name"], 30, UIKit.C_ACCENT if done else UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
		col.add_child(UIKit.label(a["desc"], 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		hb.add_child(col)
		hb.add_child(UIKit.label("+%d" % int(a["coins"]), 30, UIKit.C_ACCENT if done else UIKit.C_MUTED))
		list.add_child(p)


func on_back() -> void:
	GameManager.go_to("main_menu")
