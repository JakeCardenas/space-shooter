extends Node2D

# Lives on the main scene. Owns the four screens, the HUD, the wave banner,
# the combo readout and the boss health bar.

const SHIP_NAMES := {
	1: "ACE",
	2: "TANK",
	3: "ZAP",
}
const SHIP_BLURBS := {
	1: "FAST SINGLE SHOT\nHIGH RATE OF FIRE",
	2: "TRIPLE SPREAD SHOT\nWIDE COVERAGE",
	3: "PIERCING PLASMA ORB\nSLOW BUT HEAVY",
}

@onready var _player: Area2D = $Player
@onready var _spawner: Node2D = $Spawner
@onready var _start_screen: Control = $CanvasLayer/startScreen
@onready var _choose_screen: Control = $CanvasLayer/chooseScreen
@onready var _in_game_screen: Control = $CanvasLayer/inGameScreen
@onready var _game_over_screen: Control = $CanvasLayer/gameOverScreen
@onready var _wave_label: Label = $CanvasLayer/inGameScreen/LabelWave
@onready var _bonus_label: Label = $CanvasLayer/inGameScreen/LabelBonus
@onready var _combo_label: Label = $CanvasLayer/inGameScreen/LabelCombo
@onready var _boss_bar: Control = $CanvasLayer/inGameScreen/BossBar
@onready var _lives: Array[TextureRect] = [
	$CanvasLayer/inGameScreen/lives/life1,
	$CanvasLayer/inGameScreen/lives/life2,
	$CanvasLayer/inGameScreen/lives/life3,
]

var _floating_text := preload("res://scenes/floating_text.tscn")
var _game_over_shown := false
var _last_multiplier := 1
var _bonus_busy := false
var _bonus_queue: Array[String] = []


func _ready() -> void:
	Global.reset_values()
	Global.set_mute(Global.mute)

	_start_screen.visible = true
	_choose_screen.visible = false
	_in_game_screen.visible = false
	_game_over_screen.visible = false
	_wave_label.visible = false
	_bonus_label.visible = false
	_boss_bar.visible = false
	_combo_label.text = ""

	Global.combo_changed.connect(_on_combo_changed)
	Global.points_awarded.connect(_on_points_awarded)
	Global.bonus_awarded.connect(_on_bonus_awarded)
	Global.high_score_beaten.connect(_on_high_score_beaten)
	_spawner.wave_started.connect(_on_wave_started)
	_spawner.wave_cleared.connect(_on_wave_cleared)
	_spawner.boss_spawned.connect(_on_boss_spawned)

	$CanvasLayer/startScreen/LabelBest.text = "BEST   %d" % Global.high_score
	_update_ship_preview()
	_update_mute_labels()


func _process(_delta: float) -> void:
	if not Global.game_on:
		return

	$CanvasLayer/inGameScreen/LabelScore.text = str(Global.score)
	$CanvasLayer/inGameScreen/LabelHigh.text = "HI   %d" % Global.high_score
	for i in _lives.size():
		_lives[i].modulate.a = 1.0 if i < _player.health else 0.18

	if Global.game_over and not _game_over_shown:
		_game_over_shown = true
		_show_game_over()


# --- waves -----------------------------------------------------------------

func _on_wave_started(wave: int) -> void:
	if wave % 5 == 0:
		_wave_label.text = "WARNING\nBOSS INCOMING"
		_wave_label.modulate = Color(1.0, 0.42, 0.48)
	else:
		_wave_label.text = "WAVE %d" % wave
		_wave_label.modulate = Color(0.86, 0.92, 1.0)

	_wave_label.visible = true
	_wave_label.scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.tween_property(_wave_label, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.75)
	tween.tween_property(_wave_label, "modulate:a", 0.0, 0.35)
	await tween.finished
	if not is_inside_tree():
		return
	_wave_label.visible = false
	_wave_label.modulate.a = 1.0


func _on_wave_cleared(_wave: int) -> void:
	_boss_bar.visible = false


func _on_boss_spawned(boss: Node) -> void:
	_boss_bar.visible = true
	$CanvasLayer/inGameScreen/BossBar/Fill.scale.x = 1.0
	boss.health_changed.connect(func(fraction: float) -> void:
		if is_inside_tree():
			$CanvasLayer/inGameScreen/BossBar/Fill.scale.x = fraction)
	boss.died.connect(func() -> void:
		if is_inside_tree():
			_boss_bar.visible = false)


# --- score feedback --------------------------------------------------------

func _on_combo_changed(combo: int, multiplier: int) -> void:
	if combo < 2:
		_combo_label.text = ""
		_last_multiplier = 1
		return

	_combo_label.text = "x%d   COMBO %d" % [multiplier, combo]
	if multiplier > _last_multiplier:
		Sfx.play("combo", -8.0, minf(1.0 + 0.09 * multiplier, 1.8))
		_combo_label.scale = Vector2(1.35, 1.35)
		var tween := create_tween()
		tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.2)
	_last_multiplier = multiplier


func _on_points_awarded(amount: int, world_position: Vector2, multiplier: int) -> void:
	if multiplier < 2 and amount < 20:
		return
	var label = _floating_text.instantiate()
	$FloatingTexts.add_child(label)
	label.position = world_position - Vector2(100.0, 22.0)
	label.setup("+%d" % amount,
		Color(1.0, 0.85, 0.35) if multiplier > 1 else Color(0.85, 0.92, 1.0))


func _on_bonus_awarded(label: String, amount: int) -> void:
	_bonus_queue.append("%s   +%d" % [label, amount])
	if not _bonus_busy:
		_play_bonus_queue()


func _play_bonus_queue() -> void:
	_bonus_busy = true
	while not _bonus_queue.is_empty():
		_bonus_label.text = _bonus_queue.pop_front()
		_bonus_label.visible = true
		_bonus_label.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_bonus_label, "modulate:a", 1.0, 0.18)
		tween.tween_interval(0.85)
		tween.tween_property(_bonus_label, "modulate:a", 0.0, 0.3)
		await tween.finished
		if not is_inside_tree():
			return
	_bonus_label.visible = false
	_bonus_busy = false


func _on_high_score_beaten() -> void:
	Sfx.play("new_high_score", -4.0)
	_on_bonus_awarded("NEW HIGH SCORE", 0)


# --- screens ---------------------------------------------------------------

func _show_game_over() -> void:
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	_in_game_screen.visible = false
	$CanvasLayer/gameOverScreen/LabelScore.text = "SCORE   %d" % Global.score
	$CanvasLayer/gameOverScreen/LabelBest.text = "BEST   %d" % Global.high_score
	$CanvasLayer/gameOverScreen/LabelWaveReached.text = "REACHED WAVE %d" % maxi(Global.wave, 1)
	$CanvasLayer/gameOverScreen/LabelNewBest.visible = Global.new_high_score
	_game_over_screen.visible = true


func _update_ship_preview() -> void:
	var ships := $CanvasLayer/chooseScreen/ships
	ships.get_node("shipOne").visible = Global.chosen_ship == 1
	ships.get_node("shipTwo").visible = Global.chosen_ship == 2
	ships.get_node("shipThree").visible = Global.chosen_ship == 3
	$CanvasLayer/chooseScreen/LabelShipName.text = SHIP_NAMES[Global.chosen_ship]
	$CanvasLayer/chooseScreen/LabelStats.text = SHIP_BLURBS[Global.chosen_ship]


func _update_mute_labels() -> void:
	$CanvasLayer/inGameScreen/ButtonMute.text = "MUTED" if Global.mute else "SOUND"


# --- button handlers -------------------------------------------------------

func _on_button_play_pressed() -> void:
	Sfx.play("click")
	_start_screen.visible = false
	_choose_screen.visible = true


func _on_button_ship_one_pressed() -> void:
	Global.chosen_ship = 1
	Sfx.play("click")
	_update_ship_preview()


func _on_button_ship_two_pressed() -> void:
	Global.chosen_ship = 2
	Sfx.play("click")
	_update_ship_preview()


func _on_button_ship_three_pressed() -> void:
	Global.chosen_ship = 3
	Sfx.play("click")
	_update_ship_preview()


func _on_button_choose_pressed() -> void:
	Sfx.play("click")
	_player.show_chosen_ship()
	_choose_screen.visible = false
	_in_game_screen.visible = true
	Global.game_on = true


func _on_button_mute_pressed() -> void:
	Global.set_mute(not Global.mute)
	_update_mute_labels()
	Sfx.play("click")


func _on_button_menu_pressed() -> void:
	Global.reset_values()
	get_tree().reload_current_scene()
