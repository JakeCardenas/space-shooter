extends Node2D

# Wave manager. Builds a formation layout for each wave, flies the enemies in
# along curved entry paths, picks divers while the wave runs, and handles the
# gap between waves. Every fifth wave is a boss instead of a formation.

signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal boss_spawned(boss: Node)

const FORMATION_TOP := 200.0
const COL_SPACING := 86.0
const ROW_SPACING := 74.0
const BOSS_EVERY := 5

var _basic := preload("res://components/enemy_one.tscn")
var _strong := preload("res://components/enemy_two.tscn")
var _fast := preload("res://components/enemy_fast.tscn")
var _special := preload("res://components/enemy_special.tscn")
var _boss := preload("res://components/boss.tscn")
var _meteor := preload("res://components/meteor.tscn")
var _powerup := preload("res://components/powerup.tscn")

var _slots: Array[Vector2] = []
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

	await _sleep(1.7)
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
	_slots = _build_layout(wave)
	var types := _pick_types(wave, _slots.size())
	var scale := 1.0 + (wave - 1) * 0.045
	_alive.clear()

	for i in _slots.size():
		if not _active():
			return
		var enemy = types[i].instantiate()
		enemy.formation = self
		enemy.slot_index = i
		enemy.speed_scale = scale
		add_child(enemy)
		enemy.begin_entry(_entry_path(i))
		_alive.append(enemy)
		Sfx.play("enemy_spawn", -24.0, randf_range(0.9, 1.15))
		await _sleep(0.085)


func _spawn_boss(wave: int) -> void:
	_alive.clear()
	var boss = _boss.instantiate()
	boss.max_health = 26 + wave * 5
	add_child(boss)
	_alive.append(boss)
	boss_spawned.emit(boss)


# --- formation layouts -----------------------------------------------------

func _build_layout(wave: int) -> Array[Vector2]:
	var cx := get_viewport_rect().size.x * 0.5
	match wave % 4:
		1:
			return _grid(cx, clampi(4 + wave / 2, 4, 7), clampi(2 + wave / 4, 2, 4))
		2:
			return _vee(cx, clampi(3 + wave / 3, 3, 5))
		3:
			return _arc(cx, clampi(6 + wave / 2, 6, 11))
		_:
			return _clusters(cx, clampi(2 + wave / 6, 2, 3))


func _grid(cx: float, cols: int, rows: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for r in rows:
		for c in cols:
			out.append(Vector2(cx + (c - (cols - 1) * 0.5) * COL_SPACING,
				FORMATION_TOP + r * ROW_SPACING))
	return out


func _vee(cx: float, arm: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.append(Vector2(cx, FORMATION_TOP))
	for i in range(1, arm + 1):
		var dx := i * COL_SPACING * 0.72
		var dy := i * ROW_SPACING * 0.6
		out.append(Vector2(cx - dx, FORMATION_TOP + dy))
		out.append(Vector2(cx + dx, FORMATION_TOP + dy))
	return out


func _arc(cx: float, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var radius := 300.0
	for i in count:
		var a := lerpf(-0.85, 0.85, float(i) / maxf(1.0, count - 1.0))
		out.append(Vector2(cx + sin(a) * radius,
			FORMATION_TOP + 20.0 + (1.0 - cos(a)) * radius * 0.75))
	return out


func _clusters(cx: float, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in count:
		var bx := cx + (k - (count - 1) * 0.5) * 215.0
		var by := FORMATION_TOP + float(k % 2) * 62.0
		for r in 2:
			for c in 2:
				out.append(Vector2(bx + (c - 0.5) * 72.0, by + r * 66.0))
	return out


func _pick_types(wave: int, count: int) -> Array:
	var out := []
	for i in count:
		var roll := randf()
		var scene = _basic
		if wave >= 2 and roll < 0.20 + wave * 0.01:
			scene = _fast
		elif wave >= 3 and roll > 0.80:
			scene = _strong
		out.append(scene)
	if wave >= 2 and count > 0:
		out[randi() % count] = _special
	return out


func _entry_path(i: int) -> Array:
	var w := get_viewport_rect().size.x
	match i % 4:
		0:
			return [Vector2(-140.0, 260.0), Vector2(w * 0.35, -80.0), Vector2(w * 0.85, 430.0)]
		1:
			return [Vector2(w + 140.0, 260.0), Vector2(w * 0.65, -80.0), Vector2(w * 0.15, 430.0)]
		2:
			return [Vector2(w * 0.25, -160.0), Vector2(-80.0, 400.0), Vector2(w * 0.75, 330.0)]
		_:
			return [Vector2(w * 0.75, -160.0), Vector2(w + 80.0, 400.0), Vector2(w * 0.25, 330.0)]


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
	var scene = _powerup if randf() < 0.18 else _meteor
	var new_node = scene.instantiate()
	new_node.position = Vector2(randf_range($lPoint.position.x, $rPoint.position.x), -100.0)
	add_child(new_node)


# --- helpers ---------------------------------------------------------------

func _active() -> bool:
	return is_inside_tree() and Global.game_on and not Global.game_over


func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
