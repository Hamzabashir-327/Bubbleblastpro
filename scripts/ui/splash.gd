extends Screen
## 5-second loading screen: bouncing logo, animated bubbles, progress bar with rotating tips,
## "Powered by Hamza". AdManager (consent + SDK) starts here so it is ready by the menu.

const LOAD_SECONDS := 5.0
const TIPS := [
	"Mixing magic bubbles...",
	"Polishing the stars...",
	"Loading 30 mystic levels...",
	"Warming up the bubble cannon...",
	"Almost ready - get set to pop!",
]

var _bar: ProgressBar
var _tip: Label
var _done := false


func _ready() -> void:
	var vb := setup_layout(1, false)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER

	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.custom_minimum_size = Vector2(640, 380)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(logo)
	UIKit.pop_in(logo, 0.1)
	UIKit.sway(logo, 1.6)

	vb.add_child(UIKit.spacer(40))

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(560, 34)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	var bg := UIKit.style(Color(0.02, 0.12, 0.42, 0.8), 18, Color(1, 1, 1, 1))
	bg.shadow_size = 0
	var fill := UIKit.style(UIKit.C_ORANGE, 18, Color("fff0a8"))
	fill.shadow_size = 0
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	vb.add_child(_bar)

	_tip = UIKit.label(TIPS[0], 28, UIKit.C_MUTED)
	vb.add_child(_tip)

	var foot := Control.new()
	foot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(foot)
	var by := UIKit.powered_by(560.0)
	vb.add_child(by)
	UIKit.pop_in(by, 0.8)

	var tw := create_tween()
	tw.tween_property(_bar, "value", 100.0, LOAD_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_finish)
	var tip_tw := create_tween()
	for i in range(1, TIPS.size()):
		tip_tw.tween_interval(LOAD_SECONDS / TIPS.size())
		tip_tw.tween_callback(_set_tip.bind(i))
	AdManager.start()


func _set_tip(i: int) -> void:
	if is_instance_valid(_tip):
		_tip.text = TIPS[i]


func _finish() -> void:
	if _done:
		return
	_done = true
	GameManager.go_to("main_menu")


func on_back() -> void:
	pass  # loading can't be cancelled
