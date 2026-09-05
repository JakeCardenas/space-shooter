extends Node2D

# Wave manager. Builds a formation layout for each wave, flies the enemies in
# along curved entry paths, picks divers while the wave runs, and handles the
# gap between waves. Every fifth wave is a boss instead of a formation.

signal wave_started(wave: int)
signal stage_ready(wave: int)
signal wave_cleared(wave: int)
signal boss_spawned(boss: Node)
signal sector_started(sector: int)
signal challenge_started(wave: int)
signal challenge_finished(hits: int, total: int, perfect: bool)

const FORMATION_TOP := 200.0
const COL_SPACING := 78.0
const ROW_SPACING := 60.0
const BOSS_EVERY := 5
const SQUAD_SIZE := 6
const CHALLENGE_EVERY := 5
const CHALLENGE_OFFSET := 3

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
var _challenge := false
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
	_challenge = not is_boss and wave % CHALLENGE_EVERY == CHALLENGE_OFFSET

	if (wave - 1) % BOSS_EVERY == 0:
		sector_started.emit((wave - 1) / BOSS_EVERY + 1)
		Sfx.play("wave_start", -6.0, 0.75)
		await _sleep(1.1)
		if not _active():
			return

	if _challenge:
		challenge_started.emit(wave)
	else:
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
	elif _challenge:
		await _spawn_challenge(wave)
	else:
		await _spawn_formation(wave)
	if not _active():
		return

	_wave_running = true
	_spawning = false
	if not _challenge:
		$DiveTimer.wait_time = maxf(1.0, 3.4 - wave * 0.16)
		$DiveTimer.start()


func _finish_wave() -> void:
	_wave_running = false
	$DiveTimer.stop()
	var wave := Global.wave

	if _challenge:
		_challenge = false
		var hits := Global.challenge_hits
		var total := Global.challenge_total
		var perfect := total > 0 and hits >= total
		Global.challenge_active = false
		challenge_finished.emit(hits, total, perfect)
		Sfx.play("wave_clear", -3.0)
		Global.award_bonus("HITS %d/%d" % [hits, total], hits * 120)
		if perfect:
			Sfx.play("new_high_score", -5.0)
			Global.award_bonus("PERFECT", 3000)
		_cooldown = 2.4
		return

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


# Challenge stage: four squads trace a choreographed path across the screen and
# leave. Nothing shoots, nothing dives — it is purely a marksmanship round.
func _spawn_challenge(wave: int) -> void:
	_alive.clear()
	var squads := 4
	var per_squad := 6
	Global.challenge_active = true
	Global.challenge_hits = 0
	Global.challenge_total = squads * per_squad

	for squad in squads:
		var path := _challenge_path(squad, wave)
		for i in per_squad:
			if not _active():
				return
			var enemy = _challenge_type(squad).instantiate()
			enemy.formation = self
			enemy.pass_through = true
			enemy.formation_member = false
			enemy.shoots = false
			enemy.contact_damage = 0
			enemy.speed_scale = 1.0 + wave * 0.02
			enemy.entry_speed = 620.0
			add_child(enemy)
			enemy.begin_entry(path)
			_alive.append(enemy)
			Sfx.play("enemy_spawn", -24.0, randf_range(0.95, 1.2))
			await _sleep(0.16)
		await _sleep(0.9)


func _challenge_type(squad: int) -> PackedScene:
	match squad % 4:
		0:
			return _basic
		1:
			return _fast
		2:
			return _wasp
		_:
			return _special


# Four visually distinct routes: figure-eight, spiral, double arc, zigzag comb.
func _challenge_path(squad: int, wave: int) -> PackedVector2Array:
	var screen := get_viewport_rect().size
	var points := PackedVector2Array()
	var side := -1.0 if squad % 2 == 0 else 1.0
	var flip := 1.0 if (wave / CHALLENGE_EVERY) % 2 == 0 else -1.0
	side *= flip

	match squad % 4:
		0:
			# figure eight across the upper half
			for i in 65:
				var t := TAU * float(i) / 64.0
				points.append(Vector2(
					screen.x * 0.5 + side * sin(t) * screen.x * 0.36,
					screen.y * 0.34 + sin(t * 2.0) * screen.y * 0.16))
		1:
			# tightening spiral into the centre, then out of the bottom
			for i in 70:
				var t := float(i) / 69.0
				var a := t * TAU * 2.2
				var r := lerpf(screen.x * 0.42, 60.0, t)
				points.append(Vector2(screen.x * 0.5 + cos(a) * r * side,
					screen.y * 0.38 + sin(a) * r * 0.6))
			points.append(Vector2(screen.x * 0.5, screen.y + 160.0))
		2:
			# two stacked arcs sweeping the full width
			for i in 60:
				var t := float(i) / 59.0
				points.append(Vector2(
					lerpf(-120.0, screen.x + 120.0, t if side < 0.0 else 1.0 - t),
					screen.y * 0.28 + sin(t * PI * 2.0) * screen.y * 0.18))
		_:
			# zigzag comb down the screen
			for i in 26:
				var t := float(i) / 25.0
				points.append(Vector2(
					screen.x * 0.5 + side * cos(t * PI * 5.0) * screen.x * 0.4,
					lerpf(-100.0, screen.y + 140.0, t)))
	return points


func _spawn_boss(wave: int) -> void:
	_alive.clear()
	var boss = _boss.instantiate()
	boss.max_health = 26 + wave * 5
	add_child(boss)
	_alive.append(boss)
	boss_spawned.emit(boss)


# --- formation layouts -----------------------------------------------------

# Formation shapes. Every shape places elites nearest the top and light enemies
# on the outside, so the block always reads the same way however it is arranged.
func _build_layout(wave: int) -> void:
	_slots.clear()
	_tiers.clear()
	var cx := get_viewport_rect().size.x * 0.5
	var wide := clampi(8 + wave / 4, 8, 10)

	match _shape_for(wave):
		"vee":
			_shape_vee(cx, wide)
		"diamond":
			_shape_diamond(cx, wide)
		"arrow":
			_shape_arrow(cx, wide)
		"wave":
			_shape_rows(cx, wide, true, false)
		"staggered":
			_shape_rows(cx, wide, false, true)
		"arc":
			_shape_arc(cx, wide)
		_:
			_shape_rows(cx, wide, false, false)


func _shape_for(wave: int) -> String:
	if wave <= 2:
		return "block"
	const CYCLE := ["block", "vee", "wave", "arrow", "block", "staggered", "diamond", "arc"]
	return CYCLE[(wave - 3) % CYCLE.size()]


func _add(x: float, y: float, tier: int) -> void:
	_slots.append(Vector2(x, y))
	_tiers.append(tier)


func _row_plan(wide: int, wave: int) -> Array:
	var plan := [
		[maxi(2, wide - 4), 2],
		[maxi(4, wide - 2), 1],
		[wide, 0],
		[wide, 0],
	]
	if wave >= 4:
		plan.append([wide, 0])
	return plan


func _shape_rows(cx: float, wide: int, undulate: bool, stagger: bool) -> void:
	var plan := _row_plan(wide, Global.wave)
	for row in plan.size():
		var count: int = plan[row][0]
		var tier: int = plan[row][1]
		var shift := COL_SPACING * 0.5 if stagger and row % 2 == 1 else 0.0
		for c in count:
			var x := cx + (c - (count - 1) * 0.5) * COL_SPACING + shift
			var y := FORMATION_TOP + row * ROW_SPACING
			if undulate:
				y += sin(float(c) / maxf(1.0, count - 1.0) * PI * 2.0) * 22.0
			_add(x, y, tier)


func _shape_vee(cx: float, arm: int) -> void:
	_add(cx, FORMATION_TOP, 2)
	for i in range(1, arm + 1):
		var dx := i * COL_SPACING * 0.62
		var dy := i * ROW_SPACING * 0.55
		var tier := 2 if i <= 1 else (1 if i <= 3 else 0)
		_add(cx - dx, FORMATION_TOP + dy, tier)
		_add(cx + dx, FORMATION_TOP + dy, tier)


func _shape_arrow(cx: float, arm: int) -> void:
	_shape_vee(cx, arm)
	for i in range(1, 4):
		_add(cx, FORMATION_TOP + (i + 1) * ROW_SPACING * 0.62, 0)


func _shape_diamond(cx: float, wide: int) -> void:
	var half := maxi(2, wide / 2)
	for row in range(-half, half + 1):
		var count := half + 1 - absi(row)
		if count <= 0:
			continue
		var tier := 2 if absi(row) <= 1 else (1 if absi(row) <= 2 else 0)
		for c in count:
			_add(cx + (c - (count - 1) * 0.5) * COL_SPACING,
				FORMATION_TOP + (row + half) * ROW_SPACING * 0.62, tier)


func _shape_arc(cx: float, wide: int) -> void:
	var radius := 330.0
	for row in 3:
		var count := wide - row * 2
		if count <= 1:
			continue
		var tier := 2 if row == 0 else (1 if row == 1 else 0)
		for c in count:
			var a := lerpf(-0.82, 0.82, float(c) / maxf(1.0, count - 1.0))
			_add(cx + sin(a) * (radius - row * 34.0),
				FORMATION_TOP + (1.0 - cos(a)) * radius * 0.55 + row * ROW_SPACING * 0.85,
				tier)


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
	var base := get_slot_base(index)
	var centre := Vector2(get_viewport_rect().size.x * 0.5, FORMATION_TOP)
	# a slow pulse outward from the centre on top of the side-to-side sway
	var pulse := 1.0 + sin(_sway * 0.55) * 0.045
	return centre + (base - centre) * pulse \
		+ Vector2(sin(_sway) * 26.0, sin(_sway * 0.65) * 8.0)


# --- dives and ambient hazards ---------------------------------------------

func _on_dive_timer_timeout() -> void:
	if not _wave_running or not _active() or _challenge:
		return
	var ready := _ready_divers()
	if ready.is_empty():
		return

	if _try_capture_run(ready):
		return

	match _pick_plan(Global.wave):
		"pair":
			_attack_pair(ready)
		"squad":
			_attack_squad(ready)
		"pincer":
			_attack_pincer(ready)
		"cross":
			_attack_cross(ready)
		"feint":
			_attack_feint(ready)
		"escort":
			_attack_escort(ready)
		_:
			_attack_solo(ready)


func _ready_divers() -> Array:
	var out := []
	for enemy in _alive:
		if is_instance_valid(enemy) and enemy.has_method("can_dive") and enemy.can_dive():
			out.append(enemy)
	return out


# Attacks unlock gradually so early stages stay readable.
func _pick_plan(wave: int) -> String:
	var pool := ["solo"]
	if wave >= 3:
		pool.append_array(["pair", "pair"])
	if wave >= 5:
		pool.append_array(["squad", "feint"])
	if wave >= 7:
		pool.append_array(["pincer", "cross"])
	if wave >= 9:
		pool.append_array(["escort", "squad"])
	return pool[randi() % pool.size()]


func _by_x(list: Array) -> Array:
	var sorted := list.duplicate()
	sorted.sort_custom(func(a, b): return a.position.x < b.position.x)
	return sorted


func _attack_solo(ready: Array) -> void:
	ready[randi() % ready.size()].start_dive()


# Two neighbours peel off together and converge on the player.
func _attack_pair(ready: Array) -> void:
	var sorted := _by_x(ready)
	if sorted.size() < 2:
		_attack_solo(ready)
		return
	var i := randi() % (sorted.size() - 1)
	var target := _player_x()
	sorted[i].start_dive(target - 60.0)
	sorted[i + 1].start_dive(target + 60.0)


# Three from the same neighbourhood, one after another.
func _attack_squad(ready: Array) -> void:
	var sorted := _by_x(ready)
	var count := mini(3, sorted.size())
	var start := randi() % maxi(1, sorted.size() - count + 1)
	for i in count:
		if not _active():
			return
		sorted[start + i].start_dive()
		await _sleep(0.22)


# Outermost enemies on each flank close in from both sides.
func _attack_pincer(ready: Array) -> void:
	var sorted := _by_x(ready)
	if sorted.size() < 2:
		_attack_solo(ready)
		return
	var target := _player_x()
	sorted[0].start_dive(target)
	sorted[sorted.size() - 1].start_dive(target)


# Two divers swap sides on the way down.
func _attack_cross(ready: Array) -> void:
	var sorted := _by_x(ready)
	if sorted.size() < 2:
		_attack_solo(ready)
		return
	var left = sorted[0]
	var right = sorted[sorted.size() - 1]
	left.dive_pattern = "sweep"
	right.dive_pattern = "sweep"
	left.start_dive()
	right.start_dive()


func _attack_feint(ready: Array) -> void:
	var sorted := _by_x(ready)
	var bluffer = sorted[randi() % sorted.size()]
	bluffer.start_feint()
	await _sleep(0.5)
	if not _active():
		return
	var second := _ready_divers()
	if not second.is_empty():
		second[randi() % second.size()].start_dive()


# An elite dives with light enemies flanking it.
func _attack_escort(ready: Array) -> void:
	var elite = null
	for enemy in ready:
		if enemy.health >= 4 and (elite == null or enemy.health > elite.health):
			elite = enemy
	if elite == null:
		_attack_squad(ready)
		return

	var guards := []
	for enemy in _by_x(ready):
		if enemy != elite and absf(enemy.position.x - elite.position.x) < COL_SPACING * 2.5:
			guards.append(enemy)
		if guards.size() >= 2:
			break

	elite.start_dive()
	for guard in guards:
		guard.start_dive(elite.position.x + randf_range(-70.0, 70.0))


# One capture attempt at a time, and never while a ship is already held.
func _try_capture_run(ready: Array) -> bool:
	if Global.wave < 4 or Global.captured or _capture_active():
		return false
	if randf() > 0.3:
		return false
	for enemy in ready:
		if enemy.captures:
			enemy.start_capture()
			return true
	return false


func _capture_active() -> bool:
	for enemy in _alive:
		if is_instance_valid(enemy) and enemy.captures \
				and enemy.state in [enemy.State.WARN, enemy.State.HUNT, enemy.State.BEAM]:
			return true
	return false


func _player_x() -> float:
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		return player.global_position.x
	return get_viewport_rect().size.x * 0.5


func _on_meteor_timer_timeout() -> void:
	if not _wave_running or not _active() or _challenge:
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
