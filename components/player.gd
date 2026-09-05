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

var has_wingman := false
var weapon_override := ""
var shielded := false

var _invincible := false
var _last_x := 0.0
var _wing_home := Vector2(46.0, 6.0)


func _ready() -> void:
	health = max_health
	_last_x = global_position.x
	visible = false
	show_chosen_ship()


func show_chosen_ship() -> void:
	$ships/ship1.visible = Global.chosen_ship == 1
	$ships/ship2.visible = Global.chosen_ship == 2
	$ships/ship3.visible = Global.chosen_ship == 3
	$ships/Wingman.texture = load("res://art/ship%d.svg" % Global.chosen_ship)
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

	if weapon_override == "triple":
		fire_rate = 0.32
		for angle in [-0.22, 0.0, 0.22]:
			_spawn_main_laser(_laser_green, Vector2.UP.rotated(angle))
		Sfx.play_varied("laser_spread", -4.0, 0.06)
	elif weapon_override == "laser":
		fire_rate = 0.45
		_spawn_main_laser(_laser_orb, Vector2.UP)
		Sfx.play_varied("laser_heavy", -4.0, 0.05)
	else:
		match Global.chosen_ship:
			1:  # ACE — fast single shot
				fire_rate = 0.24
				_spawn_main_laser(_laser_blue, Vector2.UP)
				Sfx.play_varied("laser", -4.0, 0.07)
			2:  # TANK — slower triple spread
				fire_rate = 0.5
				for angle in [-0.2, 0.0, 0.2]:
					_spawn_main_laser(_laser_green, Vector2.UP.rotated(angle))
				Sfx.play_varied("laser_spread", -4.0, 0.06)
			3:  # ZAP — slow piercing orb
				fire_rate = 0.8
				_spawn_main_laser(_laser_orb, Vector2.UP)
				Sfx.play_varied("laser_heavy", -4.0, 0.05)

	# The wingman always fires one modest bolt per cycle, regardless of the
	# main weapon — mirroring every pellet would make Dual Fighter too strong.
	if has_wingman:
		_emit_laser(_laser_blue, Vector2.UP, $ships/Wingman.global_position + Vector2(0.0, -22.0))

	can_shoot = false
	$TimerToShoot.wait_time = maxf(0.08, fire_rate - power_up_boost)
	$TimerToShoot.start()


func _spawn_main_laser(scene: PackedScene, direction: Vector2) -> void:
	_emit_laser(scene, direction, $point.global_position)


func _emit_laser(scene: PackedScene, direction: Vector2, at: Vector2) -> void:
	var new_laser = scene.instantiate()
	new_laser.direction = direction
	new_laser.global_position = at
	get_parent().add_child(new_laser)


func can_be_captured() -> bool:
	return not destroyed and not _invincible and not shielded \
		and Global.game_on and not Global.game_over


# The tractor beam takes the ship itself: a life is spent, but the ship can be
# won back by destroying the enemy holding it.
func capture_ship() -> void:
	if not can_be_captured():
		return
	Sfx.play("game_over", -8.0, 1.4)
	Global.shake(14.0)
	Global.captured = true
	health -= 1
	Global.damaged_this_wave = true
	if health <= 0:
		health = 0
		die()
		return
	_start_invincibility()


func rescue_wingman(from: Vector2) -> void:
	if destroyed or has_wingman:
		return
	Global.captured = false
	has_wingman = true
	Sfx.play("powerup", -1.0, 0.8)
	Global.award_bonus("SHIP RESCUED", 500)
	var wing: Sprite2D = $ships/Wingman
	wing.visible = true
	wing.position = to_local(from)
	var tween := create_tween()
	tween.tween_property(wing, "position", _wing_home, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _drop_wingman() -> void:
	has_wingman = false
	$ships/Wingman.visible = false
	var boom = _explosion.instantiate()
	boom.radius = 46.0
	boom.duration = 0.4
	boom.color = Color(1.0, 0.6, 0.3)
	get_parent().add_child(boom)
	boom.global_position = $ships/Wingman.global_position


func take_damage(amount: int) -> void:
	if destroyed or _invincible:
		return
	if shielded:
		Sfx.play_varied("hit", -8.0, 1.4)
		return
	# The second fighter soaks the hit — that is what the extra firepower costs.
	if has_wingman:
		_drop_wingman()
		Sfx.play_varied("hit", -2.0, 0.1)
		Global.shake(9.0)
		Global.damaged_this_wave = true
		_start_invincibility()
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
	has_wingman = false
	$ships/Wingman.visible = false
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
		var power_kind: String = area.power_kind
		area.collect()
		Sfx.play("powerup", -2.0)
		_apply_power_up(power_kind)
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


func _apply_power_up(kind: String) -> void:
	match kind:
		"triple", "laser":
			weapon_override = kind
			$TimerWeapon.start()
		"shield":
			shielded = true
			$ShieldFX.visible = true
			$TimerShield.start()
		"bomb":
			_trigger_bomb()
		"slow":
			Global.start_slowmo(4.0)
		_:  # "rapid" and any unrecognised kind default to the fire-rate boost
			power_up_boost = 0.14
			$TimerPowerUp.start()


func _trigger_bomb() -> void:
	Sfx.play("explosion_big", -2.0)
	Global.shake(24.0)
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.destroyed:
			continue
		if "max_health" in enemy:
			enemy.take_damage(15)
		else:
			enemy.explode(true)
		count += 1
	for bullet in get_tree().get_nodes_in_group("enemyLaser"):
		if is_instance_valid(bullet):
			bullet.queue_free()
	if count > 0:
		Global.award_bonus("SMART BOMB", 0)


func _on_timer_power_up_timeout() -> void:
	power_up_boost = 0.0


func _on_timer_weapon_timeout() -> void:
	weapon_override = ""


func _on_timer_shield_timeout() -> void:
	shielded = false
	$ShieldFX.visible = false


func _on_timer_to_shoot_timeout() -> void:
	can_shoot = true
