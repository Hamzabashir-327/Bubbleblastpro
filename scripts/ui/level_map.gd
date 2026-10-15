extends Screen
## Level map: a winding sandy road over the three worlds (level 1 at the bottom).
## Completed stretch turns green; a marker bobs above the current level and, right after a win,
## hops along the road to the next level. Tap an open level to play it.

const MAP_W := 600.0
const GAP := 128.0
const MARG := 170.0
const WORLD_NAMES := ["Green Jungle", "Autumn Canopy", "Glow Forest"]

var _scroll: ScrollContainer
var _canvas: MapCanvas
var _marker: TextureRect
var _bob: Tween
var _scale := 1.0
var _count := 30
var _pts: Array[Vector2] = []
var _node_px := 123.0


func _ready() -> void:
	banner_key = "level_map"
	var vb := setup_layout(1, true)
	vb.add_child(header("Select Level", true, "select_level"))
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 1, 1, 1)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 6)
	frame.add_theme_stylebox_override("panel", sb)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(frame)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.clip_contents = true
	frame.add_child(_scroll)

	_count = LevelManager.level_count
	var unlocked := mini(int(SaveManager.data["unlocked_level"]), _count)
	var from := GameManager.last_won_level
	GameManager.last_won_level = 0
	var width := 636.0
	_scale = width / MAP_W
	_node_px = 0.19 * width
	_canvas = MapCanvas.new()
	_canvas.custom_minimum_size = Vector2(width, (float(_count) * GAP + MARG * 2.0) * _scale)
	_scroll.add_child(_canvas)
	for i in range(1, _count + 1):
		_pts.append(_node_pos(i))
	_canvas.points = _pts
	_canvas.reached = unlocked
	_canvas.scale_f = _scale
	for wi in range(3):
		var lv := 1 + wi * 10
		if lv <= _count:
			_add_world_tag(wi, _pts[lv - 1])
	for i in range(1, _count + 1):
		_add_node(i, unlocked)
	var start_at := clampi(from if from > 0 else unlocked, 1, _count)
	_marker = TextureRect.new()
	_marker.texture = load("res://assets/ui/marker.png")
	_marker.custom_minimum_size = Vector2(72, 72)
	_marker.size = Vector2(72, 72)
	_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.z_index = 5
	_canvas.add_child(_marker)
	_marker.position = _marker_home(start_at)
	_start_bob()
	await get_tree().process_frame
	_scroll.scroll_vertical = int(maxf(0.0, _pts[start_at - 1].y - _scroll.size.y * 0.55))
	if from > 0 and unlocked > from:
		await get_tree().create_timer(0.65).timeout
		_hop_to(unlocked)


func _node_pos(i: int) -> Vector2:
	return Vector2(300.0 + sin(float(i) * 0.9) * 180.0, float(_count) * GAP + MARG * 2.0 - MARG - float(i - 1) * GAP) * _scale


func _marker_home(level: int) -> Vector2:
	var node_size := _node_px * (1.2 if _is_boss(level) else 1.0)
	return _pts[level - 1] - Vector2(36.0, node_size * 0.5 + 66.0)


func _is_boss(level: int) -> bool:
	var r := LevelManager.get_level(level)
	return r.ok and bool(r.level.boss)


func _add_world_tag(world_index: int, near: Vector2) -> void:
	var tag := UIKit.panel(Color(0.08, 0.35, 0.16, 0.88), 30)
	tag.add_child(UIKit.label("WORLD %d  -  %s" % [world_index + 1, WORLD_NAMES[world_index]], 20))
	tag.position = Vector2(14.0, near.y + GAP * _scale * 0.62)
	_canvas.add_child(tag)


func _add_node(level: int, unlocked: int) -> void:
	var boss := _is_boss(level)
	var locked := level > unlocked
	var stars := SaveManager.level_stars(level)
	var current := level == unlocked and stars == 0
	var tex_name := "node_locked" if locked else ("node_boss" if boss else ("node_done" if stars > 0 else "node_open"))
	var sz := _node_px * (1.2 if boss else 1.0)
	var centre := _pts[level - 1]
	if current:
		var halo := TextureRect.new()
		halo.texture = load("res://assets/ui/node_halo.png")
		halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		halo.size = Vector2(sz * 1.9, sz * 1.9)
		halo.position = centre - halo.size / 2.0
		halo.pivot_offset = halo.size / 2.0
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(halo)
		var ht := halo.create_tween().set_loops()
		ht.tween_property(halo, "scale", Vector2(1.15, 1.15), 0.8).set_trans(Tween.TRANS_SINE)
		ht.tween_property(halo, "scale", Vector2(0.92, 0.92), 0.8).set_trans(Tween.TRANS_SINE)
	var b := TextureButton.new()
	b.texture_normal = load("res://assets/ui/%s.png" % tex_name)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.size = Vector2(sz, sz)
	b.position = centre - b.size / 2.0
	b.pivot_offset = b.size / 2.0
	b.disabled = locked
	b.focus_mode = Control.FOCUS_NONE
	_canvas.add_child(b)
	if not locked:
		b.button_down.connect(func() -> void:
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2(0.92, 0.92), 0.07))
		b.button_up.connect(func() -> void:
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2.ONE, 0.1))
		b.pressed.connect(func() -> void:
			AudioManager.play("click")
			GameManager.start_level(level))
		if not boss:
			var num := UIKit.label(str(level), 40)
			num.size = Vector2(sz, 56)
			num.position = Vector2(0.0, sz * 0.2)
			b.add_child(num)
		if stars > 0:
			var row := UIKit.stars_row(stars, 30.0)
			row.size = Vector2(sz, 34)
			row.position = Vector2(0.0, sz - 10.0)
			b.add_child(row)
	if current:
		var pt := b.create_tween().set_loops()
		pt.tween_property(b, "scale", Vector2(1.07, 1.07), 0.65).set_trans(Tween.TRANS_SINE)
		pt.tween_property(b, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_SINE)


func _start_bob() -> void:
	if _bob and _bob.is_valid():
		_bob.kill()
	_bob = _marker.create_tween().set_loops()
	var base := _marker.position
	_bob.tween_property(_marker, "position:y", base.y - 12.0, 0.55).set_trans(Tween.TRANS_SINE)
	_bob.tween_property(_marker, "position:y", base.y, 0.55).set_trans(Tween.TRANS_SINE)


func _hop_to(level: int) -> void:
	if _bob and _bob.is_valid():
		_bob.kill()
	AudioManager.play("click")
	var target := _marker_home(level)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_marker, "position", target, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_scroll, "scroll_vertical", int(maxf(0.0, _pts[level - 1].y - _scroll.size.y * 0.55)), 0.9).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	AudioManager.play("star")
	_start_bob()


func on_back() -> void:
	GameManager.go_to("main_menu")


## Draws the three jungle worlds (level 1 at the bottom) and the wooden bridge road.
class MapCanvas:
	extends Control
	var points: Array[Vector2] = []
	var reached := 1
	var scale_f := 1.0
	var _bgs: Array[Texture2D] = []

	func _ready() -> void:
		for i in range(1, 4):
			_bgs.append(load("res://assets/backgrounds/world_%d.png" % i))

	func _sample(pts: Array[Vector2]) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in range(pts.size() - 1):
			var p0 := pts[maxi(i - 1, 0)]
			var p1 := pts[i]
			var p2 := pts[i + 1]
			var p3 := pts[mini(i + 2, pts.size() - 1)]
			for s in range(12):
				out.append(p1.cubic_interpolate(p2, p0, p3, float(s) / 12.0))
		out.append(pts[pts.size() - 1])
		return out

	func _planks(path: PackedVector2Array, color: Color) -> void:
		for i in range(1, path.size() - 1, 3):
			var d := (path[i + 1] - path[i - 1]).normalized()
			var n := Vector2(-d.y, d.x) * 22.0 * scale_f
			draw_line(path[i] - n, path[i] + n, color, 3.0)

	func _draw() -> void:
		if _bgs.size() == 3:
			var h3 := size.y * 0.335
			draw_texture_rect(_bgs[0], Rect2(0, size.y - size.y * 0.34, size.x, size.y * 0.34), false)
			draw_texture_rect(_bgs[1], Rect2(0, size.y - size.y * 0.675, size.x, size.y * 0.335), false)
			draw_texture_rect(_bgs[2], Rect2(0, 0, size.x, h3), false)
		if points.size() < 2:
			return
		var path := _sample(points)
		var shifted := PackedVector2Array()
		for p in path:
			shifted.append(p + Vector2(0, 8.0 * scale_f))
		draw_polyline(shifted, Color(0, 0.1, 0.02, 0.38), 66.0 * scale_f, true)
		draw_polyline(path, Color("5a3414"), 58.0 * scale_f, true)
		draw_polyline(path, Color("e8c98a"), 52.0 * scale_f, true)
		draw_polyline(path, Color("c98a45"), 44.0 * scale_f, true)
		_planks(path, Color("8a5526"))
		var done: Array[Vector2] = []
		for i in range(mini(reached, points.size())):
			done.append(points[i])
		if done.size() > 1:
			var dpath := _sample(done)
			draw_polyline(dpath, Color(1.0, 0.93, 0.59, 0.55), 44.0 * scale_f, true)
			_planks(dpath, Color("a8691f"))
