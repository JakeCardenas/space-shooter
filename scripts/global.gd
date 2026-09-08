extends Node

signal shake_requested(strength: float)
signal combo_changed(combo: int, multiplier: int)
signal points_awarded(amount: int, world_position: Vector2, multiplier: int)
signal bonus_awarded(label: String, amount: int)
signal high_score_beaten

const SAVE_PATH := "user://highscore.save"
const LEADERBOARD_PATH := "user://leaderboard.save"
const SETTINGS_PATH := "user://settings.save"
const LEADERBOARD_SIZE := 10
const INITIAL_CHARSET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const COMBO_WINDOW := 2.2

# One grid for the whole playfield. Every enemy sits on a column and the ship
# steps between those same columns, so it is always dead centre under a target
# and never in the gap between two. Formations reach FORMATION_COLUMNS either
# side of the middle; the ship gets one more column of run-off past that.
const COLUMN_WIDTH := 78.0
const FORMATION_COLUMNS := 4
const PLAYER_COLUMNS := 5

# Mixing offsets baked into the bus layout. A slider at 1.0 keeps the intended
# balance; anything lower attenuates from there.
const BUS_BASE_DB := {"Master": 0.0, "Music": -12.0, "SFX": -10.0}

# Stand-in cabinet rankings so the board is never empty. The player's own best
# is merged in and marked, arcade style.
const RANKS := [
	["NOVA", 60000],
	["ORB", 38000],
	["VEX", 22000],
	["KAI", 12000],
	["ZED", 6000],
]

var game_on := false
var game_over := false
var score := 0
var high_score := 0
var chosen_ship := 1
var mute := false
var fullscreen := false
var shake_enabled := true
var auto_fire := false
var difficulty := 1                 ## 0 easy, 1 normal, 2 hard
var volumes := {"Master": 1.0, "Music": 1.0, "SFX": 1.0}
# Set before reloading the scene to drop straight back into a run.
var restart_ship := 0

var wave := 0
var combo := 0
var new_high_score := false
var damaged_this_wave := false
var captured := false
var challenge_active := false
var challenge_hits := 0
var challenge_total := 0
var shots_fired := 0
var shots_hit := 0

var leaderboard: Array = []
var last_leaderboard_rank := -1
var _initial_chars: Array[String] = ["A", "A", "A"]
var _initial_cursor := 0

var _combo_timer := 0.0
var _previous_high := 0


func _ready() -> void:
	load_high_score()
	load_leaderboard()
	load_settings()


func reset_values() -> void:
	game_on = false
	game_over = false
	score = 0
	wave = 0
	combo = 0
	new_high_score = false
	damaged_this_wave = false
	captured = false
	challenge_active = false
	challenge_hits = 0
	challenge_total = 0
	shots_fired = 0
	shots_hit = 0
	_combo_timer = 0.0
	Engine.time_scale = 1.0
	_previous_high = high_score


func _process(delta: float) -> void:
	if combo > 0 and game_on and not game_over:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo = 0
			combo_changed.emit(0, 1)


func combo_multiplier() -> int:
	return clampi(1 + combo / 3, 1, 8)


func register_kill(points: int, world_position: Vector2) -> void:
	if challenge_active:
		challenge_hits += 1
	combo += 1
	_combo_timer = COMBO_WINDOW
	var multiplier := combo_multiplier()
	var gained := points * multiplier
	add_score(gained)
	combo_changed.emit(combo, multiplier)
	points_awarded.emit(gained, world_position, multiplier)


func award_bonus(label: String, amount: int) -> void:
	add_score(amount)
	bonus_awarded.emit(label, amount)
	Sfx.play("bonus", -3.0)


func add_score(amount: int) -> void:
	score += amount
	if score > high_score:
		high_score = score
	if not new_high_score and _previous_high > 0 and score > _previous_high:
		new_high_score = true
		high_score_beaten.emit()


# --- Top 10 leaderboard -----------------------------------------------------

func load_leaderboard() -> void:
	leaderboard.clear()
	if FileAccess.file_exists(LEADERBOARD_PATH):
		var file := FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			if typeof(data) == TYPE_ARRAY:
				for row in data:
					if typeof(row) == TYPE_DICTIONARY and row.has("name") and row.has("score"):
						leaderboard.append({"name": str(row["name"]), "score": int(row["score"])})
	if leaderboard.is_empty():
		for row in RANKS:
			leaderboard.append({"name": row[0], "score": row[1]})
	_sort_leaderboard()


func _sort_leaderboard() -> void:
	leaderboard.sort_custom(func(a, b): return a["score"] > b["score"])
	if leaderboard.size() > LEADERBOARD_SIZE:
		leaderboard = leaderboard.slice(0, LEADERBOARD_SIZE)


func save_leaderboard() -> void:
	var file := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	if file:
		file.store_var(leaderboard)


func qualifies_for_leaderboard() -> bool:
	return leaderboard.size() < LEADERBOARD_SIZE or score > leaderboard[leaderboard.size() - 1]["score"]


func begin_initials_entry() -> void:
	_initial_chars = ["A", "A", "A"]
	_initial_cursor = 0


func cycle_initial(step: int) -> void:
	var idx := INITIAL_CHARSET.find(_initial_chars[_initial_cursor])
	idx = wrapi(idx + step, 0, INITIAL_CHARSET.length())
	_initial_chars[_initial_cursor] = INITIAL_CHARSET[idx]


func move_initial_cursor(step: int) -> void:
	_initial_cursor = clampi(_initial_cursor + step, 0, 2)


func initial_cursor() -> int:
	return _initial_cursor


func initial_letters() -> Array[String]:
	return _initial_chars


func initials_text() -> String:
	return _initial_chars[0] + _initial_chars[1] + _initial_chars[2]


func submit_leaderboard_entry() -> void:
	leaderboard.append({"name": initials_text(), "score": score})
	_sort_leaderboard()
	save_leaderboard()
	last_leaderboard_rank = -1
	for i in leaderboard.size():
		if leaderboard[i]["name"] == initials_text() and leaderboard[i]["score"] == score:
			last_leaderboard_rank = i
			break


func end_run() -> void:
	game_over = true
	save_high_score()


func _exit_tree() -> void:
	save_high_score()


func shake(strength: float) -> void:
	if shake_enabled:
		shake_requested.emit(strength)


# --- difficulty -------------------------------------------------------------

const DIFFICULTY_NAMES := ["EASY", "NORMAL", "HARD"]
const DIFFICULTY_LIVES := [4, 3, 2]
const DIFFICULTY_SPEED := [0.85, 1.0, 1.18]
const DIFFICULTY_DIVES := [1.35, 1.0, 0.78]   ## seconds between dives, scaled


func difficulty_name() -> String:
	return DIFFICULTY_NAMES[difficulty]


func starting_lives() -> int:
	return DIFFICULTY_LIVES[difficulty]


func enemy_speed_scale() -> float:
	return DIFFICULTY_SPEED[difficulty]


func dive_interval_scale() -> float:
	return DIFFICULTY_DIVES[difficulty]


# --- accuracy ---------------------------------------------------------------

# Counted per bolt, so a spread shot that lands two of three reads as two hits
# out of three fired. Pierce shots count every enemy they pass through.
func register_shot() -> void:
	shots_fired += 1


func register_hit() -> void:
	shots_hit += 1


func accuracy() -> float:
	if shots_fired <= 0:
		return 0.0
	return clampf(float(shots_hit) / float(shots_fired), 0.0, 1.0)


# Slows the whole game (bullets, enemies, everything) for `duration` real
# seconds, using a real-time timer so it self-corrects regardless of overlap.
func start_slowmo(duration: float, factor: float = 0.5) -> void:
	Engine.time_scale = factor
	var timer := get_tree().create_timer(duration, false, false, true)
	timer.timeout.connect(func() -> void: Engine.time_scale = 1.0)


# --- settings ---------------------------------------------------------------

func set_mute(value: bool) -> void:
	mute = value
	apply_volume("Master")
	save_settings()


func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	apply_volume(bus)
	save_settings()


func apply_volume(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var value: float = volumes[bus]
	AudioServer.set_bus_volume_db(index, BUS_BASE_DB[bus] + linear_to_db(maxf(value, 0.001)))
	AudioServer.set_bus_mute(index, value <= 0.0 or (bus == "Master" and mute))


func apply_settings() -> void:
	for bus in volumes:
		apply_volume(bus)
	# Browsers only grant fullscreen from a user gesture, so a saved value can
	# never be restored on boot — the page always starts windowed.
	if OS.has_feature("web"):
		fullscreen = false
	else:
		apply_fullscreen()


func apply_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen \
		else DisplayServer.WINDOW_MODE_WINDOWED)


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_fullscreen()
	save_settings()


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_var({
			"volumes": volumes,
			"mute": mute,
			"fullscreen": fullscreen,
			"ship": chosen_ship,
			"shake": shake_enabled,
			"auto_fire": auto_fire,
			"difficulty": difficulty,
		})


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			if typeof(data) == TYPE_DICTIONARY:
				if typeof(data.get("volumes")) == TYPE_DICTIONARY:
					for bus in volumes:
						if data["volumes"].has(bus):
							volumes[bus] = clampf(float(data["volumes"][bus]), 0.0, 1.0)
				mute = bool(data.get("mute", false))
				fullscreen = bool(data.get("fullscreen", false))
				chosen_ship = clampi(int(data.get("ship", 1)), 1, 3)
				shake_enabled = bool(data.get("shake", true))
				auto_fire = bool(data.get("auto_fire", false))
				difficulty = clampi(int(data.get("difficulty", 1)), 0, 2)
	apply_settings()


func save_high_score() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(high_score)


func load_high_score() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		high_score = file.get_32()
