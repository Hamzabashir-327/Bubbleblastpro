extends Control
## Gameplay screen. Rules live in BoardLogic; this script handles input, animation,
## rendering (custom _draw, no per-bubble nodes), HUD, powers and the win/lose flow.

enum State { AIMING, FLYING, RESOLVING, ENDED }

const R := BoardLogic.R
const ROW_H := BoardLogic.ROW_H
const PROJECTILE_SPEED := 2100.0
const MIN_ANGLE := 12.0 * PI / 180.0
const HUD_TOP := 170.0       # board top = safe_top + HUD_TOP (matches tools/board_sim.py geometry)
const SHOOTER_BOTTOM := 230.0
const MAX_PARTICLES := 160
const END_BONUS_PER_SHOT := 50
const TITLE_KEYS := {"pause": "paused", "win": "level_complete", "lose": "game_over"}
const TIME_CONTINUE_SECONDS := 30.0

var logic := BoardLogic.new()
var level: Dictionary = {}
var power := PowerManager.new()
var rng := RandomNumberGenerator.new()

# layout (recomputed in _layout)
var vsize := Vector2(720, 1280)
var origin := Vector2(20, 170)
var shooter := Vector2(360, 1050)
var danger_y := 940.0
var drop := 0.0          # logical sinking of the ceiling in px (rules use this)
var drop_vis := 0.0      # animated value used for drawing
var descent_shot := 6.0
var descent_miss := 14.0
var insets := {"top": 0.0, "bottom": 0.0}

# state
var state: State = State.AIMING
var overlay_open := false
var score := 0
var shots_fired := 0
var rescued := 0
var combo := 0
var pops_total := 0
var time_left := 0.0
var freeze_time := 0.0
var cur_color := 0
var next_color := 0
var cur_proj: int = BoardLogic.Proj.NORMAL
var armed_power := ""
var continues_used := 0
var coins_doubled := false
var _time_up_pending := false
var _pending_reward := ""        # "continue" or "double_coins" while a rewarded ad is open
var _pending_loss_reason := ""
var _last_win_coins := 0

# input
var touch_index := -1
var aiming := false
var swap_candidate := false
var press_pos := Vector2.ZERO
var aim_dir := Vector2.UP
var aim_preview: Dictionary = {}

# projectile
var proj_points := PackedVector2Array()
var proj_seg := 0
var proj_pos := Vector2.ZERO
var proj_cell := Vector2i(-1, -1)
var proj_kind: int = BoardLogic.Proj.NORMAL
var proj_color := 0
var proj_destroyed: Array = []

# effects
var fx_pops: Array = []
var fx_falls: Array = []
var fx_particles: Array = []
var fx_texts: Array = []
var fx_flashes: Array = []
var fx_words: Array = []
var wobbles: Dictionary = {}   # cell -> {t, dir}: neighbours jiggle when a bubble lands
var shake := 0.0
var _so := Vector2.ZERO        # current screen-shake offset used by every draw transform

# resources
var tex_bubble: Array[Texture2D] = []
var tex_special: Dictionary = {}
var tex_bg: Texture2D

# HUD nodes
var hud: Control
var lbl_level: Label
var lbl_objective: Label
var lbl_shots: Label
var lbl_score: Label
var lbl_time: Label
var star_icons: Array[TextureRect] = []
var power_buttons: Dictionary = {}
var power_badges: Dictionary = {}
var _overlay: ModalPanel
var _overlay_kind := ""
var _toast_label: Label
var _style_frame: StyleBoxFlat
var _style_frame_glow: StyleBoxFlat
var _style_ceiling: StyleBoxFlat
var _style_bar: StyleBoxFlat
var _style_bar_fill: StyleBoxFlat
var tex_star_on: Texture2D
var tex_star_off: Texture2D
var tex_swap: Texture2D


func _make_styles() -> void:
	_style_frame = StyleBoxFlat.new()
	_style_frame.bg_color = Color(0.03, 0.13, 0.47, 0.66)
	_style_frame.set_corner_radius_all(26)
	_style_frame.set_border_width_all(5)
	_style_frame.border_color = Color(1, 1, 1, 1)
	_style_frame_glow = StyleBoxFlat.new()
	_style_frame_glow.bg_color = Color(0, 0, 0, 0)
	_style_frame_glow.set_corner_radius_all(32)
	_style_frame_glow.set_border_width_all(10)
	_style_frame_glow.border_color = Color(1, 1, 1, 0.2)
	_style_ceiling = StyleBoxFlat.new()
	_style_ceiling.bg_color = Color("9a622c")
	_style_ceiling.set_corner_radius_all(16)
	_style_ceiling.set_border_width_all(3)
	_style_ceiling.border_color = Color("ecd29a")
	_style_bar = StyleBoxFlat.new()
	_style_bar.bg_color = Color(0.02, 0.19, 0.09, 0.9)
	_style_bar.set_corner_radius_all(20)
	_style_bar.set_border_width_all(4)
	_style_bar.border_color = Color(1, 1, 1, 1)
	_style_bar_fill = StyleBoxFlat.new()
	_style_bar_fill.bg_color = Color("ffb52a")
	_style_bar_fill.set_corner_radius_all(16)


func _ready() -> void:
	_make_styles()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	rng.randomize()
	_load_textures()
	var result := LevelManager.get_level(GameManager.current_level_id)
	AdManager.hide_banner()
	AdManager.rewarded_finished.connect(_on_rewarded_finished)
	resized.connect(_layout)
	if not result.ok:
		_layout()
		_build_hud_minimal()
		_show_error("This level could not be loaded.\n(%s)" % result.error)
		return
	level = result.level
	tex_bg = load("res://assets/backgrounds/world_%d.png" % clampi(int(level.world), 1, 3))
	logic.load_rows(level.rows)
	var ds: Dictionary = level.descent
	descent_shot = float(ds.shot)
	descent_miss = float(ds.miss)
	time_left = float(level.time_limit)
	_layout()
	cur_color = _pick_color()
	next_color = _pick_color()
	_build_hud()
	_refresh_hud()
	if str(level.tip) != "":
		_toast(str(level.tip), 3.5)
	set_process(true)
	queue_redraw()


func _exit_tree() -> void:
	if AdManager.rewarded_finished.is_connected(_on_rewarded_finished):
		AdManager.rewarded_finished.disconnect(_on_rewarded_finished)


func _load_textures() -> void:
	tex_star_on = load("res://assets/ui/star_on.png")
	tex_star_off = load("res://assets/ui/star_off.png")
	tex_swap = load("res://assets/ui/swap.png")
	for i in range(BoardLogic.NUM_COLORS):
		tex_bubble.append(load("res://assets/bubbles/bubble_%d.png" % i))
	for n in ["ice", "stone", "lock", "critter", "rainbow", "bomb", "lightning", "fireball"]:
		tex_special[n] = load("res://assets/bubbles/%s.png" % n)


## Board origin used by the RULES (aim, collisions, landing) and by the PICTURE (animated sink).
func _ol() -> Vector2:
	return origin + Vector2(0.0, drop)


func _ov() -> Vector2:
	return origin + Vector2(0.0, drop_vis)


## Pixels between the lowest bubble's bottom edge and the red danger line (<= 0 means game over).
func _room_px() -> float:
	var low := logic.lowest_row()
	if low < 0:
		return 9999.0
	return danger_y - (origin.y + drop + 2.0 * R + float(low) * ROW_H)


func _layout() -> void:
	vsize = size
	if vsize.x < 10.0:
		vsize = get_viewport_rect().size
	insets = GameManager.get_safe_insets()
	var shooter_y: float = vsize.y - SHOOTER_BOTTOM - float(insets.bottom)
	origin = Vector2((vsize.x - BoardLogic.board_width()) / 2.0, float(insets.top) + HUD_TOP)
	shooter = Vector2(vsize.x / 2.0, shooter_y)
	danger_y = shooter_y - 110.0
	queue_redraw()


# ====================================================================== HUD
func _build_hud_minimal() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)


func _build_hud() -> void:
	_build_hud_minimal()
	var menu := Button.new()
	menu.custom_minimum_size = Vector2(76, 76)
	menu.size = Vector2(76, 76)
	menu.position = Vector2(24.0, float(insets.top) + 14.0)
	menu.icon = load("res://assets/ui/menu.png")
	menu.expand_icon = true
	menu.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed"]:
		menu.add_theme_stylebox_override(st, UIKit.style(UIKit.C_PANEL_LIGHT, 22))
	menu.pressed.connect(_open_pause)
	hud.add_child(menu)

	var dock := UIKit.panel(Color(0.16, 0.55, 0.26, 0.94), 34)
	dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left = 12
	dock.offset_right = -12
	dock.offset_bottom = -(float(insets.bottom) + 8.0)
	dock.offset_top = -(float(insets.bottom) + 136.0)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dock)
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 24
	bar.offset_right = -24
	bar.offset_bottom = -(float(insets.bottom) + 18.0)
	bar.offset_top = -(float(insets.bottom) + 126.0)
	bar.add_theme_constant_override("separation", 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bar)
	for id in PowerManager.ORDER:
		var def: Dictionary = PowerManager.DEFS[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(96, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = load(def.icon)
		b.expand_icon = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", UIKit.style(Color(0.08, 0.3, 0.15, 0.85), 24))
		b.add_theme_stylebox_override("hover", UIKit.style(Color(0.12, 0.4, 0.2, 0.9), 24))
		b.add_theme_stylebox_override("pressed", UIKit.style(Color(0.2, 0.55, 0.3, 0.95), 24))
		b.pressed.connect(_on_power_pressed.bind(id))
		bar.add_child(b)
		var badge := UIKit.label("", 24, UIKit.C_TEXT)
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_left = -50
		badge.offset_top = -40
		badge.offset_right = -6
		badge.offset_bottom = -2
		b.add_child(badge)
		power_buttons[id] = b
		power_badges[id] = badge
	_refresh_power_buttons()


func _refresh_hud() -> void:
	queue_redraw()  # score, stars, objective and timer are painted in _draw()


func _refresh_power_buttons() -> void:
	for id in PowerManager.ORDER:
		var b: Button = power_buttons[id]
		var badge: Label = power_badges[id]
		var reason := power.check(id)
		var count := CoinManager.power_count(id)
		if reason == "none":
			badge.text = "+"
			b.modulate = Color(1, 1, 1, 0.55)
		elif reason == "cooldown":
			badge.text = "%d" % int(power.cooldown[id])
			b.modulate = Color(1, 1, 1, 0.45)
		elif reason == "limit":
			badge.text = "0"
			b.modulate = Color(1, 1, 1, 0.35)
		else:
			badge.text = str(count)
			b.modulate = Color(1, 1, 1, 1)
		if armed_power == id:
			b.modulate = Color(1.5, 1.4, 0.9, 1)
			b.add_theme_stylebox_override("normal", UIKit.style(UIKit.C_ACCENT.darkened(0.3), 24, UIKit.C_ACCENT))
		else:
			b.add_theme_stylebox_override("normal", UIKit.style(Color(0.1, 0.05, 0.25, 0.8), 24))


func _toast(text: String, seconds: float = 2.0) -> void:
	if hud == null:
		return
	if _toast_label and is_instance_valid(_toast_label):
		_toast_label.queue_free()
	var l := UIKit.label(text, 26, UIKit.C_TEXT)
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_left = 60
	l.offset_right = -60
	l.offset_top = danger_y - 250.0
	l.offset_bottom = danger_y - 170.0
	hud.add_child(l)
	_toast_label = l
	var tw := l.create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


# ====================================================================== input
func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_debug_tools_enabled() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 and state != State.ENDED:
			_win()
		elif event.keycode == KEY_F2 and state != State.ENDED:
			_lose("danger")
	if overlay_open or state == State.ENDED or level.is_empty():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_index != -1 or state != State.AIMING:
				return
			var p: Vector2 = event.position
			if p.y < origin.y - 10.0 or p.y > vsize.y - float(insets.bottom) - 135.0:
				return
			touch_index = event.index
			press_pos = p
			swap_candidate = p.distance_to(shooter) < 80.0
			aiming = true
			_update_aim(p)
		elif event.index == touch_index:
			var p: Vector2 = event.position
			touch_index = -1
			var was_aiming := aiming
			aiming = false
			aim_preview = {}
			if not was_aiming or state != State.AIMING:
				queue_redraw()
				return
			if swap_candidate and p.distance_to(shooter) < 80.0 and press_pos.distance_to(p) < 30.0:
				_swap_bubbles()
			elif p.y <= vsize.y - float(insets.bottom) - 135.0:
				_fire(aim_dir)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == touch_index and aiming:
		_update_aim(event.position)


func _update_aim(p: Vector2) -> void:
	var d := p - shooter
	var a := atan2(-d.y, d.x)  # 0..PI is "upwards"
	a = clampf(a, MIN_ANGLE, PI - MIN_ANGLE)
	aim_dir = Vector2(cos(a), -sin(a))
	if cur_proj == BoardLogic.Proj.FIREBALL:
		aim_preview = logic.trace_fireball(shooter, aim_dir, _ol())
	else:
		aim_preview = logic.trace_shot(shooter, aim_dir, _ol())
	queue_redraw()


func _swap_bubbles() -> void:
	if cur_proj != BoardLogic.Proj.NORMAL:
		_toast("Fire your power-up first!")
		return
	var t := cur_color
	cur_color = next_color
	next_color = t
	AudioManager.play("click", 1.2)


# ====================================================================== firing
func _pick_color() -> int:
	var present := logic.colors_present(true)
	if present.is_empty():
		present = logic.colors_present(false)
	if present.is_empty():
		return 0
	return present[rng.randi_range(0, present.size() - 1)]


func _fallback_cell(pos: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for r in range(0, mini(BoardLogic.MAX_ROWS, 16)):
		for c in range(BoardLogic.row_cols(r)):
			var cell := Vector2i(c, r)
			if logic.grid.has(cell) or (r > 0 and not logic.has_neighbor_bubble(cell)):
				continue
			var d := BoardLogic.cell_center(cell, _ol()).distance_squared_to(pos)
			if d < best_d:
				best_d = d
				best = cell
	return best


func _fire(dir: Vector2) -> void:
	if state != State.AIMING:
		return
	proj_kind = cur_proj
	proj_color = cur_color
	var tr: Dictionary
	if proj_kind == BoardLogic.Proj.FIREBALL:
		tr = logic.trace_fireball(shooter, dir, _ol())
		proj_destroyed = tr.destroyed
		proj_cell = Vector2i(-1, -1)
	else:
		tr = logic.trace_shot(shooter, dir, _ol())
		proj_cell = logic.landing_cell(tr.end, _ol())
		if proj_cell == Vector2i(-1, -1):
			proj_cell = _fallback_cell(tr.end)
	shots_fired += 1
	power.tick_shot()
	if armed_power != "":
		if CoinManager.consume_power(armed_power):
			power.register_use(armed_power)
		armed_power = ""
	cur_proj = BoardLogic.Proj.NORMAL
	proj_points = tr.points
	proj_seg = 0
	proj_pos = proj_points[0]
	state = State.FLYING
	AudioManager.play("shoot")
	_refresh_hud()
	_refresh_power_buttons()


# ====================================================================== frame update
func _process(delta: float) -> void:
	if level.is_empty():
		return
	if not overlay_open and state != State.ENDED:
		_tick_timer(delta)
	if state == State.FLYING and not overlay_open:
		_move_projectile(delta)
	_update_effects(delta)
	if drop_vis < drop:
		drop_vis = minf(drop, drop_vis + 90.0 * delta)
	elif drop_vis > drop:
		drop_vis = maxf(drop, drop_vis - 240.0 * delta)
	if state == State.RESOLVING and not _effects_active() and absf(drop_vis - drop) < 0.5:
		_after_resolve()
	queue_redraw()


func _tick_timer(delta: float) -> void:
	if int(level.time_limit) <= 0:
		return
	if freeze_time > 0.0:
		freeze_time = maxf(0.0, freeze_time - delta)
	else:
		time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		if state == State.AIMING:
			_lose("time")
		else:
			_time_up_pending = true
	_refresh_hud_timer_only()


func _refresh_hud_timer_only() -> void:
	queue_redraw()


func _move_projectile(delta: float) -> void:
	var move := PROJECTILE_SPEED * delta
	while move > 0.0 and proj_seg < proj_points.size() - 1:
		var target := proj_points[proj_seg + 1]
		var to_t := target - proj_pos
		var dist := to_t.length()
		if dist <= move:
			proj_pos = target
			move -= dist
			proj_seg += 1
			if proj_seg < proj_points.size() - 1:
				AudioManager.play("bounce")
		else:
			proj_pos += to_t / dist * move
			move = 0.0
	if proj_seg >= proj_points.size() - 1:
		_on_projectile_landed()


# ====================================================================== resolution
func _on_projectile_landed() -> void:
	var res: Dictionary
	if proj_kind == BoardLogic.Proj.FIREBALL:
		res = logic.resolve_fireball(proj_destroyed)
	else:
		res = logic.resolve_landing(proj_cell, proj_kind, proj_color)
	state = State.RESOLVING
	_apply_result(res)


func _apply_result(res: Dictionary) -> void:
	var made_progress: bool = int(res.pop_count) + int(res.drop_count) + int(res.rescued) > 0
	combo = combo + 1 if made_progress else 0
	drop += descent_shot + (0.0 if made_progress else descent_miss)  # a little every shot, more after a miss
	var mult := 1.0 + 0.5 * float(mini(maxi(combo - 1, 0), 6))
	var gained := int(float(res.score) * mult)
	score += gained
	rescued += int(res.rescued)
	pops_total += int(res.pop_count) + int(res.drop_count)

	if res.cell != Vector2i(-1, -1):
		var impact := BoardLogic.cell_center(res.cell, Vector2.ZERO)
		var around: Array[Vector2i] = BoardLogic.neighbors(res.cell)
		for p in res.popped:
			around.append_array(BoardLogic.neighbors(p.cell))
		for nb in around:
			if logic.grid.has(nb):
				var away := BoardLogic.cell_center(nb, Vector2.ZERO) - impact
				wobbles[nb] = {"t": 0.0, "dir": away.normalized() if away.length() > 0.01 else Vector2.UP}
	var pc := int(res.pop_count)
	if pc >= 3:
		var word := "AWESOME!" if pc >= 10 else ("GREAT!" if pc >= 7 else ("NICE!" if pc >= 5 else ("COMBO x%d" % combo if combo >= 3 else "")))
		if word != "":
			fx_words.append({"s": word, "t": 0.0})
	if pc >= 8 or proj_kind != BoardLogic.Proj.NORMAL:
		shake = 0.25
	var delay := 0.0
	var centroid := Vector2.ZERO
	var n := 0
	for p in res.popped:
		var c := BoardLogic.cell_center(p.cell, _ov())
		fx_pops.append({"pos": c, "color": p.color, "kind": p.kind, "t": -delay, "special": false})
		_spawn_particles(c, int(p.color))
		centroid += c
		n += 1
		delay += 0.025
	for p in res.freed:
		var c := BoardLogic.cell_center(p.cell, _ov())
		fx_pops.append({"pos": c, "color": -1, "kind": p.kind, "t": -delay, "special": true})
		_spawn_particles(c, 1)
		fx_texts.append({"pos": c, "text": "Rescued!", "t": 0.0})
		delay += 0.04
	var dd := 0.12
	for p in res.dropped:
		var c := BoardLogic.cell_center(p.cell, _ov())
		fx_falls.append({"pos": c, "vel": Vector2(rng.randf_range(-90, 90), rng.randf_range(-260, -60)), "color": p.color, "kind": p.kind, "t": -dd})
		if p.kind == BoardLogic.Kind.RESCUE:
			fx_texts.append({"pos": c, "text": "Rescued!", "t": -dd})
		centroid += c
		n += 1
		dd += 0.02
	for cell in res.cracked:
		fx_flashes.append({"pos": BoardLogic.cell_center(cell, _ov()), "t": 0.0, "kind": "ice"})
	for cell in res.unlocked:
		fx_flashes.append({"pos": BoardLogic.cell_center(cell, _ov()), "t": 0.0, "kind": "unlock"})
	if res.landed:
		fx_flashes.append({"pos": BoardLogic.cell_center(res.cell, _ov()), "t": 0.0, "kind": "land"})

	if gained > 0:
		var at := centroid / float(maxi(n, 1)) if n > 0 else proj_pos
		var txt := "+%d" % gained
		if combo > 1:
			txt += "  x%.1f" % mult
		fx_texts.append({"pos": at, "text": txt, "t": 0.0})

	# sound / haptics
	match proj_kind:
		BoardLogic.Proj.BOMB:
			AudioManager.play("explosion")
			GameManager.vibrate(70)
		BoardLogic.Proj.LIGHTNING:
			AudioManager.play("lightning")
			GameManager.vibrate(50)
		BoardLogic.Proj.FIREBALL:
			AudioManager.play("fire")
			GameManager.vibrate(50)
		_:
			if int(res.pop_count) > 0:
				AudioManager.play("pop_big" if int(res.pop_count) >= 6 else _pop_name(), 0.97 + rng.randf() * 0.08)
				if combo > 1:
					AudioManager.play("chime_%d" % mini(combo - 2, 4))
				GameManager.vibrate(15 if int(res.pop_count) < 6 else 35)
			else:
				AudioManager.play("land")
	if int(res.drop_count) > 0:
		AudioManager.play("drop")
	_refresh_hud()


func _objective_met() -> bool:
	var obj: Dictionary = level.objective
	match str(obj.type):
		"clear":
			return logic.count_colored() == 0
		"score":
			return score >= int(obj.target)
		"rescue":
			return rescued >= int(obj.target)
	return false


func _after_resolve() -> void:
	state = State.AIMING
	if _objective_met():
		_win()
		return
	if _room_px() <= 0.0:
		_lose("danger")
		return
	if _time_up_pending or (int(level.time_limit) > 0 and time_left <= 0.0):
		_lose("time")
		return
	if logic.count_colored() == 0:
		_lose("empty")
		return
	cur_color = next_color
	var present := logic.colors_present(true)
	if not present.is_empty() and not present.has(cur_color):
		cur_color = _pick_color()
	next_color = _pick_color()
	if _room_px() < 150.0:
		AudioManager.play("click", 0.6)
		_toast("Danger! Clear bubbles before they reach the line", 2.2)
	_refresh_hud()
	_refresh_power_buttons()


# ====================================================================== powers
func _on_power_pressed(id: String) -> void:
	if overlay_open or state != State.AIMING:
		return
	var def: Dictionary = PowerManager.DEFS[id]
	var reason := power.check(id)
	if reason == "none":
		_offer_buy(id)
		return
	if reason == "limit":
		_toast("%s: limit reached for this level" % def.name)
		return
	if reason == "cooldown":
		_toast("%s recharging: %d more shot(s)" % [def.name, int(power.cooldown[id])])
		return
	if str(def.kind) == "shot":
		if armed_power == id:
			armed_power = ""
			cur_proj = BoardLogic.Proj.NORMAL
		else:
			armed_power = id
			cur_proj = int(def.proj)
			AudioManager.play("power")
			_toast("%s ready - aim and shoot!" % def.name, 1.6)
	elif id == "color_switch":
		var present := logic.colors_present(true)
		if present.size() < 2:
			_toast("No other colour on the board")
			return
		if not CoinManager.consume_power(id):
			return
		power.register_use(id)
		var idx := present.find(cur_color)
		cur_color = present[(idx + 1) % present.size()]
		AudioManager.play("power")
	elif id == "time_freeze":
		if int(level.time_limit) <= 0:
			_toast("Time Freeze only works on timed levels")
			return
		if not CoinManager.consume_power(id):
			return
		power.register_use(id)
		freeze_time = float(GameManager.config_get(["time_freeze_seconds"], 10.0))
		AudioManager.play("freeze")
	_refresh_hud()
	_refresh_power_buttons()


func _offer_buy(id: String) -> void:
	var def: Dictionary = PowerManager.DEFS[id]
	var price := CoinManager.power_price(id)
	var m := _open_overlay("Out of %s" % def.name, "buy")
	m.body.add_child(UIKit.icon(def.icon, Vector2(120, 120)))
	m.body.add_child(UIKit.label(str(def.desc), 26, UIKit.C_MUTED))
	var buy := m.add_button("Buy 1 for %d coins" % price, UIKit.C_TEAL, func() -> void:
		if CoinManager.buy_power(id):
			AudioManager.play("coin")
			_close_overlay()
			_refresh_power_buttons())
	buy.disabled = CoinManager.balance() < price
	if buy.disabled:
		m.body.add_child(UIKit.label("You have %d coins" % CoinManager.balance(), 24, UIKit.C_PINK))
	m.add_button("Cancel", UIKit.C_GRAY, _close_overlay)


# ====================================================================== overlays
func _open_overlay(title: String, kind: String) -> ModalPanel:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	overlay_open = true
	aiming = false
	touch_index = -1
	aim_preview = {}
	_overlay_kind = kind
	var key: String = TITLE_KEYS.get(kind, "")
	var shown := title if (key == "" or kind == "lose") else ""
	_overlay = ModalPanel.create(shown, self, 600.0, key)
	return _overlay


func _close_overlay() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.close()
	_overlay = null
	_overlay_kind = ""
	overlay_open = false


func _open_pause() -> void:
	if overlay_open or state == State.ENDED:
		return
	AudioManager.play("click")
	var m := _open_overlay("", "pause")
	m.add_button("Resume", UIKit.C_TEAL, _close_overlay)
	m.add_button("Restart", UIKit.C_BLUE, func() -> void: GameManager.start_level(int(level.id)))
	m.add_button("Level map", UIKit.C_GRAY, func() -> void: GameManager.go_to("level_map"))
	var snd := m.add_button("Sound: %s" % ("ON" if SaveManager.get_setting("sound") else "OFF"), UIKit.C_PANEL_LIGHT, func() -> void: pass)
	snd.pressed.connect(func() -> void:
		SaveManager.set_setting("sound", not SaveManager.get_setting("sound"))
		snd.text = "Sound: %s" % ("ON" if SaveManager.get_setting("sound") else "OFF"))
	var mus := m.add_button("Music: %s" % ("ON" if SaveManager.get_setting("music") else "OFF"), UIKit.C_PANEL_LIGHT, func() -> void: pass)
	mus.pressed.connect(func() -> void:
		SaveManager.set_setting("music", not SaveManager.get_setting("music"))
		AudioManager.apply_settings()
		mus.text = "Music: %s" % ("ON" if SaveManager.get_setting("music") else "OFF"))


func _show_error(text: String) -> void:
	var m := _open_overlay("Oops", "error")
	m.body.add_child(UIKit.label(text, 28))
	m.add_button("Back to map", UIKit.C_TEAL, func() -> void: GameManager.go_to("level_map"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if not level.is_empty() and state != State.ENDED and not overlay_open:
			_open_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _overlay_kind == "pause":
			_close_overlay()
		elif _overlay_kind == "":
			_open_pause()
		elif _overlay_kind == "buy":
			_close_overlay()


# ====================================================================== end of level
func _win() -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	var bonus := maxi(0, int(level.shots) - shots_fired) * END_BONUS_PER_SHOT
	var final_score := score + bonus
	var stars := LevelManager.star_rating(level, final_score)
	var first := SaveManager.record_win(int(level.id), stars, final_score)
	GameManager.last_won_level = int(level.id)
	SaveManager.data["stats"]["pops"] = int(SaveManager.data["stats"]["pops"]) + pops_total
	var coins: int = _econ("level_win_coins", 15) + stars * _econ("coins_per_star", 10)
	if first:
		coins += _econ("first_clear_bonus", 20)
	_last_win_coins = coins
	CoinManager.add(coins)
	RewardManager.check_achievements()
	AudioManager.play("win")
	GameManager.vibrate(80)
	await get_tree().create_timer(0.7).timeout
	_show_complete(final_score, bonus, stars, coins, first)


func _econ(key: String, default_value: int) -> int:
	return int(GameManager.config_get(["economy", key], default_value))


func _show_complete(final_score: int, bonus: int, stars: int, coins: int, first: bool) -> void:
	var m := _open_overlay("", "win")
	AdManager.show_banner("level_end")  # result screen = natural break, never over the board
	var row := UIKit.stars_row(0, 96.0)
	m.body.add_child(row)
	for i in range(stars):
		await get_tree().create_timer(0.35).timeout
		if not is_instance_valid(row):
			return
		(row.get_child(i) as TextureRect).texture = load("res://assets/ui/star_on.png")
		AudioManager.play("star", 1.0 + 0.15 * i)
	m.body.add_child(UIKit.label("Score %d" % final_score, 40))
	if bonus > 0:
		m.body.add_child(UIKit.label("Shot bonus +%d" % bonus, 24, UIKit.C_MUTED))
	var best := SaveManager.level_best(int(level.id))
	m.body.add_child(UIKit.label("Best %d   |   +%d coins%s" % [best, coins, "  (first clear!)" if first else ""], 26, UIKit.C_ACCENT))
	if bool(GameManager.config_get(["economy", "double_coins_enabled"], true)) and AdManager.is_rewarded_ready():
		var dbl := m.add_button("Watch a video: double coins (+%d)" % coins, UIKit.C_ACCENT, func() -> void: pass)
		dbl.pressed.connect(func() -> void:
			if AdManager.show_rewarded("double_coins"):
				_pending_reward = "double_coins"
				dbl.disabled = true)
	var next_id := int(level.id) + 1
	if LevelManager.has_level(next_id):
		m.add_button("Next level", UIKit.C_PINK, func() -> void:
			AdManager.try_show_interstitial(int(level.id), func() -> void: GameManager.start_level(next_id)))
	m.add_button("Replay", UIKit.C_BLUE, func() -> void:
		AdManager.try_show_interstitial(int(level.id), func() -> void: GameManager.start_level(int(level.id))))
	m.add_button("Level map", UIKit.C_GRAY, func() -> void:
		AdManager.try_show_interstitial(int(level.id), func() -> void: GameManager.go_to("level_map")))


func _lose(reason: String) -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	_pending_loss_reason = reason
	AudioManager.play("lose")
	await get_tree().create_timer(0.5).timeout
	_show_failed(reason)


func _show_failed(reason: String) -> void:
	var title := "The bubbles reached the line!"
	var offer := "clear 3 rows"
	match reason:
		"time":
			title = "Time's up!"
			offer = "+%d seconds" % int(TIME_CONTINUE_SECONDS)
		"empty":
			title = "No bubbles left to finish the goal"
			offer = ""
	var m := _open_overlay(title, "lose")
	AdManager.show_banner("level_end")
	m.body.add_child(UIKit.label(str(level.name), 28, UIKit.C_MUTED))
	if offer != "" and continues_used == 0:
		var cost := 80
		var coin_btn := m.add_button("Continue %s  -  %d coins" % [offer, cost], UIKit.C_ACCENT, func() -> void: pass)
		coin_btn.disabled = CoinManager.balance() < cost
		coin_btn.pressed.connect(func() -> void:
			if CoinManager.spend(cost):
				_grant_continue())
		if AdManager.is_rewarded_ready():
			var ad_btn := m.add_button("Watch a video: continue (%s)" % offer, UIKit.C_TEAL, func() -> void: pass)
			ad_btn.pressed.connect(func() -> void:
				if AdManager.show_rewarded("continue"):
					_pending_reward = "continue"
					ad_btn.disabled = true)
	m.add_button("Try again", UIKit.C_PINK, func() -> void:
		AdManager.try_show_interstitial(int(level.id), func() -> void: GameManager.start_level(int(level.id))))
	m.add_button("Level map", UIKit.C_GRAY, func() -> void:
		AdManager.try_show_interstitial(int(level.id), func() -> void: GameManager.go_to("level_map")))


func _grant_continue() -> void:
	continues_used += 1
	AdManager.hide_banner()
	_close_overlay()
	match _pending_loss_reason:
		"time":
			time_left = TIME_CONTINUE_SECONDS
			_time_up_pending = false
		"danger":
			drop = maxf(0.0, drop - 3.0 * ROW_H)
			var removed: Array = []
			var low := logic.lowest_row()
			for cell in logic.grid.keys():
				if cell.y > low - 3:
					removed.append(cell)
			var res := BoardLogic._new_result()
			for cell in removed:
				if logic.grid.has(cell):
					logic._remove(cell, res.popped)
			logic._after_removal(removed, res)
			for p in res.popped:
				var c := BoardLogic.cell_center(p.cell, _ov())
				fx_pops.append({"pos": c, "color": p.color, "kind": p.kind, "t": 0.0, "special": false})
			for p in res.dropped:
				fx_falls.append({"pos": BoardLogic.cell_center(p.cell, _ov()), "vel": Vector2(0, -100), "color": p.color, "kind": p.kind, "t": 0.0})
	_time_up_pending = false
	state = State.AIMING
	cur_color = _pick_color()
	next_color = _pick_color()
	_refresh_hud()
	_refresh_power_buttons()


func _on_rewarded_finished(placement: String, earned: bool) -> void:
	if _pending_reward == "" or placement != _pending_reward:
		return
	var kind := _pending_reward
	_pending_reward = ""
	if not earned:
		_toast("Watch the full video to get the reward")
		return
	if kind == "continue":
		_grant_continue()
	elif kind == "double_coins" and not coins_doubled:
		coins_doubled = true
		CoinManager.add(_last_win_coins)
		AudioManager.play("coin")
		_toast("Coins doubled! +%d" % _last_win_coins, 2.5)


# ====================================================================== effects
func _spawn_particles(pos: Vector2, color: int) -> void:
	var col := Color.WHITE
	if color >= 0:
		col = _color_of(color)
	for i in range(5):
		if fx_particles.size() >= MAX_PARTICLES:
			return
		var a := rng.randf() * TAU
		var sp := rng.randf_range(120.0, 360.0)
		fx_particles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * sp, "life": 0.0, "max": rng.randf_range(0.35, 0.6), "color": col, "size": rng.randf_range(4.0, 8.0)})


func _color_of(i: int) -> Color:
	var cols := [Color("ec1c32"), Color("ffcd00"), Color("1cc43c"), Color("1676ff"), Color("ac34ff"), Color("ff3ea8")]
	return cols[clampi(i, 0, cols.size() - 1)]


func _update_effects(delta: float) -> void:
	for e in fx_pops:
		e["t"] += delta
	fx_pops = fx_pops.filter(func(e: Dictionary) -> bool: return e["t"] < 0.28)
	for e in fx_falls:
		e["t"] += delta
		if e["t"] > 0.0:
			var fv: Vector2 = e["vel"]
			fv.y += 2600.0 * delta
			e["vel"] = fv
			e["pos"] = e["pos"] + fv * delta
	fx_falls = fx_falls.filter(func(e: Dictionary) -> bool: return e["t"] < 0.9 and e["pos"].y < vsize.y + 100.0)
	for e in fx_particles:
		e["life"] += delta
		var pv: Vector2 = e["vel"]
		e["pos"] = e["pos"] + pv * delta
		pv.y += 700.0 * delta
		e["vel"] = pv
	fx_particles = fx_particles.filter(func(e: Dictionary) -> bool: return e["life"] < e["max"])
	for e in fx_texts:
		e["t"] += delta
	fx_texts = fx_texts.filter(func(e: Dictionary) -> bool: return e["t"] < 1.0)
	for e in fx_flashes:
		e["t"] += delta
	for k in wobbles.keys():
		wobbles[k]["t"] += delta
		if float(wobbles[k]["t"]) > 0.5:
			wobbles.erase(k)
	for w in fx_words:
		w["t"] += delta
	fx_words = fx_words.filter(func(w: Dictionary) -> bool: return w["t"] < 1.1)
	shake = maxf(0.0, shake - delta)
	fx_flashes = fx_flashes.filter(func(e: Dictionary) -> bool: return e["t"] < 0.3)


func _pop_name() -> String:
	return ["pop", "pop_1", "pop_2", "pop_3"][rng.randi_range(0, 3)]


func _effects_active() -> bool:
	return not (fx_pops.is_empty() and fx_falls.is_empty())


# ====================================================================== drawing
func _draw() -> void:
	if tex_bg:
		var s := maxf(vsize.x / tex_bg.get_width(), vsize.y / tex_bg.get_height())
		var sz := Vector2(tex_bg.get_width(), tex_bg.get_height()) * s
		draw_texture_rect(tex_bg, Rect2((vsize - sz) / 2.0, sz), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, vsize), UIKit.C_BG)
	if level.is_empty():
		return
	_so = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * (shake / 0.25 * 7.0) if shake > 0.0 else Vector2.ZERO
	draw_set_transform(_so, 0.0, Vector2.ONE)
	var w := BoardLogic.board_width()
	_draw_bridge(w)
	# danger zone: glow + dashed line, pulsing when the bubbles are close
	var hot := _room_px() < 150.0
	var pa := 0.55 + 0.35 * sin(Time.get_ticks_msec() / 110.0) if hot else 0.4
	for i in range(4):
		draw_rect(Rect2(origin.x - 6.0, danger_y - 20.0 * float(i + 1), w + 12.0, 20.0), Color(1.0, 0.24, 0.35, (0.34 if hot else 0.12) * (1.0 - float(i) * 0.22)))
	var x := origin.x
	while x < origin.x + w:
		draw_line(Vector2(x, danger_y), Vector2(minf(x + 20.0, origin.x + w), danger_y), Color(1, 0.35, 0.42, pa), 4.0)
		x += 32.0
	# board
	for cell in logic.grid:
		var v: Vector2i = logic.grid[cell]
		var bpos := BoardLogic.cell_center(cell, _ov())
		var wb: Variant = wobbles.get(cell)
		if wb != null:
			bpos += (wb["dir"] as Vector2) * (exp(-float(wb["t"]) * 8.0) * sin(float(wb["t"]) * 36.0) * 8.0)
		_draw_cell_bubble(bpos, v.x, v.y, 1.0, 1.0)
	# the sinking ceiling bar (its lower edge is exactly where new bubbles attach)
	var cy0 := origin.y + drop_vis - 6.0
	draw_style_box(_style_ceiling, Rect2(origin.x - 10.0, cy0 - 26.0, w + 20.0, 32.0))
	for i in range(BoardLogic.COLS):
		if i % 2 == 0:
			draw_circle(Vector2(origin.x + R + float(i) * 2.0 * R + R, cy0 - 12.0), 5.0, Color(0.16, 0.08, 0.02, 0.55))
	# effects
	for e in fx_falls:
		if e["t"] > 0.0:
			_draw_cell_bubble(e["pos"], e["color"], e["kind"], 1.0, clampf(1.0 - e["t"] / 0.9, 0.0, 1.0))
		else:
			_draw_cell_bubble(e["pos"], e["color"], e["kind"], 1.0, 1.0)
	for e in fx_pops:
		if e["t"] < 0.0:
			_draw_cell_bubble(e["pos"], e["color"], e["kind"], 1.0, 1.0)
		else:
			var k: float = e["t"] / 0.28
			if e["special"]:
				draw_circle(e["pos"], R * (1.0 + 1.2 * k), Color(1, 0.9, 0.4, 0.5 * (1.0 - k)))
			else:
				_draw_cell_bubble(e["pos"], e["color"], e["kind"], 1.0 + 0.5 * k, 1.0 - k)
				draw_arc(e["pos"], R * (1.0 + 0.9 * k), 0.0, TAU, 28, Color(1, 1, 1, 0.7 * (1.0 - k)), 3.0)
	for e in fx_flashes:
		var k2: float = e["t"] / 0.3
		var col := Color(0.7, 0.95, 1.0, 0.8 * (1.0 - k2))
		if e["kind"] == "unlock":
			col = Color(1.0, 0.85, 0.3, 0.8 * (1.0 - k2))
		elif e["kind"] == "land":
			col = Color(1, 1, 1, 0.45 * (1.0 - k2))
		draw_arc(e["pos"], R * (0.9 + 0.7 * k2), 0.0, TAU, 28, col, 4.0)
	for e in fx_particles:
		var c: Color = e["color"]
		c.a = 1.0 - e["life"] / e["max"]
		draw_circle(e["pos"], e["size"] * c.a, c)
	# aim guide
	if aiming and not aim_preview.is_empty() and state == State.AIMING:
		_draw_aim_guide()
	# shooter
	_draw_shooter()
	if state == State.FLYING:
		_draw_projectile_bubble(proj_pos, proj_kind, proj_color)
		if proj_kind == BoardLogic.Proj.FIREBALL:
			draw_circle(proj_pos, R * 1.5, Color(1, 0.55, 0.1, 0.25))
	# floating texts
	for e in fx_texts:
		if e["t"] < 0.0:
			continue
		var a: float = 1.0 - float(e["t"]) / 1.0
		var p: Vector2 = e["pos"] + Vector2(0, -60.0 * e["t"])
		draw_string_outline(UIKit.font(), p - Vector2(100, 0), e["text"], HORIZONTAL_ALIGNMENT_CENTER, 200.0, 34, 8, Color(0, 0, 0, a * 0.7))
		draw_string(UIKit.font(), p - Vector2(100, 0), e["text"], HORIZONTAL_ALIGNMENT_CENTER, 200.0, 34, Color(1, 0.92, 0.45, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for fw in fx_words:
		var k := minf(1.0, float(fw["t"]) * 5.0)
		var fs := int(70.0 * (0.55 + 0.45 * k))
		var a := clampf((1.1 - float(fw["t"])) * 2.0, 0.0, 1.0)
		var wp := Vector2(0.0, origin.y + 350.0 - float(fw["t"]) * 40.0)
		draw_string_outline(UIKit.font(), wp, str(fw["s"]), HORIZONTAL_ALIGNMENT_CENTER, vsize.x, fs, 14, Color(0.04, 0.16, 0.47, a))
		draw_string(UIKit.font(), wp, str(fw["s"]), HORIZONTAL_ALIGNMENT_CENTER, vsize.x, fs, Color(1.0, 0.9, 0.4, a))
	_draw_hud_overlay()


func _draw_bridge(w: float) -> void:
	var x0 := origin.x - 14.0
	var y0 := origin.y - 30.0
	var bw := w + 28.0
	var bh := danger_y - origin.y + 64.0
	var y := y0
	var i := 0
	while y < y0 + bh:
		var ph := minf(46.0, y0 + bh - y)
		draw_rect(Rect2(x0, y, bw, ph), Color("c98a45") if i % 2 == 1 else Color("dba65e"))
		draw_rect(Rect2(x0, y, bw, 5.0), Color(1.0, 0.93, 0.75, 0.22))
		draw_rect(Rect2(x0, y + ph, bw, 6.0), Color(0.24, 0.11, 0.02, 0.6))
		var gy := y + 15.0
		draw_line(Vector2(x0 + 30.0 + float((i * 47) % 120), gy), Vector2(x0 + 250.0 + float((i * 61) % 160), gy + 2.0), Color(0.47, 0.27, 0.1, 0.38), 2.0)
		draw_circle(Vector2(x0 + 16.0, y + ph / 2.0), 3.2, Color(0.2, 0.1, 0.02, 0.7))
		draw_circle(Vector2(x0 + bw - 16.0, y + ph / 2.0), 3.2, Color(0.2, 0.1, 0.02, 0.7))
		y += 52.0
		i += 1
	draw_rect(Rect2(x0, y0, bw, bh), Color(0.16, 0.06, 0.0, 0.1))
	for rx in [x0 - 5.0, x0 + bw + 5.0]:
		draw_line(Vector2(rx, y0 - 8.0), Vector2(rx, y0 + bh + 8.0), Color("4a2a10"), 15.0)
		draw_line(Vector2(rx, y0 - 8.0), Vector2(rx, y0 + bh + 8.0), Color("ecd29a"), 9.0)
		for k in range(7):
			var py := y0 + float(k) * bh / 6.0
			draw_rect(Rect2(rx - 15.0, py - 26.0, 30.0, 52.0), Color("4a2a10"))
			draw_rect(Rect2(rx - 11.0, py - 22.0, 22.0, 22.0), Color("b9792f"))


func _draw_cell_bubble(pos: Vector2, color: int, kind: int, scale_f: float, alpha: float) -> void:
	var r := R * scale_f
	var rect := Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0)
	var mod := Color(1, 1, 1, alpha)
	if alpha > 0.0:
		draw_set_transform(pos + _so + Vector2(3.0, r * 0.78), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, r * 0.78, Color(0.01, 0.1, 0.32, 0.32 * alpha))
		draw_set_transform(_so, 0.0, Vector2.ONE)
	match kind:
		BoardLogic.Kind.NORMAL:
			draw_texture_rect(tex_bubble[color], rect, false, mod)
		BoardLogic.Kind.ICE:
			draw_texture_rect(tex_bubble[color], rect, false, mod)
			draw_texture_rect(tex_special["ice"], rect, false, mod)
		BoardLogic.Kind.STONE:
			draw_texture_rect(tex_special["stone"], rect, false, mod)
		BoardLogic.Kind.LOCKED:
			draw_texture_rect(tex_bubble[color], rect, false, Color(0.62, 0.62, 0.62, alpha))
			draw_texture_rect(tex_special["lock"], rect, false, mod)
		BoardLogic.Kind.RESCUE:
			draw_texture_rect(tex_special["critter"], rect, false, mod)


func _draw_projectile_bubble(pos: Vector2, kind: int, color: int, scale_f: float = 1.0) -> void:
	var r := R * scale_f
	var rect := Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0)
	match kind:
		BoardLogic.Proj.RAINBOW:
			draw_texture_rect(tex_special["rainbow"], rect, false)
		BoardLogic.Proj.BOMB:
			draw_texture_rect(tex_special["bomb"], rect, false)
		BoardLogic.Proj.LIGHTNING:
			draw_texture_rect(tex_special["lightning"], rect, false)
		BoardLogic.Proj.FIREBALL:
			draw_texture_rect(tex_special["fireball"], rect, false)
		_:
			draw_texture_rect(tex_bubble[clampi(color, 0, tex_bubble.size() - 1)], rect, false)


func _sticker(text: String, centre: Vector2, font_px: int, color: Color, width: float = 220.0, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var x := centre.x - width / 2.0
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		x = centre.x - width
	elif align == HORIZONTAL_ALIGNMENT_LEFT:
		x = centre.x
	var p := Vector2(x, centre.y + float(font_px) * 0.35)
	draw_string_outline(UIKit.font(), p, text, align, width, font_px, maxi(5, font_px / 3), Color("0d3b1c"))
	draw_string(UIKit.font(), p, text, align, width, font_px, color)


func _draw_shooter() -> void:
	var angle := atan2(aim_dir.y, aim_dir.x)
	draw_set_transform(shooter + _so, angle + PI / 2.0, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -R * 2.3), Vector2(16, -R * 1.45), Vector2(-16, -R * 1.45)]), Color(1, 1, 1, 0.92))
	draw_set_transform(_so, 0.0, Vector2.ONE)
	draw_circle(shooter, R * 1.6, Color(1, 1, 1, 0.22))
	draw_arc(shooter, R * 1.6, 0.0, TAU, 40, Color(1, 1, 1, 1.0), 6.0)
	draw_circle(shooter, R * 1.2, Color(0.04, 0.24, 0.11, 0.35))
	if state == State.AIMING:
		_draw_projectile_bubble(shooter, cur_proj, cur_color)
	var rows := maxi(0, int(floor(_room_px() / ROW_H)))
	var bc := shooter + Vector2(-128, 0)
	draw_circle(bc, 32.0, Color(0.78, 0.12, 0.23) if rows <= 2 else Color(0.06, 0.3, 0.14))
	draw_arc(bc, 32.0, 0.0, TAU, 28, Color(1, 1, 1, 1.0), 4.0)
	_sticker(str(rows), bc + Vector2(0, -2), 30, Color.WHITE, 60.0)
	_sticker("ROWS", bc + Vector2(0, 46), 15, Color.WHITE, 90.0)
	draw_texture_rect(tex_swap, Rect2(shooter + Vector2(66, -24), Vector2(44, 44)), false, Color(1, 1, 1, 0.95))
	_draw_projectile_bubble(shooter + Vector2(140, 0), BoardLogic.Proj.NORMAL, next_color, 0.7)
	_sticker("NEXT", shooter + Vector2(140, 46), 15, Color.WHITE, 90.0)


## Star progress bar, score, level/objective line and timer (same arrangement as the reference game).
func _draw_hud_overlay() -> void:
	var top := float(insets.top)
	var bar := Rect2(122.0, top + 28.0, 372.0, 40.0)
	draw_style_box(_style_bar, bar)
	var s0 := float(level.star_scores[0])
	var s1 := float(level.star_scores[1])
	var fr := clampf(float(score) / s1, 0.0, 1.0)
	if fr > 0.0:
		draw_style_box(_style_bar_fill, Rect2(bar.position + Vector2(4, 4), Vector2((bar.size.x - 8.0) * fr, bar.size.y - 8.0)))
	for t in [[0.6 * s0, 0.6 * s0 / s1], [s0, s0 / s1], [s1, 1.0]]:
		var sx := bar.position.x + bar.size.x * minf(float(t[1]), 0.98) - 8.0
		var tex: Texture2D = tex_star_on if float(score) >= float(t[0]) else tex_star_off
		draw_texture_rect(tex, Rect2(sx - 22.0, bar.position.y - 9.0, 52.0, 52.0), false)
	_sticker(str(score), Vector2(698.0, top + 50.0), 42, Color.WHITE, 260.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_sticker("LEVEL %d%s" % [int(level.id), "  BOSS" if level.boss else ""], Vector2(30.0, top + 118.0), 22, Color("ffe27a"), 220.0, HORIZONTAL_ALIGNMENT_LEFT)
	var obj: Dictionary = level.objective
	var info := ""
	match str(obj.type):
		"clear":
			info = "Clear all: %d left" % logic.count_colored()
		"score":
			info = "Reach %d pts" % int(obj.target)
		"rescue":
			info = "Rescue %d / %d" % [rescued, int(obj.target)]
	_sticker(info, Vector2(360.0, top + 118.0), 21, Color.WHITE, 300.0)
	if int(level.time_limit) > 0:
		var t := maxi(0, int(ceil(time_left)))
		_sticker("%d:%02d%s" % [t / 60, t % 60, " FROZEN" if freeze_time > 0.0 else ""], Vector2(698.0, top + 118.0), 22, Color("9fe6ff") if freeze_time > 0.0 else (Color("ff9fb4") if t <= 10 else Color("ffe27a")), 260.0, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_sticker("SHOTS %d" % shots_fired, Vector2(698.0, top + 118.0), 19, Color("d8ffd8"), 260.0, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_aim_guide() -> void:
	var pts: PackedVector2Array = aim_preview.points
	var travelled := 0.0
	var next_dot := 20.0
	var di := 0
	var dot_col := _color_of(cur_color) if cur_proj == BoardLogic.Proj.NORMAL else Color.WHITE
	for i in range(pts.size() - 1):
		var a := pts[i]
		var seg := pts[i + 1] - a
		var length := seg.length()
		if length < 0.001:
			continue
		var dir := seg / length
		while next_dot <= travelled + length:
			var rr := maxf(3.2, 8.5 - float(di) * 0.11)
			var dp := a + dir * (next_dot - travelled)
			draw_circle(dp, rr + 2.0, Color(1, 1, 1, 0.9))
			draw_circle(dp, rr, dot_col)
			next_dot += 27.0
			di += 1
		travelled += length
	if aim_preview.has("hit_ceiling") or aim_preview.has("end"):
		var end: Vector2 = aim_preview.end
		if cur_proj != BoardLogic.Proj.FIREBALL:
			var cell := logic.landing_cell(end, _ol())
			if cell != Vector2i(-1, -1):
				draw_arc(BoardLogic.cell_center(cell, _ol()), R * 0.92, 0.0, TAU, 32, Color(1, 1, 1, 0.55), 3.0)
		else:
			for c in aim_preview.destroyed:
				draw_arc(BoardLogic.cell_center(c, _ol()), R * 0.95, 0.0, TAU, 32, Color(1, 0.6, 0.2, 0.8), 4.0)
