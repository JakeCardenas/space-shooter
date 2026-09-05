extends Node

# Autoload "Music". One looping AudioStreamPlayer that crossfades between
# named tracks. Looping is done by hand (replay on `finished`) so any format
# works without per-format loop-flag handling.
#
# Drop a file at music/<name>.ogg (or .mp3 / .wav) and it is picked up
# automatically. Asking for a track with no file present leaves whatever is
# already playing alone, so a partial soundtrack still plays continuously
# instead of cutting to silence.

const TRACKS := ["menu", "gameplay", "challenge", "boss", "game_over", "high_score"]
const EXTENSIONS := [".ogg", ".mp3", ".wav"]
const VOLUME_DB := -8.0
const FADE_TIME := 0.6

var _player: AudioStreamPlayer
var _current := ""
var _fade_tween: Tween = null


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_player.finished.connect(_on_finished)


func track_path(track: String) -> String:
	for ext in EXTENSIONS:
		var path := "res://music/%s%s" % [track, ext]
		if ResourceLoader.exists(path):
			return path
	return ""


func play(track: String) -> void:
	if track == _current:
		return
	var path := track_path(track)
	if path == "":
		return  # nothing supplied for this track — keep the current one going
	_current = track

	var stream := load(path)
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()

	if _player.playing:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_player, "volume_db", -40.0, FADE_TIME)
		await _fade_tween.finished
		if _current != track:
			return

	_player.stream = stream
	_player.volume_db = VOLUME_DB
	_player.play()


func stop() -> void:
	_current = ""
	if not _player.playing:
		return
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", -40.0, FADE_TIME)
	await _fade_tween.finished
	_player.stop()


func _on_finished() -> void:
	if _current != "" and _player.stream != null:
		_player.play()
