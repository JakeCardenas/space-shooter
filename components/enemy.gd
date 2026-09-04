extends Area2D

# Shared script for everything that comes at the player: formation enemies,
# meteors and power-ups. Meteors and power-ups stay in the FALL state and
# behave exactly like they always did. Formation enemies fly in along a curve,
# hold a slot in the grid, and occasionally dive at the player.

enum State { FALL, ENTER, FORMATION, WARN, DIVE }

@export_group("Stats")
@export var health := 1
@export var speed := 180.0
@export var score_value := 1
@export var kind := "ship"
@export var contact_damage := 1
@export var dies_on_contact := true
@export var explosion_radius := 55.0
@export var big_explosion := false

@export_group("Falling")
@export var weave_amplitude := 0.0
@export var weave_speed := 2.0
@export var spin_speed := 0.0

@export_group("Formation")
@export var formation_member := false
@export var entry_speed := 560.0
@export var dive_speed := 430.0
@export var dive_pattern := "curved"   ## straight, curved, zigzag or fast
@export var return_chance := 0.5
@export var shoots := false
@export var shoot_interval := 2.4
@export var drops_powerup := false

var destroyed := false
var state: int = State.FALL
var formation: Node2D = null
var slot_index := -1
var speed_scale := 1.0

var _explosion := preload("res://scenes/explosion.tscn")
var _bullet := preload("res://components/enemy_bullet.tscn")

var _powerup_scene: PackedScene   # loaded on demand: powerup.tscn uses this same script
var _time := 0.0
var _start_x := 0.0
var _path: Array[Vector2] = []
var _path_t := 0.0
var _path_len := 1.0
var _warn_timer := 0.0
var _shoot_timer := 0.0
var _returns := false
var _prev_pos := Vector2.ZERO


func _ready() -> void:
	_start_x = position.x
	_time = randf() * TAU
	_prev_pos = position
	_shoot_timer = randf_range(1.0, maxf(shoot_interval, 1.2))


func _process(delta: float) -> void:
	if destroyed or not Global.game_on or Global.game_over:
		return

	_time += delta
	match state:
		State.FALL:
			_process_fall(delta)
		State.ENTER:
			_process_enter(delta)
		State.FORMATION:
			_process_formation(delta)
		State.WARN:
			_process_warn(delta)
		State.DIVE:
			_process_dive(delta)

	if shoots and (state == State.FORMATION or state == State.DIVE):
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_shoot_timer = shoot_interval * randf_range(0.7, 1.3)
			_fire()


# --- falling behaviour (meteors and power-ups) -----------------------------

func _process_fall(delta: float) -> void:
	position.y += speed * speed_scale * delta
	if weave_amplitude > 0.0:
		position.x = _start_x + sin(_time * weave_speed) * weave_amplitude
	if spin_speed != 0.0:
		$Sprite2D.rotation += spin_speed * delta
	if position.y > get_viewport_rect().size.y + 140.0:
		queue_free()


# --- formation behaviour ---------------------------------------------------

func begin_entry(path_points: Array) -> void:
	var target: Vector2 = position
	if is_instance_valid(formation):
		target = formation.get_slot_base(slot_index)
	_path = [path_points[0], path_points[1], path_points[2], target]
	position = path_points[0]
	_prev_pos = position
	_path_t = 0.0
	_path_len = _measure_path()
	state = State.ENTER


func _process_enter(delta: float) -> void:
	_path_t += (entry_speed * speed_scale / _path_len) * delta
	if _path_t >= 1.0:
		_path_t = 1.0
		_apply_path_position()
		state = State.FORMATION
		Sfx.play("enemy_formation", -20.0, randf_range(0.95, 1.12))
		return
	_apply_path_position()


func _process_formation(delta: float) -> void:
	var weight := minf(1.0, 8.0 * delta)
	if is_instance_valid(formation):
		position = position.lerp(formation.get_slot_position(slot_index), weight)
	rotation = lerp_angle(rotation, 0.0, weight)
	_prev_pos = position


func _process_warn(delta: float) -> void:
	_process_formation(delta)
	_warn_timer -= delta
	if _warn_timer <= 0.0:
		_launch_dive()


func can_dive() -> bool:
	return formation_member and not destroyed and state == State.FORMATION


func start_dive() -> void:
	if not can_dive():
		return
	state = State.WARN
	_warn_timer = 0.5
	var tween := create_tween().set_loops(3)
	tween.tween_property($Sprite2D, "modulate", Color(2.4, 0.5, 0.5), 0.08)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.08)


func _launch_dive() -> void:
	var screen := get_viewport_rect().size
	var target_x := screen.x * 0.5
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		target_x = player.global_position.x

	var start := position
	var end := Vector2(clampf(target_x + randf_range(-70.0, 70.0), 40.0, screen.x - 40.0),
		screen.y + 180.0)
	var side := 1.0 if start.x < screen.x * 0.5 else -1.0
	var c1: Vector2
	var c2: Vector2

	match dive_pattern:
		"straight":
			c1 = start + Vector2(0.0, 260.0)
			c2 = end - Vector2(0.0, 260.0)
		"zigzag":
			c1 = start + Vector2(side * 200.0, 200.0)
			c2 = end - Vector2(side * 200.0, 220.0)
		"fast":
			c1 = start + Vector2(side * 60.0, 340.0)
			c2 = end - Vector2(side * 60.0, 300.0)
		_:
			c1 = start + Vector2(side * 330.0, 210.0)
			c2 = end - Vector2(side * 300.0, 300.0)

	_path = [start, c1, c2, end]
	_path_t = 0.0
	_path_len = _measure_path()
	_returns = randf() < return_chance
	state = State.DIVE
	Sfx.play_varied("enemy_dive", -14.0, 0.1)


func _process_dive(delta: float) -> void:
	_path_t += (dive_speed * speed_scale / _path_len) * delta
	if _path_t >= 1.0:
		_finish_dive()
		return
	var wobble := Vector2.ZERO
	if dive_pattern == "zigzag":
		wobble.x = sin(_path_t * PI * 5.0) * 60.0
	_apply_path_position(wobble)


func _finish_dive() -> void:
	# Survivors loop back around the top and rejoin the formation.
	if _returns and is_instance_valid(formation):
		var screen := get_viewport_rect().size
		var start := Vector2(clampf(position.x, 60.0, screen.x - 60.0), -140.0)
		var target: Vector2 = formation.get_slot_base(slot_index)
		_path = [start, start + Vector2(0.0, 220.0), target - Vector2(0.0, 240.0), target]
		position = start
		_prev_pos = start
		_path_t = 0.0
		_path_len = _measure_path()
		state = State.ENTER
	else:
		queue_free()


func _fire() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or not player.visible:
		return
	var bullet = _bullet.instantiate()
	bullet.direction = (player.global_position - global_position).normalized()
	get_parent().add_child(bullet)
	bullet.global_position = global_position + Vector2(0.0, 26.0)
	Sfx.play_varied("enemy_shoot", -16.0, 0.12)


# --- damage ----------------------------------------------------------------

func take_damage(amount: int) -> void:
	if destroyed:
		return
	health -= amount
	if health <= 0:
		explode(true)
	else:
		_flash()


func explode(award_score: bool) -> void:
	if destroyed:
		return
	destroyed = true
	if award_score:
		Global.register_kill(score_value, global_position)

	set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	speed = 0.0

	if big_explosion:
		Sfx.play_varied("explosion_big", -4.0, 0.1)
		Global.shake(7.0)
	else:
		Sfx.play_varied("explosion", -6.0, 0.14)
		Global.shake(2.0)

	if drops_powerup and award_score:
		if _powerup_scene == null:
			_powerup_scene = load("res://components/powerup.tscn")
		var drop = _powerup_scene.instantiate()
		drop.position = position
		# deferred: explode() can run during a collision callback
		get_parent().call_deferred("add_child", drop)

	var boom = _explosion.instantiate()
	boom.radius = explosion_radius
	boom.shards = 12 if big_explosion else 8
	boom.color = Color(0.8, 0.7, 0.55) if kind == "meteor" else Color(1.0, 0.55, 0.2)
	get_parent().add_child(boom)
	boom.global_position = global_position

	var tween := create_tween().set_parallel(true)
	tween.tween_property($Sprite2D, "scale", $Sprite2D.scale * 1.6, 0.2)
	tween.tween_property($Sprite2D, "modulate", Color(1, 1, 1, 0), 0.2)
	await tween.finished
	queue_free()


func collect() -> void:
	if destroyed:
		return
	destroyed = true
	set_deferred("monitoring", false)
	queue_free()


func _flash() -> void:
	$Sprite2D.modulate = Color(4, 4, 4)
	var tween := create_tween()
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.14)


func _on_area_entered(area: Area2D) -> void:
	if destroyed:
		return
	if kind != "powerup" and area.is_in_group("laser"):
		take_damage(area.damage)
		area.on_hit()


# --- path helpers ----------------------------------------------------------

func _apply_path_position(extra := Vector2.ZERO) -> void:
	var point := _bezier(_path_t) + extra
	var step := point - _prev_pos
	position = point
	if step.length() > 0.5:
		rotation = lerp_angle(rotation, step.angle() - PI / 2.0, 0.3)
	_prev_pos = point


func _bezier(t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * _path[0] + 3.0 * u * u * t * _path[1] \
		+ 3.0 * u * t * t * _path[2] + t * t * t * _path[3]


func _measure_path() -> float:
	var total := 0.0
	var prev := _path[0]
	for i in range(1, 13):
		var point := _bezier(float(i) / 12.0)
		total += prev.distance_to(point)
		prev = point
	return maxf(total, 1.0)
