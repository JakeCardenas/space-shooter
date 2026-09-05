extends Area2D

# Mini-boss. Holds the top of the screen, sweeps side to side and escalates
# through four health-based phases, each unlocking a wider attack pool and
# moving faster. Uses the same take_damage / explode interface as enemy.gd so
# lasers and player collisions work unchanged.
#
# To add a new boss: instance this scene with a different sprite/health/score,
# or extend it — phases, tints and pattern pools are all data (the arrays
# below), so a subclass only needs to override PATTERN_POOLS-equivalent state.

signal health_changed(fraction: float)
signal phase_changed(phase: int)
signal died

@export var max_health := 40
@export var score_value := 400
@export var contact_damage := 2
@export var dies_on_contact := false

const PHASE_TINTS := [Color.WHITE, Color(1.0, 0.85, 0.4), Color(1.0, 0.55, 0.35), Color(1.0, 0.3, 0.3)]
const PHASE_TIMER_MULT := [1.0, 0.8, 0.6, 0.4]
const PHASE_MOVE_MULT := [1.0, 1.15, 1.35, 1.6]
const PHASE_SHAKE := [0.0, 10.0, 14.0, 20.0]
# Which pattern ids are in rotation once a phase is reached.
const PHASE_POOLS := [
	[0, 1],
	[0, 1, 2],
	[1, 2, 3],
	[2, 3, 4],
]

var health := 0
var destroyed := false

var _bullet := preload("res://components/enemy_bullet.tscn")
var _explosion := preload("res://scenes/explosion.tscn")
var _powerup := preload("res://components/powerup.tscn")

var _t := 0.0
var _phase := 0
var _pattern := 0
var _pattern_timer := 5.0
var _shoot_timer := 1.4
var _spiral_angle := 0.0
var _wall_offset := 0.0
var _entering := true
var _hover_y := 250.0
var _center_x := 360.0


func _ready() -> void:
	health = max_health
	_center_x = get_viewport_rect().size.x * 0.5
	position = Vector2(_center_x, -160.0)
	health_changed.emit(1.0)
	phase_changed.emit(0)


func _process(delta: float) -> void:
	if destroyed or not Global.game_on or Global.game_over:
		return

	_t += delta

	if _entering:
		position.y = move_toward(position.y, _hover_y, 190.0 * delta)
		if absf(position.y - _hover_y) < 1.0:
			_entering = false
			_entrance_slam()
		return

	var move_mult: float = PHASE_MOVE_MULT[_phase]
	position.x = _center_x + sin(_t * 0.7 * move_mult) * 250.0
	position.y = _hover_y + sin(_t * 1.3 * move_mult) * 18.0

	_pattern_timer -= delta
	if _pattern_timer <= 0.0:
		var pool: Array = PHASE_POOLS[_phase]
		_pattern = pool[randi() % pool.size()]
		_pattern_timer = 5.0 * PHASE_TIMER_MULT[_phase]

	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_fire_pattern()


func _entrance_slam() -> void:
	Global.shake(12.0)
	Sfx.play("boss_warn", -4.0, 0.85)
	var tween := create_tween().set_loops(2)
	tween.tween_property($Sprite2D, "modulate", Color(2.4, 2.4, 2.4), 0.1)
	tween.tween_property($Sprite2D, "modulate", PHASE_TINTS[_phase], 0.1)


func _fire_pattern() -> void:
	var mult: float = PHASE_TIMER_MULT[_phase]
	match _pattern:
		0:  # spread fan
			for angle in [-0.5, -0.25, 0.0, 0.25, 0.5]:
				_spawn_bullet(Vector2.DOWN.rotated(angle))
			_shoot_timer = 1.5 * mult
		1:  # aimed burst
			var direction := Vector2.DOWN
			var player := get_tree().get_first_node_in_group("player")
			if is_instance_valid(player):
				direction = (player.global_position - global_position).normalized()
			for i in 3:
				_spawn_bullet(direction.rotated(randf_range(-0.14, 0.14)))
			_shoot_timer = 1.2 * mult
		2:  # rapid sine stream
			_spawn_bullet(Vector2.DOWN.rotated(sin(_t * 2.2) * 0.7))
			_shoot_timer = 0.17 * mult
		3:  # sweeping curtain, phase 2+
			_wall_offset = sin(_t * 1.6) * 90.0
			for dx in [-70.0, 0.0, 70.0]:
				_spawn_bullet_at(Vector2(dx + _wall_offset, 44.0), Vector2.DOWN)
			_shoot_timer = 0.85 * mult
		_:  # spiral bloom, enrage only
			_spiral_angle += 0.55
			_spawn_bullet(Vector2.DOWN.rotated(_spiral_angle))
			_spawn_bullet(Vector2.DOWN.rotated(_spiral_angle + PI))
			_shoot_timer = 0.14 * mult
	Sfx.play_varied("enemy_shoot", -14.0, 0.12)


func _spawn_bullet(direction: Vector2) -> void:
	_spawn_bullet_at(Vector2(0.0, 44.0), direction)


func _spawn_bullet_at(offset: Vector2, direction: Vector2) -> void:
	var bullet = _bullet.instantiate()
	bullet.direction = direction
	bullet.speed = 430.0
	get_parent().add_child(bullet)
	bullet.global_position = global_position + offset


func take_damage(amount: int) -> void:
	if destroyed:
		return
	health -= amount
	var fraction := clampf(float(health) / float(max_health), 0.0, 1.0)
	health_changed.emit(fraction)
	if health <= 0:
		explode(true)
		return

	var new_phase := _phase_for(fraction)
	if new_phase != _phase:
		_enter_phase(new_phase)
	else:
		$Sprite2D.modulate = Color(3, 3, 3)
		var tween := create_tween()
		tween.tween_property($Sprite2D, "modulate", PHASE_TINTS[_phase], 0.1)


func _phase_for(fraction: float) -> int:
	if fraction <= 0.15:
		return 3
	if fraction <= 0.33:
		return 2
	if fraction <= 0.66:
		return 1
	return 0


func _enter_phase(phase: int) -> void:
	_phase = phase
	_pattern_timer = 0.0
	Global.shake(PHASE_SHAKE[phase])
	Sfx.play("boss_warn", -3.0, 1.0 + phase * 0.15)
	phase_changed.emit(phase)

	var tween := create_tween().set_loops(4)
	tween.tween_property($Sprite2D, "modulate", Color(3, 1, 3) if phase == 3 else Color(3, 3, 3), 0.08)
	tween.tween_property($Sprite2D, "modulate", PHASE_TINTS[phase], 0.08)


func explode(award_score: bool) -> void:
	if destroyed:
		return
	destroyed = true
	set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	Sfx.play("boss_explosion", -2.0)
	Global.shake(22.0)
	if award_score:
		Global.register_kill(score_value, global_position)
		Global.award_bonus("BOSS DEFEATED", 1000)
	died.emit()

	for i in 7:
		if not is_inside_tree():
			return
		var boom = _explosion.instantiate()
		boom.radius = randf_range(42.0, 90.0)
		boom.duration = 0.6
		boom.shards = 12
		get_parent().add_child(boom)
		boom.global_position = global_position + Vector2(randf_range(-70.0, 70.0), randf_range(-36.0, 36.0))
		$Sprite2D.modulate = Color(1, 1, 1, 1.0 - float(i) / 7.0)
		await get_tree().create_timer(0.09).timeout

	if is_inside_tree():
		var drop = _powerup.instantiate()
		drop.position = position
		get_parent().call_deferred("add_child", drop)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if destroyed:
		return
	if area.is_in_group("laser"):
		take_damage(area.damage)
		area.on_hit()
