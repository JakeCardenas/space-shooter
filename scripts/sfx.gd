extends Node

# Autoloaded sound player. Uses a small pool of AudioStreamPlayers so that a
# sound keeps playing even after the node that triggered it has been freed.

const POOL_SIZE := 14

var _sounds := {
	"laser": preload("res://sfx/laser.wav"),
	"laser_heavy": preload("res://sfx/laser_heavy.wav"),
	"explosion": preload("res://sfx/explosion.wav"),
	"hit": preload("res://sfx/hit.wav"),
	"powerup": preload("res://sfx/powerup.wav"),
	"game_over": preload("res://sfx/game_over.wav"),
	"click": preload("res://sfx/click.wav"),
}

var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _sounds.has(sound_name):
		push_warning("Unknown sound: %s" % sound_name)
		return
	for player in _players:
		if not player.playing:
			player.stream = _sounds[sound_name]
			player.volume_db = volume_db
			player.pitch_scale = pitch
			player.play()
			return
