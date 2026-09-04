extends Node2D

# Drops enemies in from above and slowly speeds up as the run goes on.

@export var start_interval := 1.05
@export var min_interval := 0.3
@export var ramp_per_second := 0.02

var _enemy_one := preload("res://components/enemy_one.tscn")
var _enemy_two := preload("res://components/enemy_two.tscn")
var _meteor := preload("res://components/meteor.tscn")
var _powerup := preload("res://components/powerup.tscn")


func _ready() -> void:
	$Timer.wait_time = start_interval


func _process(delta: float) -> void:
	if Global.game_on and not Global.game_over:
		if $Timer.wait_time > min_interval:
			$Timer.wait_time = maxf(min_interval, $Timer.wait_time - ramp_per_second * delta)


func _on_timer_timeout() -> void:
	if not Global.game_on or Global.game_over:
		return

	var scene: PackedScene
	var roll := randf()
	if roll < 0.06:
		scene = _powerup
	elif roll < 0.46:
		scene = _enemy_one
	elif roll < 0.76:
		scene = _meteor
	else:
		scene = _enemy_two

	var new_enemy = scene.instantiate()
	# Position is set before add_child so the enemy's _ready() sees it.
	new_enemy.position = Vector2(randf_range($lPoint.position.x, $rPoint.position.x), -100.0)
	add_child(new_enemy)
