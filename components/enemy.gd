extends Area2D

# Shared script for everything that comes at the player: formation enemies,
# meteors and power-ups. Meteors and power-ups stay in the FALL state and
# behave exactly like they always did. Formation enemies fly in along a curve,
# hold a slot in the grid, and occasionally dive at the player.

enum State { FALL, ENTER, FORMATION, WARN, DIVE, HUNT, BEAM }

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
@export var dive_pattern := "curved"   ## straight, curved, zigzag, fast or sweep
@export var return_chance := 0.5
@export var shoots := false
@export var shoot_interval := 2.4
@export var drops_powerup := false
@export var power_kind := ""   ## powerups only: forced kind, or "" to roll one

@export_group("Personality")
@export var captures := false      ## dives to hover and fires a tractor beam
@export var escorts := false       ## joins elite dives as a flanking guard
@export var sniper := false        ## stops and takes aim before firing

var destroyed := false
var state: int = State.FALL
var formation: Node2D = null
var slot_index := -1
var speed_scale := 1.0
var pass_through := false          ## challenge stages: fly the path, then leave
var has_captive := false

var _explosion := preload("res://scenes/explosion.tscn")
var _bullet := preload("res://components/enemy_bullet.tscn")
var _beam_scene := preload("res://components/tractor_beam.tscn")

var _powerup_scene: PackedScene   # loaded on demand: powerup.tscn uses this same script
var _time := 0.0
var _start_x := 0.0
var _path: Array[Vector2] = []
var _path_t := 0.0
var _path_len := 1.0
var _poly: PackedVector2Array = PackedVector2Array()
var _seg := 0
var _seg_t := 0.0
var _warn_timer := 0.0
var _shoot_timer := 0.0
var _returns := false
var _prev_pos := Vector2.ZERO
var _feint := false
var _capturing := false
var _hunt_target := Vector2.ZERO
var _beam: Node2D = null
var _beam_timer := 0.0
var _hold_timer := 0.0
var _aim_timer := 0.0
var _aim_x := -1.0
var _captive_sprite: Sprite2D = null
var _power_label: Label = null

const POWER_KINDS := ["rapid", "triple", "laser", "shield", "bomb", "slow"]
const POWER_WEIGHTS := [3, 2, 2, 2, 1, 1]
const POWER_TINTS := {
	"rapid": Color(1.0, 0.85, 0.25),
	"triple": Color(0.3, 0.9, 0.4),
	"laser": Color(0.75, 0.35, 1.0),
	"shield": Color(0.3, 0.75, 1.0),
	"bomb": Color(1.0, 0.3, 0.3),
	"slow": Color(0.4, 0.95, 0.9),
}
const POWER_LETTERS := {
	"rapid": "R", "triple": "T", "laser": "L",
	"shield": "S", "bomb": "B", "slow": "W",
}


func _ready() -> void:
	_start_x = position.x
	_time = randf() * TAU
	_prev_pos = position
	_shoot_timer = randf_range(1.0, maxf(shoot_interval, 1.2))
	if kind == "powerup":
		if power_kind == "":
			power_kind = _pick_power_kind()
		_add_power_label()
		$Sprite2D.scale = Vector2.ZERO
		var tween := create_tween()
		tween.tween_property($Sprite2D, "scale", Vector2.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play("bonus", -18.0, 1.45)


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
		State.HUNT:
			_process_hunt(delta)
		State.BEAM:
			_process_beam(delta)

	if shoots and (state == State.FORMATION or state == State.DIVE):
		if _aim_timer > 0.0:
			_aim_timer -= delta
			if _aim_timer <= 0.0:
				_fire()
		else:
			_shoot_timer -= delta
			if _shoot_timer <= 0.0:
				_shoot_timer = shoot_interval * randf_range(0.7, 1.3)
				if sniper:
					_take_aim()
				else:
					_fire()


# --- falling behaviour (meteors and power-ups) -----------------------------

func _process_fall(delta: float) -> void:
	position.y += speed * speed_scale * delta
	if weave_amplitude > 0.0:
		position.x = _start_x + sin(_time * weave_speed) * weave_amplitude
	if spin_speed != 0.0:
		$Sprite2D.rotation += spin_speed * delta
	if kind == "powerup":
		var glow := 0.5 + 0.5 * sin(_time * 7.0)
		var tint: Color = POWER_TINTS.get(power_kind, Color.WHITE)
		$Sprite2D.modulate = tint.lerp(tint * 1.8, glow)
	if position.y > get_viewport_rect().size.y + 140.0:
		queue_free()


# --- formation behaviour ---------------------------------------------------

func begin_entry(path_points: PackedVector2Array) -> void:
	_poly = PackedVector2Array(path_points)
	if is_instance_valid(formation) and not pass_through:
		_poly.append(formation.get_slot_base(slot_index))
	position = _poly[0]
	_prev_pos = position
	_seg = 0
	_seg_t = 0.0
	state = State.ENTER


# Walks the polyline at a constant speed, carrying leftover distance across
# segment boundaries so the loop stays smooth however finely it is sampled.
func _process_enter(delta: float) -> void:
	var step := entry_speed * speed_scale * delta
	while step > 0.0 and _seg < _poly.size() - 1:
		var length := _poly[_seg].distance_to(_poly[_seg + 1])
		if length <= 0.001:
			_seg += 1
			_seg_t = 0.0
			continue
		var remaining := (1.0 - _seg_t) * length
		if step < remaining:
			_seg_t += step / length
			step = 0.0
		else:
			step -= remaining
			_seg += 1
			_seg_t = 0.0

	if _seg >= _poly.size() - 1:
		_apply_point(_poly[_poly.size() - 1])
		if pass_through:
			queue_free()
			return
		state = State.FORMATION
		Sfx.play("enemy_formation", -20.0, randf_range(0.95, 1.12))
		return
	_apply_point(_poly[_seg].lerp(_poly[_seg + 1], _seg_t))


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


func start_dive(target_x := -1.0) -> void:
	if not can_dive():
		return
	_feint = false
	_capturing = false
	_aim_x = target_x
	_begin_warn(0.5, Color(2.4, 0.5, 0.5), 3)


# A dive that pulls up early and rejoins the formation — reads as a bluff.
func start_feint() -> void:
	if not can_dive():
		return
	_feint = true
	_capturing = false
	_aim_x = -1.0
	_begin_warn(0.4, Color(2.4, 2.0, 0.6), 2)


func start_capture() -> void:
	if not can_dive() or not captures:
		return
	_feint = false
	_capturing = true
	_aim_x = -1.0
	Sfx.play("boss_warn", -12.0, 1.5)
	_begin_warn(1.0, Color(2.2, 0.6, 2.6), 6)


func _begin_warn(seconds: float, tint: Color, blinks: int) -> void:
	state = State.WARN
	_warn_timer = seconds
	var tween := create_tween().set_loops(blinks)
	tween.tween_property($Sprite2D, "modulate", tint, 0.08)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.08)


func _launch_dive() -> void:
	var screen := get_viewport_rect().size
	if _capturing:
		_hunt_target = Vector2(_player_x(), screen.y * 0.46)
		state = State.HUNT
		Sfx.play_varied("enemy_dive", -12.0, 0.08)
		return

	var target_x := _aim_x if _aim_x >= 0.0 else _player_x()

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
		"sweep":
			# Crosses to the far side of the screen on the way down.
			var far := clampf(screen.x * 0.5 + side * (screen.x * 0.5 - 60.0),
				40.0, screen.x - 40.0)
			end = Vector2(far, screen.y + 180.0)
			c1 = start + Vector2(side * 300.0, 340.0)
			c2 = Vector2(far - side * 120.0, screen.y * 0.72)
		_:
			c1 = start + Vector2(side * 330.0, 210.0)
			c2 = end - Vector2(side * 300.0, 300.0)

	if _feint:
		# pull up well before the player and head straight back
		end = Vector2(start.x + (target_x - start.x) * 0.35, start.y + 300.0)
		c1 = start + Vector2(0.0, 190.0)
		c2 = end - Vector2(0.0, 120.0)

	_path = [start, c1, c2, end]
	_path_t = 0.0
	_path_len = _measure_path()
	_returns = true if _feint else randf() < return_chance
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
		position = start
		_prev_pos = start
		_poly = sample_curve(start, start + Vector2(0.0, 220.0),
			target - Vector2(0.0, 240.0), target, 14)
		_seg = 0
		_seg_t = 0.0
		state = State.ENTER
	else:
		queue_free()


func _process_hunt(delta: float) -> void:
	var to_target := _hunt_target - position
	var step := dive_speed * 0.75 * speed_scale * delta
	if to_target.length() <= step:
		position = _hunt_target
		_start_beam()
		return
	_apply_point(position + to_target.normalized() * step)


func _start_beam() -> void:
	state = State.BEAM
	_beam_timer = 2.6
	_hold_timer = 0.0
	rotation = 0.0
	_beam = _beam_scene.instantiate()
	add_child(_beam)
	_beam.position = Vector2(0.0, 22.0)
	Sfx.play("boss_warn", -8.0, 0.7)


func _process_beam(delta: float) -> void:
	_beam_timer -= delta
	# drift toward the player so the beam is dodgeable but not trivial
	position.x = move_toward(position.x, _player_x(), 90.0 * delta)

	if is_instance_valid(_beam):
		var open := clampf(1.0 - absf(_beam_timer - 1.3) / 1.3, 0.0, 1.0)
		_beam.strength = open
		var player := get_tree().get_first_node_in_group("player")
		if open > 0.6 and is_instance_valid(player) and player.can_be_captured() \
				and _beam.contains(player.global_position):
			_hold_timer += delta
			if _hold_timer >= 1.0:
				_capture(player)
				return
		else:
			_hold_timer = maxf(0.0, _hold_timer - delta * 0.7)

	if _beam_timer <= 0.0:
		_end_beam()
		_returns = true
		_finish_dive()


func _capture(player: Node) -> void:
	_end_beam()
	player.capture_ship()
	has_captive = true
	_show_captive()
	_returns = true
	_finish_dive()


func _end_beam() -> void:
	if is_instance_valid(_beam):
		_beam.queue_free()
	_beam = null


func _show_captive() -> void:
	if is_instance_valid(_captive_sprite):
		return
	_captive_sprite = Sprite2D.new()
	_captive_sprite.texture = load("res://art/ship%d.svg" % Global.chosen_ship)
	_captive_sprite.position = Vector2(0.0, 40.0)
	_captive_sprite.scale = Vector2(0.7, 0.7)
	_captive_sprite.rotation = PI
	add_child(_captive_sprite)


func _player_x() -> float:
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		return player.global_position.x
	return get_viewport_rect().size.x * 0.5


func _take_aim() -> void:
	_aim_timer = 0.55
	var tween := create_tween().set_loops(2)
	tween.tween_property($Sprite2D, "modulate", Color(2.6, 2.2, 0.7), 0.13)
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.13)


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

	_end_beam()
	set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	speed = 0.0

	if big_explosion:
		Sfx.play_varied("explosion_big", -4.0, 0.1)
		Global.shake(7.0)
	else:
		Sfx.play_varied("explosion", -6.0, 0.14)
		Global.shake(2.0)

	if has_captive:
		has_captive = false
		var player := get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.has_method("rescue_wingman"):
			player.rescue_wingman(global_position)

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
	var boom = _explosion.instantiate()
	boom.radius = 48.0
	boom.duration = 0.34
	boom.shards = 10
	boom.pixel = 5.0
	boom.color = Color(1.0, 0.86, 0.25)
	get_parent().add_child(boom)
	boom.global_position = global_position
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

func _apply_point(point: Vector2) -> void:
	var step := point - _prev_pos
	position = point
	if step.length() > 0.5:
		rotation = lerp_angle(rotation, step.angle() - PI / 2.0, 0.35)
	_prev_pos = point


static func _pick_power_kind() -> String:
	var total := 0
	for w in POWER_WEIGHTS:
		total += w
	var roll := randi() % total
	var acc := 0
	for i in POWER_KINDS.size():
		acc += POWER_WEIGHTS[i]
		if roll < acc:
			return POWER_KINDS[i]
	return POWER_KINDS[0]


func _add_power_label() -> void:
	_power_label = Label.new()
	_power_label.text = POWER_LETTERS.get(power_kind, "?")
	_power_label.add_theme_font_override("font", load("res://art/font/starbyte.fnt"))
	_power_label.add_theme_font_size_override("font_size", 16)
	_power_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
	_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_power_label.size = Vector2(28.0, 28.0)
	_power_label.position = Vector2(-14.0, -14.0)
	_power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_label.z_index = 1
	add_child(_power_label)


static func sample_curve(p0: Vector2, c1: Vector2, c2: Vector2, p3: Vector2,
		steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var u := 1.0 - t
		out.append(u * u * u * p0 + 3.0 * u * u * t * c1
			+ 3.0 * u * t * t * c2 + t * t * t * p3)
	return out


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
