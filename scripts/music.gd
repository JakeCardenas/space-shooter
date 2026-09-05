extends Node

# Autoload "Music". One looping AudioStreamPlayer that crossfades between
# named tracks. Looping is done by hand (replay on `finished`) so any format
# works without per-format loop-flag handling.
#
# No tracks ship with the project yet — play() checks the file exists before
# loading, so calling it with nothing in music/ is a silent no-op. Drop an
# .ogg or .wav at the paths below and it starts working immediately.

const TRACKS := {
	"menu": "res://music/menu.ogg",
	"gameplay": "res://music/gameplay.ogg",
	"challenge": "res://music/challenge.ogg",
	"boss": "res://music/boss.ogg",
	"game_over": "res://music/game_over.ogg",
	"high_score": "res://music/high_score.ogg",
}
const VOLUME_DB := -6.0
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


func play(track: String) -> void:
	if track == _current:
		return
	_current = track

	if not TRACKS.has(track) or not ResourceLoader.exists(TRACKS[track]):
		stop()
		return

	var stream := load(TRACKS[track])
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
