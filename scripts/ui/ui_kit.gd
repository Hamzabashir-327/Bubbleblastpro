class_name UIKit
extends RefCounted
## Small factory for consistent, mobile-friendly controls (>= 96 px tap targets on a
## 720-wide layout, which is ~48 dp). Everything is code-built so no theme file is needed.

const C_BG := Color("0f4d24")
const C_PANEL := Color("1f7a3a")
const C_PANEL_LIGHT := Color("3aa655")
const C_ACCENT := Color("ffc82e")
const C_TEAL := Color("2fd36b")     # "green" in the new theme (name kept for existing scripts)
const C_PINK := Color("ff4f8b")
const C_BLUE := Color("2f8cff")
const C_GRAY := Color("6a7fb0")
const C_ORANGE := Color("ff8f1f")
const C_VIOLET := Color("8d5cff")
const C_TEXT := Color("ffffff")
const C_MUTED := Color("d8ecff")
const C_OUTLINE := Color("0d3b1c")

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/Poppins-Bold.ttf")
	return _font


static func style(color: Color, radius: int = 26, border: Color = Color(1, 1, 1, 1)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(4)
	s.border_color = border
	# hard navy "base" under the button gives the chunky 3D candy look
	s.shadow_color = Color(0.02, 0.2, 0.08, 0.65)
	s.shadow_size = 2
	s.shadow_offset = Vector2(0, 7)
	s.anti_aliasing = true
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 10
	s.content_margin_bottom = 14
	return s


static func button(text: String, color: Color = C_TEAL, min_size: Vector2 = Vector2(320, 96), font_size: int = 34) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	b.add_theme_color_override("font_outline_color", color.darkened(0.55))
	b.add_theme_constant_override("outline_size", maxi(5, font_size / 5))
	b.add_theme_stylebox_override("normal", style(color))
	b.add_theme_stylebox_override("hover", style(color.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", style(color.darkened(0.2)))
	b.add_theme_stylebox_override("disabled", style(C_GRAY, 26, Color(1, 1, 1, 0.1)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func() -> void: _scale_to(b, 0.93, 0.07))
	b.button_up.connect(func() -> void: _scale_to(b, 1.0, 0.12))
	return b


static func label(text: String, size: int = 32, color: Color = C_TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", C_OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.add_theme_color_override("font_shadow_color", Color(0.02, 0.08, 0.3, 0.45))
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 14))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel(color: Color = C_PANEL, radius: int = 32) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(color, radius))
	return p


static func icon(path: String, size: Vector2 = Vector2(64, 64)) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.custom_minimum_size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func spacer(h: float = 16.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func stars_row(count: int, size: float = 72.0) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	for i in range(3):
		hb.add_child(icon("res://assets/ui/star_on.png" if i < count else "res://assets/ui/star_off.png", Vector2(size, size)))
	return hb


## Header showing the coin balance, kept in sync automatically.
static func coin_chip() -> PanelContainer:
	var p := panel(C_PANEL_LIGHT, 40)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.add_child(icon("res://assets/ui/coin.png", Vector2(48, 48)))
	var l := label(str(CoinManager.balance()), 34, C_ACCENT)
	hb.add_child(l)
	p.add_child(hb)
	var on_change := func(total: int) -> void:
		if is_instance_valid(l):
			l.text = str(total)
	CoinManager.coins_changed.connect(on_change)
	var on_exit := func() -> void:
		if CoinManager.coins_changed.is_connected(on_change):
			CoinManager.coins_changed.disconnect(on_change)
	p.tree_exited.connect(on_exit)
	return p


# ------------------------------------------------------------------ animation helpers
static func _scale_to(n: Control, target: float, secs: float) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(target, target), secs).set_trans(Tween.TRANS_SINE)


## Entrance: fade + overshoot scale. Call AFTER the node was added to the tree.
static func pop_in(n: Control, delay: float = 0.0) -> void:
	n.modulate.a = 0.0
	n.scale = Vector2(0.82, 0.82)
	n.resized.connect(func() -> void: n.pivot_offset = n.size / 2.0)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "modulate:a", 1.0, 0.35).set_delay(delay)
	tw.tween_property(n, "scale", Vector2.ONE, 0.5).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Endless gentle heartbeat (call-to-action buttons). `delay` lets an entrance animation finish first.
static func pulse(n: Control, amount: float = 0.05, delay: float = 0.0) -> void:
	n.resized.connect(func() -> void: n.pivot_offset = n.size / 2.0)
	if delay <= 0.0:
		_start_pulse(n, amount)
	else:
		(Engine.get_main_loop() as SceneTree).create_timer(delay).timeout.connect(_start_pulse.bind(n, amount))


static func _start_pulse(node: Variant, amount: float) -> void:
	if not is_instance_valid(node):
		return
	var n: Control = node
	if not n.is_inside_tree():
		return
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "scale", Vector2(1.0 + amount, 1.0 + amount), 0.75).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "scale", Vector2.ONE, 0.75).set_trans(Tween.TRANS_SINE)


## Endless slow sway (logo).
static func sway(n: Control, degrees: float = 2.0) -> void:
	n.resized.connect(func() -> void: n.pivot_offset = n.size / 2.0)
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "rotation", deg_to_rad(degrees), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "rotation", deg_to_rad(-degrees), 1.6).set_trans(Tween.TRANS_SINE)


## Loading-screen credit badge ("Handcrafted with love by Hamza"). Shown on the splash only.
static func powered_by(width: float = 520.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://assets/ui/powered_by.png")
	t.custom_minimum_size = Vector2(width, width * 190.0 / 700.0)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## 3D gold/pink lettering image (assets/ui/title_<key>.png) or a plain label if the image is missing.
static func title_image(key: String, fallback_text: String, height: float = 78.0) -> Control:
	var path := "res://assets/ui/title_%s.png" % key
	if not ResourceLoader.exists(path):
		return label(fallback_text, 46, C_ACCENT)
	var t := TextureRect.new()
	t.texture = load(path)
	var tex_size: Vector2 = t.texture.get_size()
	t.custom_minimum_size = Vector2(height * tex_size.x / tex_size.y, height)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
