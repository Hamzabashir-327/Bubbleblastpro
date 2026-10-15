class_name BubbleBackdrop
extends Control
## Gently rising, swaying glossy bubbles drawn over a menu background. Cheap (16 sprites),
## purely decorative, ignores all input.

var _bubbles: Array = []
var _tex: Array[Texture2D] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in range(BoardLogic.NUM_COLORS):
		_tex.append(load("res://assets/bubbles/bubble_%d.png" % i))
	_rng.seed = 7
	for i in range(16):
		_bubbles.append({
			"x": _rng.randf(), "y": _rng.randf(), "r": _rng.randf_range(22.0, 66.0),
			"speed": _rng.randf_range(0.02, 0.055), "phase": _rng.randf() * TAU,
			"sway": _rng.randf_range(10.0, 36.0), "c": _rng.randi_range(0, BoardLogic.NUM_COLORS - 1),
			"a": _rng.randf_range(0.22, 0.55),
		})


func _process(delta: float) -> void:
	_t += delta
	for b in _bubbles:
		b["y"] = float(b["y"]) - float(b["speed"]) * delta
		if float(b["y"]) < -0.12:
			b["y"] = 1.12
			b["x"] = _rng.randf()
	queue_redraw()


func _draw() -> void:
	var s := size
	for b in _bubbles:
		var r: float = b["r"]
		var x: float = float(b["x"]) * s.x + sin(_t * 0.8 + float(b["phase"])) * float(b["sway"])
		var y: float = float(b["y"]) * s.y
		draw_texture_rect(_tex[int(b["c"])], Rect2(x - r, y - r, r * 2.0, r * 2.0), false, Color(1, 1, 1, float(b["a"])))
