extends Node

signal shake_requested(strength: float)
signal combo_changed(combo: int, multiplier: int)
signal points_awarded(amount: int, world_position: Vector2, multiplier: int)
signal bonus_awarded(label: String, amount: int)
signal high_score_beaten

const SAVE_PATH := "user://highscore.save"
const COMBO_WINDOW := 2.2

var game_on := false
var game_over := false
var score := 0
var high_score := 0
var chosen_ship := 1
var mute := false

var wave := 0
var combo := 0
var new_high_score := false
var damaged_this_wave := false

var _combo_timer := 0.0
var _previous_high := 0


func _ready() -> void:
	load_high_score()


func reset_values() -> void:
	game_on = false
	game_over = false
	score = 0
	chosen_ship = 1
	wave = 0
	combo = 0
	new_high_score = false
	damaged_this_wave = false
	_combo_timer = 0.0
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
		save_high_score()
	if not new_high_score and _previous_high > 0 and score > _previous_high:
		new_high_score = true
		high_score_beaten.emit()


func shake(strength: float) -> void:
	shake_requested.emit(strength)


func set_mute(value: bool) -> void:
	mute = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), mute)


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
