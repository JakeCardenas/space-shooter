extends Node

# Pooled sound player. Sounds keep playing even after the node that triggered
# them is freed. play_varied() adds a little pitch wobble so repeated shots
# and explosions don't get monotonous.

const POOL_SIZE := 24

var _sounds := {
	"laser": preload("res://sfx/laser.wav"),
	"laser_heavy": preload("res://sfx/laser_heavy.wav"),
	"laser_spread": preload("res://sfx/laser_spread.wav"),
	"enemy_shoot": preload("res://sfx/enemy_shoot.wav"),
	"enemy_spawn": preload("res://sfx/enemy_spawn.wav"),
	"enemy_formation": preload("res://sfx/enemy_formation.wav"),
	"enemy_dive": preload("res://sfx/enemy_dive.wav"),
	"explosion": preload("res://sfx/explosion.wav"),
	"explosion_big": preload("res://sfx/explosion_big.wav"),
	"boss_explosion": preload("res://sfx/boss_explosion.wav"),
	"boss_warn": preload("res://sfx/boss_warn.wav"),
	"hit": preload("res://sfx/hit.wav"),
	"powerup": preload("res://sfx/powerup.wav"),
	"game_over": preload("res://sfx/game_over.wav"),
	"wave_start": preload("res://sfx/wave_start.wav"),
	"wave_clear": preload("res://sfx/wave_clear.wav"),
	"bonus": preload("res://sfx/bonus.wav"),
	"combo": preload("res://sfx/combo.wav"),
	"new_high_score": preload("res://sfx/new_high_score.wav"),
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


func play_varied(sound_name: String, volume_db: float = 0.0, spread: float = 0.08) -> void:
	play(sound_name, volume_db, randf_range(1.0 - spread, 1.0 + spread))
