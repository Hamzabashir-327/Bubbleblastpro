class_name Screen
extends Control
## Base class for full-screen menus: background, safe-area margins, optional banner
## reserve, and Android back-button handling.

var banner_key := ""  # name from ads_config.json "banner.screens"; "" = no banner here


## Builds the standard layout and returns the VBox to fill.
func setup_layout(world: int = 1, reserve_banner: bool = false) -> VBoxContainer:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/world_%d.png" % clampi(world, 1, 3))
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_child(BubbleBackdrop.new())
	var insets := GameManager.get_safe_insets()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 24 + int(insets.top))
	var bottom := 24 + int(insets.bottom)
	if reserve_banner:
		bottom += AdManager.banner_reserve_px()
	margin.add_theme_constant_override("margin_bottom", bottom)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	margin.add_child(vb)
	if banner_key != "":
		AdManager.show_banner(banner_key)
	else:
		AdManager.hide_banner()
	return vb


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		on_back()


## Override: Android back button / Escape.
func on_back() -> void:
	GameManager.go_to("main_menu")


func header(title: String, show_back: bool = true, title_key: String = "") -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	if show_back:
		var back := UIKit.button("", UIKit.C_TEAL, Vector2(80, 80), 30)
		back.icon = load("res://assets/ui/back.png")
		back.expand_icon = true
		back.pressed.connect(func() -> void:
			AudioManager.play("click")
			on_back())
		hb.add_child(back)
	var t: Control = UIKit.title_image(title_key, title, 70.0) if title_key != "" else UIKit.label(title, 46)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(t)
	hb.add_child(UIKit.coin_chip())
	return hb
