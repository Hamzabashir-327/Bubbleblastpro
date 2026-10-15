extends RefCounted
## "No ads" backend. Used on desktop/editor and whenever the AdMob plugin is not
## installed. It NEVER fakes an ad or a reward: every load fails, nothing is ever
## ready, so the game simply behaves as if ads were unavailable (core game is offline).

var reason := "AdMob plugin not installed or not running on Android"


func is_available() -> bool:
	return false


func request_consent(on_done: Callable) -> void:
	on_done.call(false, false)


func show_privacy_options(on_done: Callable) -> void:
	on_done.call(false)


func initialize(on_done: Callable) -> void:
	on_done.call(false)


func show_banner(_unit: String, _on_loaded: Callable, on_failed: Callable) -> void:
	on_failed.call(reason)


func destroy_banner() -> void:
	pass


func load_interstitial(_unit: String, _on_loaded: Callable, on_failed: Callable) -> void:
	on_failed.call(reason)


func is_interstitial_ready() -> bool:
	return false


func show_interstitial(on_closed: Callable) -> void:
	on_closed.call()


func load_rewarded(_unit: String, _on_loaded: Callable, on_failed: Callable) -> void:
	on_failed.call(reason)


func is_rewarded_ready() -> bool:
	return false


func show_rewarded(_on_earned: Callable, on_closed: Callable) -> void:
	on_closed.call()
