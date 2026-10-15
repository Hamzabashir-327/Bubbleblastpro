extends Screen

var _coin_label_host: Control
var _rows: VBoxContainer
var _free_btn: Button
var _status: Label


func _ready() -> void:
	banner_key = "shop"
	var vb := setup_layout(1, true)
	vb.add_child(header("Shop", true, "shop"))
	_free_btn = UIKit.button("", UIKit.C_ACCENT, Vector2(0, 96), 30)
	_free_btn.pressed.connect(_on_free_coins)
	vb.add_child(_free_btn)
	_status = UIKit.label("", 24, UIKit.C_MUTED)
	vb.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 14)
	scroll.add_child(_rows)
	CoinManager.powers_changed.connect(_refresh)
	CoinManager.coins_changed.connect(func(_t: int) -> void: _refresh())
	AdManager.rewarded_finished.connect(_on_rewarded_finished)
	AdManager.availability_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in _rows.get_children():
		c.queue_free()
	for id in PowerManager.ORDER:
		_rows.add_child(_power_row(id))
	var left := RewardManager.rewarded_coins_left_today()
	var bonus := int(GameManager.config_get(["economy", "rewarded_coin_bonus"], 50))
	_free_btn.text = "Watch a video: +%d coins  (%d left today)" % [bonus, left]
	_free_btn.disabled = left <= 0 or not AdManager.is_rewarded_ready()
	if left > 0 and not AdManager.is_rewarded_ready():
		_status.text = "No video available right now. Please try again later."
	else:
		_status.text = ""


func _power_row(id: String) -> Control:
	var def: Dictionary = PowerManager.DEFS[id]
	var panel := UIKit.panel(UIKit.C_PANEL, 28)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	panel.add_child(hb)
	hb.add_child(UIKit.icon(def.icon, Vector2(96, 96)))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label("%s   x%d" % [def.name, CoinManager.power_count(id)], 30, UIKit.C_ACCENT, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(UIKit.label(def.desc, 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	hb.add_child(info)
	var price := CoinManager.power_price(id)
	var buy := UIKit.button("%d" % price, UIKit.C_TEAL, Vector2(150, 96), 32)
	buy.disabled = CoinManager.balance() < price
	buy.pressed.connect(func() -> void:
		if CoinManager.buy_power(id):
			AudioManager.play("coin"))
	hb.add_child(buy)
	return panel


func _on_free_coins() -> void:
	if RewardManager.rewarded_coins_left_today() <= 0:
		return
	if not AdManager.show_rewarded("shop_coins"):
		_status.text = "No video available right now."
		return
	_free_btn.disabled = true


func _on_rewarded_finished(placement: String, earned: bool) -> void:
	if placement != "shop_coins":
		return
	if earned:
		CoinManager.add(int(GameManager.config_get(["economy", "rewarded_coin_bonus"], 50)))
		RewardManager.note_rewarded_coin_claim()
		AudioManager.play("coin")
	else:
		_status.text = "Watch the whole video to get the reward."
	_refresh()


func _exit_tree() -> void:
	if AdManager.rewarded_finished.is_connected(_on_rewarded_finished):
		AdManager.rewarded_finished.disconnect(_on_rewarded_finished)
	if AdManager.availability_changed.is_connected(_refresh):
		AdManager.availability_changed.disconnect(_refresh)


func on_back() -> void:
	GameManager.go_to("main_menu")
