extends RefCounted
## AdMob backend for the Poing Studios "Godot AdMob" plugin (poingstudios/godot-admob-plugin).
##
## API names below were checked against the plugin's published documentation
## (poingstudios.github.io/godot-admob-plugin, "latest" = master, needs Godot 4.5+): MobileAds,
## AdView + AdListener, InterstitialAdLoader/-LoadCallback, RewardedAdLoader/-LoadCallback,
## FullScreenContentCallback, OnUserEarnedRewardListener, UserMessagingPlatform.consent_information
## .update(), load_consent_form(), ConsentForm.show().
## It has NOT been compiled against the real plugin (the build sandbox had no Godot). The docs mark the
## "latest" pages as experimental and the README shows a slightly different UMP style, so if your
## plugin release differs, the editor underlines the exact name to change. Anything not in the docs
## (privacy-options form) is called dynamically so a mismatch cannot break compilation.
## AdManager loads this script at runtime and falls back to the no-ads stub if it fails to compile.

var _banner: AdView
var _interstitial: InterstitialAd
var _rewarded: RewardedAd
var _consent_form: ConsentForm

# listener objects must stay referenced while ads exist
var _banner_listener := AdListener.new()
var _inter_load_cb := InterstitialAdLoadCallback.new()
var _inter_fs_cb := FullScreenContentCallback.new()
var _rew_load_cb := RewardedAdLoadCallback.new()
var _rew_fs_cb := FullScreenContentCallback.new()
var _earned_listener := OnUserEarnedRewardListener.new()

var _on_banner_loaded: Callable
var _on_banner_failed: Callable
var _on_inter_loaded: Callable
var _on_inter_failed: Callable
var _on_inter_closed: Callable
var _on_rew_loaded: Callable
var _on_rew_failed: Callable
var _on_rew_earned: Callable
var _on_rew_closed: Callable
var _on_consent_done: Callable


func is_available() -> bool:
	return true


# ------------------------------------------------------------------ consent (UMP)
func request_consent(on_done: Callable) -> void:
	_on_consent_done = on_done
	var request := ConsentRequestParameters.new()
	request.tag_for_under_age_of_consent = false  # app is not child-directed
	UserMessagingPlatform.consent_information.update(request, _consent_info_updated, _consent_info_failed)


func _consent_info_updated() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_consent_form_loaded, _consent_form_failed)
	else:
		_finish_consent()


func _consent_info_failed(_error: FormError) -> void:
	_finish_consent()


func _consent_form_loaded(form: ConsentForm) -> void:
	_consent_form = form
	var info: Variant = UserMessagingPlatform.consent_information
	if info.get_consent_status() == info.ConsentStatus.REQUIRED:
		form.show(_consent_form_dismissed)
	else:
		_finish_consent()


func _consent_form_failed(_error: FormError) -> void:
	_finish_consent()


func _consent_form_dismissed(_error: FormError) -> void:
	_finish_consent()


## Ads may be requested only when consent is obtained or not required.
func _finish_consent() -> void:
	var info: Variant = UserMessagingPlatform.consent_information
	var status: Variant = info.get_consent_status()
	var can_request: bool = status == info.ConsentStatus.OBTAINED or status == info.ConsentStatus.NOT_REQUIRED
	var options_required := false
	if info.has_method("get_privacy_options_requirement_status"):
		options_required = int(info.get_privacy_options_requirement_status()) == 2  # Google UMP: 2 = REQUIRED
	if _on_consent_done.is_valid():
		var cb := _on_consent_done
		_on_consent_done = Callable()
		cb.call(can_request, options_required)


func show_privacy_options(on_done: Callable) -> void:
	var ump: Variant = UserMessagingPlatform
	if ump.has_method("show_privacy_options_form"):
		ump.show_privacy_options_form(func(_err: Variant) -> void: on_done.call(true))
	else:
		push_warning("Plugin build has no show_privacy_options_form()")
		on_done.call(false)


# ------------------------------------------------------------------ SDK
func initialize(on_done: Callable) -> void:
	MobileAds.initialize()  # once, at launch (plugin docs)
	on_done.call(true)


# ------------------------------------------------------------------ banner
func show_banner(unit_id: String, on_loaded: Callable, on_failed: Callable) -> void:
	destroy_banner()
	_on_banner_loaded = on_loaded
	_on_banner_failed = on_failed
	_banner_listener.on_ad_loaded = _banner_loaded
	_banner_listener.on_ad_failed_to_load = _banner_failed
	_banner = AdView.new(unit_id, AdSize.BANNER, AdPosition.BOTTOM)
	_banner.ad_listener = _banner_listener
	_banner.load_ad(AdRequest.new())


func _banner_loaded() -> void:
	if _on_banner_loaded.is_valid():
		_on_banner_loaded.call()


func _banner_failed(error: LoadAdError) -> void:
	if _on_banner_failed.is_valid():
		_on_banner_failed.call(str(error.message))


func destroy_banner() -> void:
	if _banner:
		_banner.destroy()  # plugin docs: always destroy to free native memory
		_banner = null


# ------------------------------------------------------------------ interstitial
func load_interstitial(unit_id: String, on_loaded: Callable, on_failed: Callable) -> void:
	_on_inter_loaded = on_loaded
	_on_inter_failed = on_failed
	_inter_load_cb.on_ad_loaded = _inter_loaded
	_inter_load_cb.on_ad_failed_to_load = _inter_failed
	InterstitialAdLoader.new().load(unit_id, AdRequest.new(), _inter_load_cb)


func _inter_loaded(ad: InterstitialAd) -> void:
	if _interstitial:
		_interstitial.destroy()
	_interstitial = ad
	_inter_fs_cb.on_ad_dismissed_full_screen_content = _inter_dismissed
	_inter_fs_cb.on_ad_failed_to_show_full_screen_content = _inter_show_failed
	_interstitial.full_screen_content_callback = _inter_fs_cb
	if _on_inter_loaded.is_valid():
		_on_inter_loaded.call()


func _inter_failed(error: LoadAdError) -> void:
	if _on_inter_failed.is_valid():
		_on_inter_failed.call(str(error.message))


func is_interstitial_ready() -> bool:
	return _interstitial != null


func show_interstitial(on_closed: Callable) -> void:
	if _interstitial == null:
		on_closed.call()
		return
	_on_inter_closed = on_closed
	_interstitial.show()


func _inter_dismissed() -> void:
	_release_interstitial_and_continue()


func _inter_show_failed(_error: AdError) -> void:
	_release_interstitial_and_continue()


func _release_interstitial_and_continue() -> void:
	if _interstitial:
		_interstitial.destroy()
		_interstitial = null
	if _on_inter_closed.is_valid():
		var cb := _on_inter_closed
		_on_inter_closed = Callable()
		cb.call()


# ------------------------------------------------------------------ rewarded
func load_rewarded(unit_id: String, on_loaded: Callable, on_failed: Callable) -> void:
	_on_rew_loaded = on_loaded
	_on_rew_failed = on_failed
	_rew_load_cb.on_ad_loaded = _rew_loaded
	_rew_load_cb.on_ad_failed_to_load = _rew_failed
	RewardedAdLoader.new().load(unit_id, AdRequest.new(), _rew_load_cb)


func _rew_loaded(ad: RewardedAd) -> void:
	if _rewarded:
		_rewarded.destroy()
	_rewarded = ad
	_rew_fs_cb.on_ad_dismissed_full_screen_content = _rew_dismissed
	_rew_fs_cb.on_ad_failed_to_show_full_screen_content = _rew_show_failed
	_rewarded.full_screen_content_callback = _rew_fs_cb
	if _on_rew_loaded.is_valid():
		_on_rew_loaded.call()


func _rew_failed(error: LoadAdError) -> void:
	if _on_rew_failed.is_valid():
		_on_rew_failed.call(str(error.message))


func is_rewarded_ready() -> bool:
	return _rewarded != null


func show_rewarded(on_earned: Callable, on_closed: Callable) -> void:
	if _rewarded == null:
		on_closed.call()
		return
	_on_rew_earned = on_earned
	_on_rew_closed = on_closed
	_earned_listener.on_user_earned_reward = _rew_earned
	_rewarded.show(_earned_listener)


func _rew_earned(_item: RewardedItem) -> void:
	if _on_rew_earned.is_valid():
		_on_rew_earned.call()


func _rew_dismissed() -> void:
	_release_rewarded_and_continue()


func _rew_show_failed(_error: AdError) -> void:
	_release_rewarded_and_continue()


func _release_rewarded_and_continue() -> void:
	if _rewarded:
		_rewarded.destroy()
		_rewarded = null
	if _on_rew_closed.is_valid():
		var cb := _on_rew_closed
		_on_rew_closed = Callable()
		cb.call()
