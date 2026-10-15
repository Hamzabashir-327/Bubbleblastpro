extends Node
## Single entry point for all ads. Screens never talk to the SDK directly.
##
## Safety rules implemented here:
##  * Debug builds ALWAYS use Google's public test IDs; production IDs are used only in a
##    release build with test_mode=false AND real (non placeholder) IDs.
##  * Consent (UMP) runs before the SDK is initialised; no consent -> no ad requests.
##  * Ads never block the game: every failure just means "no ad".
##  * Interstitials only at natural breaks, with frequency caps. Rewarded ads are
##    opt-in only; the reward is granted exactly once, only after the SDK confirms it.

signal rewarded_finished(placement: String, earned: bool)
signal availability_changed

const CONFIG_PATH := "res://data/config/ads_config.json"
const BACKEND_POING := "res://scripts/ads/ad_backend_poing.gd"
const BACKEND_STUB := "res://scripts/ads/ad_backend_stub.gd"
const GOOGLE_TEST_APP_PREFIX := "ca-app-pub-3940256099942544"

var config: Dictionary = {}
var enabled := false
var test_mode := true
var ids: Dictionary = {}
var backend: RefCounted
var backend_name := "stub"
var sdk_ready := false
var can_request_ads := false
var privacy_options_required := false
var status_text := "not started"

var _started := false
var _banner_key := ""
var _banner_loaded := false
var _banner_loading := false
var _banner_fail_count := 0
var _inter_loading := false
var _inter_fail_count := 0
var _rew_loading := false
var _rew_fail_count := 0
var _breaks := 0
var _last_inter_time := -100000.0
var _session_inters := 0
var _rewarded_busy := false
var _reward_earned := false
var _rewarded_placement := ""
var _inter_done: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()


func _load_config() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text()) if f else null
	config = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	enabled = bool(config.get("enabled", false))
	test_mode = bool(config.get("test_mode", true)) or OS.is_debug_build()
	var block: Dictionary = config.get("test" if test_mode else "production", {})
	ids = block.duplicate()
	if not test_mode:
		# refuse to run production ads with placeholder IDs
		for k in ["app_id", "banner", "interstitial", "rewarded"]:
			var v := str(ids.get(k, ""))
			if v == "" or v.begins_with("OWNER_PROVIDED") or v.begins_with(GOOGLE_TEST_APP_PREFIX):
				push_warning("AdMob production ID '%s' not set - ads disabled in this build" % k)
				enabled = false
	if config.is_empty():
		enabled = false


## Called once from the splash screen.
func start() -> void:
	if _started:
		return
	_started = true
	if not enabled:
		status_text = "ads disabled by config"
		backend = load(BACKEND_STUB).new()
		return
	backend = null
	if OS.get_name() == "Android":
		# If the plugin is missing, this script does not compile and can_instantiate() is false.
		var script: Variant = load(BACKEND_POING)
		if script is GDScript and script.can_instantiate():
			backend = script.new()
			backend_name = "poing-admob"
		else:
			push_warning("AdMob plugin missing or its API differs from ad_backend_poing.gd - see docs/ADMOB_SETUP.md")
	if backend == null:
		backend = load(BACKEND_STUB).new()
		status_text = "ads unavailable (plugin missing or not Android)"
		return
	status_text = "requesting consent"
	backend.request_consent(_on_consent_done)


func _on_consent_done(can_request: bool, options_required: bool) -> void:
	can_request_ads = can_request
	privacy_options_required = options_required
	if not can_request:
		status_text = "no consent - ads off"
		availability_changed.emit()
		return
	status_text = "initialising SDK"
	backend.initialize(_on_sdk_ready)


func _on_sdk_ready(ok: bool) -> void:
	sdk_ready = ok
	status_text = "ready (%s IDs)" % ("TEST" if test_mode else "PRODUCTION") if ok else "SDK init failed"
	if not ok:
		return
	if bool(config.get("interstitial", {}).get("preload", true)):
		_load_interstitial()
	_load_rewarded()
	if _banner_key != "":
		_load_banner()
	availability_changed.emit()


func show_privacy_options() -> void:
	if backend and privacy_options_required:
		backend.show_privacy_options(func(_ok: bool) -> void: pass)


# ------------------------------------------------------------------ banner
## Height to keep free at the bottom of banner screens (viewport pixels).
func banner_reserve_px() -> int:
	return 110 if enabled else 0


func show_banner(screen_key: String) -> void:
	var allowed: Array = config.get("banner", {}).get("screens", [])
	if not enabled or not allowed.has(screen_key):
		hide_banner()
		return
	_banner_key = screen_key
	if not sdk_ready or backend == null:
		return
	if not _banner_loaded and not _banner_loading:
		_load_banner()


func hide_banner() -> void:
	_banner_key = ""
	if backend and sdk_ready and (_banner_loaded or _banner_loading):
		backend.destroy_banner()
	_banner_loaded = false
	_banner_loading = false


func _load_banner() -> void:
	_banner_loading = true
	backend.show_banner(str(ids.get("banner", "")), _on_banner_loaded, _on_banner_failed)


func _on_banner_loaded() -> void:
	_banner_loading = false
	_banner_loaded = true
	_banner_fail_count = 0
	if _banner_key == "":
		hide_banner()  # the player already left the screen that wanted a banner


func _on_banner_failed(err: String) -> void:
	_banner_loading = false
	_banner_loaded = false
	push_warning("Banner failed: %s" % err)
	_retry_later(config.get("banner", {}).get("retry_backoff_seconds", [30]), _banner_fail_count, _retry_banner)
	_banner_fail_count += 1


func _retry_banner() -> void:
	if _banner_key != "" and not _banner_loaded and not _banner_loading:
		_load_banner()


# ------------------------------------------------------------------ interstitial
## Call after every natural break (level finished). The callback ALWAYS runs
## exactly once - after the ad closes, or immediately if no ad is shown.
func try_show_interstitial(level_id: int, done: Callable) -> void:
	_breaks += 1
	var cfg: Dictionary = config.get("interstitial", {})
	var now := Time.get_ticks_msec() / 1000.0
	var ok: bool = enabled and sdk_ready and backend != null and backend.is_interstitial_ready() \
		and level_id >= int(cfg.get("first_allowed_level", 4)) \
		and _breaks >= int(cfg.get("every_n_breaks", 3)) \
		and now - _last_inter_time >= float(cfg.get("min_interval_seconds", 120)) \
		and _session_inters < int(cfg.get("max_per_session", 8))
	if not ok:
		done.call()
		return
	_breaks = 0
	_last_inter_time = now
	_session_inters += 1
	_inter_done = done
	backend.show_interstitial(_on_inter_closed)


func _on_inter_closed() -> void:
	var cb := _inter_done
	_inter_done = Callable()
	_load_interstitial()
	if cb.is_valid():
		cb.call()  # runs once: _inter_done was cleared above


func _load_interstitial() -> void:
	if _inter_loading or not sdk_ready:
		return
	_inter_loading = true
	backend.load_interstitial(str(ids.get("interstitial", "")), _on_inter_loaded, _on_inter_failed)


func _on_inter_loaded() -> void:
	_inter_loading = false
	_inter_fail_count = 0


func _on_inter_failed(err: String) -> void:
	_inter_loading = false
	push_warning("Interstitial failed: %s" % err)
	_retry_later(config.get("rewarded", {}).get("reload_backoff_seconds", [30]), _inter_fail_count, _load_interstitial)
	_inter_fail_count += 1


# ------------------------------------------------------------------ rewarded
func is_rewarded_ready() -> bool:
	return enabled and sdk_ready and backend != null and not _rewarded_busy and backend.is_rewarded_ready()


## Starts a rewarded ad. Returns false if none can be shown right now.
## The result arrives via rewarded_finished(placement, earned) - grant the reward only
## when earned == true. Emitted exactly once per request.
func show_rewarded(placement: String) -> bool:
	if not is_rewarded_ready():
		return false
	_rewarded_busy = true
	_reward_earned = false
	_rewarded_placement = placement
	backend.show_rewarded(_on_reward_earned, _on_rewarded_closed)
	return true


func _on_reward_earned() -> void:
	_reward_earned = true


func _on_rewarded_closed() -> void:
	if not _rewarded_busy:
		return  # duplicate callback: never pay twice
	_rewarded_busy = false
	var earned := _reward_earned
	_reward_earned = false
	_load_rewarded()
	rewarded_finished.emit(_rewarded_placement, earned)


func _load_rewarded() -> void:
	if _rew_loading or not sdk_ready:
		return
	_rew_loading = true
	backend.load_rewarded(str(ids.get("rewarded", "")), _on_rew_loaded, _on_rew_failed)


func _on_rew_loaded() -> void:
	_rew_loading = false
	_rew_fail_count = 0
	availability_changed.emit()


func _on_rew_failed(err: String) -> void:
	_rew_loading = false
	push_warning("Rewarded failed: %s" % err)
	_retry_later(config.get("rewarded", {}).get("reload_backoff_seconds", [30]), _rew_fail_count, _load_rewarded)
	_rew_fail_count += 1


# ------------------------------------------------------------------ helpers
func _retry_later(schedule: Array, attempt: int, action: Callable) -> void:
	var secs := 30.0
	if not schedule.is_empty():
		secs = float(schedule[mini(attempt, schedule.size() - 1)])
	get_tree().create_timer(secs).timeout.connect(action)
