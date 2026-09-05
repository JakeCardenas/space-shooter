extends Area2D

# The player ship. Hold the left mouse button (or touch) to fly toward the
# cursor and fire at the same time.

@export var speed := 950.0
@export var stopping_distance := 6.0
@export var max_health := 3

var health := 3
var destroyed := false
var can_shoot := true
var power_up_boost := 0.0

var _laser_blue := preload("res://components/laser_blue.tscn")
var _laser_green := preload("res://components/laser_green.tscn")
var _laser_orb := preload("res://components/laser_orb.tscn")
var _explosion := preload("res://scenes/explosion.tscn")

var _invincible := false
var _last_x := 0.0


func _ready() -> void:
	health = max_health
	_last_x = global_position.x
	visible = false
	show_chosen_ship()


func show_chosen_ship() -> void:
	$ships/ship1.visible = Global.chosen_ship == 1
	$ships/ship2.visible = Global.chosen_ship == 2
	$ships/ship3.visible = Global.chosen_ship == 3
	match Global.chosen_ship:
		1:
			$Trail.color = Color(0.45, 0.78, 1.0, 0.55)
		2:
			$Trail.color = Color(0.45, 1.0, 0.62, 0.55)
		_:
			$Trail.color = Color(0.78, 0.5, 1.0, 0.55)


func _process(delta: float) -> void:
	visible = Global.game_on
	if not Global.game_on or Global.game_over or destroyed:
		return

	_move(delta)

	if Input.is_action_pressed("left_click") and can_shoot:
		shoot_laser()


func _move(delta: float) -> void:
	if Input.is_action_pressed("left_click"):
		var to_target := get_global_mouse_position() - global_position
		if to_target.length() > stopping_distance:
			var step: float = min(speed * delta, to_target.length())
			global_position += to_target.normalized() * step

	var screen := get_viewport_rect().size
	global_position.x = clampf(global_position.x, 40.0, screen.x - 40.0)
	global_position.y = clampf(global_position.y, 190.0, screen.y - 100.0)

	var drift := global_position.x - _last_x
	_last_x = global_position.x
	var target_tilt := clampf(drift * 0.03, -0.32, 0.32)
	$ships.rotation = lerpf($ships.rotation, target_tilt, 10.0 * delta)


func shoot_laser() -> void:
	var fire_rate := 0.4

	match Global.chosen_ship:
		1:  # ACE — fast single shot
			fire_rate = 0.24
			_spawn_laser(_laser_blue, Vector2.UP)
			Sfx.play_varied("laser", -4.0, 0.07)
		2:  # TANK — slower triple spread
			fire_rate = 0.5
			for angle in [-0.2, 0.0, 0.2]:
				_spawn_laser(_laser_green, Vector2.UP.rotated(angle))
			Sfx.play_varied("laser_spread", -4.0, 0.06)
		3:  # ZAP — slow piercing orb
			fire_rate = 0.8
			_spawn_laser(_laser_orb, Vector2.UP)
			Sfx.play_varied("laser_heavy", -4.0, 0.05)

	can_shoot = false
	$TimerToShoot.wait_time = maxf(0.08, fire_rate - power_up_boost)
	$TimerToShoot.start()


func _spawn_laser(scene: PackedScene, direction: Vector2) -> void:
	var new_laser = scene.instantiate()
	new_laser.direction = direction
	new_laser.global_position = $point.global_position
	get_parent().add_child(new_laser)


func take_damage(amount: int) -> void:
	if destroyed or _invincible:
		return
	health -= amount
	Global.damaged_this_wave = true
	if health <= 0:
		health = 0
		die()
	else:
		Sfx.play_varied("hit", -1.0, 0.1)
		Global.shake(9.0)
		_start_invincibility()


func die() -> void:
	destroyed = true
	Global.end_run()
	$ships.visible = false
	$Trail.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	Sfx.play("explosion_big", -1.0)
	Sfx.play("game_over", -3.0)
	Global.shake(20.0)

	var boom = _explosion.instantiate()
	boom.radius = 90.0
	boom.duration = 0.8
	boom.shards = 14
	boom.color = Color(1.0, 0.45, 0.25)
	get_parent().add_child(boom)
	boom.global_position = global_position


func _start_invincibility() -> void:
	_invincible = true
	var tween := create_tween().set_loops(6)
	tween.tween_property($ships, "modulate:a", 0.25, 0.08)
	tween.tween_property($ships, "modulate:a", 1.0, 0.08)
	await tween.finished
	$ships.modulate.a = 1.0
	_invincible = false


func _on_area_entered(area: Area2D) -> void:
	if destroyed:
		return

	if area.is_in_group("powerUp"):
		area.collect()
		power_up_boost = 0.14
		Sfx.play("powerup", -2.0)
		$TimerPowerUp.start()
		var tween := create_tween()
		$ships.modulate = Color(2.0, 1.9, 1.2)
		tween.tween_property($ships, "modulate", Color.WHITE, 0.3)
		return

	if _invincible:
		return

	if area.is_in_group("enemyLaser"):
		area.on_hit()
		take_damage(area.damage)
		return

	if area.is_in_group("enemy"):
		var damage: int = area.contact_damage
		if area.dies_on_contact:
			area.explode(false)
		take_damage(damage)


func _on_timer_power_up_timeout() -> void:
	power_up_boost = 0.0


func _on_timer_to_shoot_timeout() -> void:
	can_shoot = true
