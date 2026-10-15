extends Node
## Sound effects (small player pool) and looping music, honouring the user's settings.

const SFX := ["shoot", "pop", "pop_1", "pop_2", "pop_3", "chime_0", "chime_1", "chime_2", "chime_3", "chime_4", "pop_big", "bounce", "land", "drop", "click", "coin", "power",
	"explosion", "lightning", "fire", "freeze", "win", "lose", "star"]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in SFX:
		var s: Variant = load("res://assets/sounds/%s.wav" % n)
		if s:
			_streams[n] = s
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -9.0
	add_child(_music)
	var m: Variant = load("res://assets/music/mystic_loop.wav")
	if m is AudioStreamWAV:
		m.loop_mode = AudioStreamWAV.LOOP_FORWARD
		m.loop_begin = 0
		m.loop_end = m.data.size() / 2  # 16-bit mono
		_music.stream = m
	apply_settings()


func play(sfx_name: String, pitch: float = 1.0) -> void:
	if not SaveManager.get_setting("sound") or not _streams.has(sfx_name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sfx_name]
	p.pitch_scale = pitch
	p.play()


func apply_settings() -> void:
	if _music == null or _music.stream == null:
		return
	if SaveManager.get_setting("music"):
		if not _music.playing:
			_music.play()
		_music.stream_paused = false
	else:
		_music.stop()


func _notification(what: int) -> void:
	if _music == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_music.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_music.stream_paused = false
