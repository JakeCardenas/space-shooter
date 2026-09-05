extends Node2D

# Wave manager. Builds a formation layout for each wave, flies the enemies in
# along curved entry paths, picks divers while the wave runs, and handles the
# gap between waves. Every fifth wave is a boss instead of a formation.

signal wave_started(wave: int)
signal stage_ready(wave: int)
signal wave_cleared(wave: int)
signal boss_spawned(boss: Node)

const FORMATION_TOP := 200.0
const COL_SPACING := 78.0
const ROW_SPACING := 60.0
const BOSS_EVERY := 5
const SQUAD_SIZE := 6

var _basic := preload("res://components/enemy_one.tscn")
var _strong := preload("res://components/enemy_two.tscn")
var _fast := preload("res://components/enemy_fast.tscn")
var _special := preload("res://components/enemy_special.tscn")
var _wasp := preload("res://components/enemy_wasp.tscn")
var _guard := preload("res://components/enemy_guard.tscn")
var _boss := preload("res://components/boss.tscn")
var _meteor := preload("res://components/meteor.tscn")
var _powerup := preload("res://components/powerup.tscn")

var _slots: Array[Vector2] = []
var _tiers: Array[int] = []
var _alive: Array = []
var _sway := 0.0
var _cooldown := 0.0
var _wave_running := false
var _spawning := false


func _process(delta: float) -> void:
	_sway += delta * 0.8
	if not Global.game_on or Global.game_over:
		return

	if _cooldown > 0.0:
		_cooldown -= delta
		return

	if _wave_running:
		_alive = _alive.filter(func(e): return is_instance_valid(e) and not e.destroyed)
		if _alive.is_empty():
			_finish_wave()
	elif not _spawning:
		_start_next_wave()


# --- wave flow -------------------------------------------------------------

func _start_next_wave() -> void:
	_spawning = true
	Global.wave += 1
	Global.damaged_this_wave = false
	var wave := Global.wave
	var is_boss := wave % BOSS_EVERY == 0

	wave_started.emit(wave)
	Sfx.play("boss_warn" if is_boss else "wave_start", -3.0)

	await _sleep(1.5)
	if not _active():
		return

	stage_ready.emit(wave)
	Sfx.play("wave_start", -9.0, 1.3)
	await _sleep(0.9)
	if not _active():
		return

	if is_boss:
		_spawn_boss(wave)
	else:
		await _spawn_formation(wave)
	if not _active():
		return

	_wave_running = true
	_spawning = false
	$DiveTimer.wait_time = maxf(1.0, 3.4 - wave * 0.16)
	$DiveTimer.start()


func _finish_wave() -> void:
	_wave_running = false
	$DiveTimer.stop()
	var wave := Global.wave
	wave_cleared.emit(wave)
	Sfx.play("wave_clear", -3.0)
	Global.award_bonus("WAVE CLEAR", 100 * wave)
	if not Global.damaged_this_wave:
		Global.award_bonus("NO DAMAGE", 250)
	_cooldown = 1.6


func _spawn_formation(wave: int) -> void:
	_build_layout(wave)
	var types := _pick_types(wave)
	var scale := 1.0 + (wave - 1) * 0.045
	_alive.clear()

	for i in _slots.size():
		if not _active():
			return
		var enemy = types[i].instantiate()
		enemy.formation = self
		enemy.slot_index = i
		enemy.speed_scale = scale
		_apply_difficulty(enemy, wave)
		add_child(enemy)
		enemy.begin_entry(_entry_path(i / SQUAD_SIZE))
		_alive.append(enemy)
		Sfx.play("enemy_spawn", -24.0, randf_range(0.9, 1.15))
		# tight gap inside a squad, longer one before the next enters
		await _sleep(0.35 if (i + 1) % SQUAD_SIZE == 0 else 0.09)


# Difficulty ramps one factor at a time: sweeping dives appear first, then
# faster shooting, then ordinary enemies start returning fire.
func _apply_difficulty(enemy: Node, wave: int) -> void:
	if wave >= 6 and randf() < 0.25:
		enemy.dive_pattern = "sweep"
	if enemy.shoots:
		enemy.shoot_interval = maxf(1.1, enemy.shoot_interval - (wave - 1) * 0.09)
	elif wave >= 7 and randf() < minf(0.06 * (wave - 6), 0.3):
		enemy.shoots = true
		enemy.shoot_interval = randf_range(2.8, 4.2)


func _spawn_boss(wave: int) -> void:
	_alive.clear()
	var boss = _boss.instantiate()
	boss.max_health = 26 + wave * 5
	add_child(boss)
	_alive.append(boss)
	boss_spawned.emit(boss)


# --- formation layouts -----------------------------------------------------

# Elites sit across the top centre, mid-tier below them, then wide rows of
# light enemies — the classic arcade block. It grows with the wave instead of
# changing shape every time.
func _build_layout(wave: int) -> void:
	_slots.clear()
	_tiers.clear()
	var cx := get_viewport_rect().size.x * 0.5
	var wide := clampi(8 + wave / 4, 8, 10)

	var plan := [
		[maxi(2, wide - 4), 2],
		[maxi(4, wide - 2), 1],
		[wide, 0],
		[wide, 0],
	]
	if wave >= 4:
		plan.append([wide, 0])

	for row in plan.size():
		var count: int = plan[row][0]
		var tier: int = plan[row][1]
		for c in count:
			_slots.append(Vector2(cx + (c - (count - 1) * 0.5) * COL_SPACING,
				FORMATION_TOP + row * ROW_SPACING))
			_tiers.append(tier)


func _pick_types(wave: int) -> Array:
	var out := []
	for tier in _tiers:
		match tier:
			2:
				out.append(_guard if wave >= 8 and randf() < 0.45 else _strong)
			1:
				out.append(_wasp if wave >= 4 and randf() < 0.45 else _fast)
			_:
				out.append(_basic)
	if wave >= 2 and not out.is_empty():
		out[randi() % out.size()] = _special
	return out


# Each squad flies one of four routes: sweep in low from a side, carve a full
# circle, then climb to the formation. Because the whole squad shares the route
# and enters a fraction of a second apart, they trail head-to-tail like a snake.
func _entry_path(route: int) -> PackedVector2Array:
	var screen := get_viewport_rect().size
	var from_left := route % 2 == 0
	var high := route < 2
	var side := -1.0 if from_left else 1.0
	var loop_centre := Vector2(screen.x * (0.34 if from_left else 0.66),
		screen.y * (0.44 if high else 0.56))
	var radius := 132.0

	var points := PackedVector2Array()
	points.append(Vector2(screen.x * 0.5 + side * (screen.x * 0.5 + 150.0), screen.y * 0.92))
	points.append(Vector2(screen.x * 0.5 + side * 120.0, screen.y * 0.84))
	points.append(loop_centre + Vector2(0.0, radius))

	# one full turn, sampled finely enough to read as a circle
	var turn := 1.0 if from_left else -1.0
	for i in range(1, 29):
		var angle := PI * 0.5 + turn * TAU * float(i) / 28.0
		points.append(loop_centre + Vector2(cos(angle), sin(angle)) * radius)

	points.append(Vector2(loop_centre.x - side * 60.0, screen.y * 0.26))
	return points


# --- slots (read by the enemies each frame) --------------------------------

func get_slot_base(index: int) -> Vector2:
	if index < 0 or index >= _slots.size():
		return Vector2(get_viewport_rect().size.x * 0.5, FORMATION_TOP)
	return _slots[index]


func get_slot_position(index: int) -> Vector2:
	return get_slot_base(index) + Vector2(sin(_sway) * 30.0, sin(_sway * 0.65) * 9.0)


# --- dives and ambient hazards ---------------------------------------------

func _on_dive_timer_timeout() -> void:
	if not _wave_running or not _active():
		return
	var ready := []
	for enemy in _alive:
		if is_instance_valid(enemy) and enemy.has_method("can_dive") and enemy.can_dive():
			ready.append(enemy)
	if ready.is_empty():
		return
	var divers := mini(1 + Global.wave / 4, 3)
	for i in divers:
		if ready.is_empty():
			break
		var pick = ready[randi() % ready.size()]
		ready.erase(pick)
		pick.start_dive()


func _on_meteor_timer_timeout() -> void:
	if not _wave_running or not _active():
		return
	# Boss waves stay clean so the fight reads clearly — power-ups only.
	var boss_wave := Global.wave % BOSS_EVERY == 0
	if boss_wave and randf() > 0.4:
		return
	var scene = _powerup if boss_wave or randf() < 0.18 else _meteor
	var new_node = scene.instantiate()
	new_node.position = Vector2(randf_range($lPoint.position.x, $rPoint.position.x), -100.0)
	add_child(new_node)


# --- helpers ---------------------------------------------------------------

func _active() -> bool:
	return is_inside_tree() and Global.game_on and not Global.game_over


func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
