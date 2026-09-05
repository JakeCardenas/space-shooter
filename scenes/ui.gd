extends Node2D

# Lives on the main scene. Owns the attract/select screen, the arcade HUD, the
# wave banner, the combo readout, the boss bar and the game over board.

const SHIP_NAMES := {
	1: "ACE",
	2: "TANK",
	3: "ZAP",
}
const SHIP_BLURBS := {
	1: "FAST SINGLE BOLT\nHIGH RATE OF FIRE",
	2: "TRIPLE SPREAD SHOT\nWIDE COVERAGE",
	3: "PIERCING PLASMA ORB\nSLOW BUT HEAVY",
}
const SHIP_TEXTURES := {
	1: preload("res://art/ship1.svg"),
	2: preload("res://art/ship2.svg"),
	3: preload("res://art/ship3.svg"),
}
const CURSOR_Y := {1: 424.0, 2: 476.0, 3: 528.0}

@onready var _player: Area2D = $Player
@onready var _spawner: Node2D = $Spawner
@onready var _start_screen: Control = $CanvasLayer/startScreen
@onready var _in_game_screen: Control = $CanvasLayer/inGameScreen
@onready var _game_over_screen: Control = $CanvasLayer/gameOverScreen
@onready var _cursor: Label = $CanvasLayer/startScreen/MenuCursor
@onready var _preview: Sprite2D = $CanvasLayer/startScreen/ShipPreview
@onready var _wave_label: Label = $CanvasLayer/inGameScreen/LabelWave
@onready var _bonus_label: Label = $CanvasLayer/inGameScreen/LabelBonus
@onready var _combo_label: Label = $CanvasLayer/inGameScreen/LabelCombo
@onready var _boss_bar: Control = $CanvasLayer/inGameScreen/BossBar
@onready var _lives: Array[Sprite2D] = [
	$CanvasLayer/inGameScreen/lives/life1,
	$CanvasLayer/inGameScreen/lives/life2,
	$CanvasLayer/inGameScreen/lives/life3,
]

var _floating_text := preload("res://scenes/floating_text.tscn")
var _game_over_shown := false
var _last_multiplier := 1
var _bonus_busy := false
var _bonus_queue: Array[String] = []
var _menu_time := 0.0
var _banner_tween: Tween = null
var _blink := 0.0


func _ready() -> void:
	Global.reset_values()
	Global.set_mute(Global.mute)

	_start_screen.visible = true
	_in_game_screen.visible = false
	_game_over_screen.visible = false
	_wave_label.visible = false
	_bonus_label.visible = false
	_boss_bar.visible = false
	_combo_label.text = ""

	# Buttons must not hold focus, or ENTER would re-press the last one clicked
	# instead of starting the game.
	for button in _all_buttons():
		button.focus_mode = Control.FOCUS_NONE

	Global.combo_changed.connect(_on_combo_changed)
	Global.points_awarded.connect(_on_points_awarded)
	Global.bonus_awarded.connect(_on_bonus_awarded)
	Global.high_score_beaten.connect(_on_high_score_beaten)
	_spawner.wave_started.connect(_on_wave_started)
	_spawner.stage_ready.connect(_on_stage_ready)
	_spawner.wave_cleared.connect(_on_wave_cleared)
	_spawner.boss_spawned.connect(_on_boss_spawned)

	$CanvasLayer/startScreen/LabelHigh.text = str(Global.high_score)
	$CanvasLayer/startScreen/HeaderScore.text = str(Global.score)
	_update_ship_preview()
	_update_mute_labels()
	_flash_start_button()


func _all_buttons() -> Array:
	return [
		$CanvasLayer/startScreen/ButtonShipOne,
		$CanvasLayer/startScreen/ButtonShipTwo,
		$CanvasLayer/startScreen/ButtonShipThree,
		$CanvasLayer/startScreen/ButtonChoose,
		$CanvasLayer/inGameScreen/ButtonMute,
		$CanvasLayer/gameOverScreen/ButtonMenu,
	]


func _unhandled_input(event: InputEvent) -> void:
	if _start_screen.visible:
		if event.is_action_pressed("ui_accept"):
			_on_button_choose_pressed()
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
			_select_ship(Global.chosen_ship - 1)
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
			_select_ship(Global.chosen_ship + 1)
	elif _game_over_screen.visible and event.is_action_pressed("ui_accept"):
		_on_button_menu_pressed()


func _process(delta: float) -> void:
	if _start_screen.visible:
		_menu_time += delta
		_animate_selection()
		return
	if not Global.game_on:
		return

	$CanvasLayer/inGameScreen/LabelScore.text = str(Global.score)
	$CanvasLayer/inGameScreen/LabelHigh.text = str(Global.high_score)
	_blink += delta
	$CanvasLayer/inGameScreen/Label1Up.modulate.a = 1.0 if fposmod(_blink, 1.0) < 0.6 else 0.0
	for i in _lives.size():
		_lives[i].modulate.a = 1.0 if i < _player.health else 0.15

	if Global.game_over and not _game_over_shown:
		_game_over_shown = true
		_show_game_over()


# --- title screen ----------------------------------------------------------

func _animate_selection() -> void:
	_preview.scale = Vector2.ONE * (2.0 + sin(_menu_time * 5.0) * 0.07)
	_cursor.modulate.a = 1.0 if fposmod(_menu_time, 0.7) < 0.45 else 0.15


func _flash_start_button() -> void:
	var button: Button = $CanvasLayer/startScreen/ButtonChoose
	var tween := create_tween().set_loops()
	tween.tween_property(button, "modulate:a", 0.25, 0.45)
	tween.tween_property(button, "modulate:a", 1.0, 0.45)


func _select_ship(index: int) -> void:
	Global.chosen_ship = wrapi(index, 1, 4)
	Sfx.play("click", -4.0)
	_update_ship_preview()


func _update_ship_preview() -> void:
	$CanvasLayer/startScreen/LabelStats.text = SHIP_BLURBS[Global.chosen_ship]
	_preview.texture = SHIP_TEXTURES[Global.chosen_ship]
	var tween := create_tween()
	tween.tween_property(_cursor, "position:y", CURSOR_Y[Global.chosen_ship], 0.1) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- waves -----------------------------------------------------------------

func _banner(text: String, tint: Color, hold: float) -> void:
	if is_instance_valid(_banner_tween):
		_banner_tween.kill()
	_wave_label.text = text
	_wave_label.modulate = tint
	_wave_label.visible = true
	_wave_label.scale = Vector2(0.6, 0.6)
	_banner_tween = create_tween()
	_banner_tween.tween_property(_wave_label, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_wave_label, "modulate:a", 0.0, 0.25)
	_banner_tween.tween_callback(func() -> void:
		_wave_label.visible = false
		_wave_label.modulate.a = 1.0)


func _on_wave_started(wave: int) -> void:
	_banner("STAGE %d" % wave, Color(0.35, 0.85, 1.0), 0.75)


func _on_stage_ready(wave: int) -> void:
	if wave % 5 == 0:
		_banner("WARNING\nELITE WAVE", Color(1.0, 0.3, 0.35), 0.45)
	else:
		_banner("READY", Color(1.0, 0.3, 0.35), 0.35)


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
	if multiplier < 2:
		_combo_label.text = ""
		_last_multiplier = 1
		return

	_combo_label.text = "COMBO X%d" % multiplier
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
	_bonus_queue.append("%s +%d" % [label, amount] if amount > 0 else label)
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
	$CanvasLayer/gameOverScreen/LabelScore.text = "SCORE %d" % Global.score
	$CanvasLayer/gameOverScreen/LabelWaveReached.text = "REACHED WAVE %d" % maxi(Global.wave, 1)
	$CanvasLayer/gameOverScreen/LabelNewBest.visible = Global.new_high_score
	_fill_ranking()
	_game_over_screen.visible = true


func _fill_ranking() -> void:
	var rows := Global.ranking()
	for i in rows.size():
		var row: Array = rows[i]
		var label: Label = $CanvasLayer/gameOverScreen/ranks.get_child(i)
		label.text = "%d  %-4s %7d" % [i + 1, row[0], row[1]]
		label.modulate = Color(1.0, 0.83, 0.36) if row[0] == "YOU" else Color(0.72, 0.79, 0.9)


func _update_mute_labels() -> void:
	$CanvasLayer/inGameScreen/ButtonMute.text = "MUTED" if Global.mute else "SOUND"


# --- button handlers -------------------------------------------------------

func _on_button_ship_one_pressed() -> void:
	_select_ship(1)


func _on_button_ship_two_pressed() -> void:
	_select_ship(2)


func _on_button_ship_three_pressed() -> void:
	_select_ship(3)


func _on_button_choose_pressed() -> void:
	Sfx.play("wave_start", -6.0)
	_player.show_chosen_ship()
	for life in _lives:
		life.texture = SHIP_TEXTURES[Global.chosen_ship]
	_start_screen.visible = false
	_in_game_screen.visible = true
	Global.game_on = true
	_banner("START", Color(1.0, 0.3, 0.35), 0.5)


func _on_button_mute_pressed() -> void:
	Global.set_mute(not Global.mute)
	_update_mute_labels()
	Sfx.play("click")


func _on_button_menu_pressed() -> void:
	Global.reset_values()
	get_tree().reload_current_scene()
