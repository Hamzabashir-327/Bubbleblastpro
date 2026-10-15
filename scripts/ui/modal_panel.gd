class_name ModalPanel
extends Control
## Full-screen dimmer + centred card. Swallows all input underneath so nothing
## behind a popup can be tapped (also blocks accidental shots).

signal closed

var body: VBoxContainer
var _closing := false


static func create(title: String, parent: Node, width: float = 600.0, title_key: String = "") -> ModalPanel:
	var m := ModalPanel.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	m.z_index = 100
	parent.add_child(m)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.07, 0.27, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	m.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(center)
	var card := UIKit.panel(UIKit.C_PANEL_LIGHT, 36)
	card.custom_minimum_size = Vector2(width, 0)
	center.add_child(card)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	card.add_child(margin)
	m.body = VBoxContainer.new()
	m.body.add_theme_constant_override("separation", 16)
	margin.add_child(m.body)
	if title_key != "":
		m.body.add_child(UIKit.title_image(title_key, title, 84.0))
		if title != "":
			m.body.add_child(UIKit.label(title, 28, UIKit.C_MUTED))
	elif title != "":
		m.body.add_child(UIKit.label(title, 52, UIKit.C_ACCENT))
	m.modulate.a = 0.0
	var tw := m.create_tween()
	tw.tween_property(m, "modulate:a", 1.0, 0.15)
	return m


func add_button(text: String, color: Color, callback: Callable, min_size: Vector2 = Vector2(0, 96)) -> Button:
	var b := UIKit.button(text, color, min_size)
	b.pressed.connect(func() -> void:
		AudioManager.play("click")
		callback.call())
	body.add_child(b)
	return b


func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	queue_free()
