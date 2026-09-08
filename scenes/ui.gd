extends Node2D


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
	1: preload("res://art/ship1.png"),
	2: preload("res://art/ship2.png"),
	3: preload("res://art/ship3.png"),
}
const CURSOR_Y := {1: 424.0, 2: 476.0, 3: 528.0}
const SETTING_BUSES := ["Master", "Music", "SFX"]

@onready var _player: Area2D = $Player
@onready var _spawner: Node2D = $Spawner
@onready var _start_screen: Control = $CanvasLayer/startScreen
@onready var _ship_screen: Control = $CanvasLayer/shipScreen
@onready var _scores_screen: Control = $CanvasLayer/scoresScreen
@onready var _settings_screen: Control = $CanvasLayer/settingsScreen
@onready var _in_game_screen: Control = $CanvasLayer/inGameScreen
@onready var _game_over_screen: Control = $CanvasLayer/gameOverScreen
@onready var _touch_controls: CanvasLayer = $TouchControls
@onready var _initials_screen: Control = $CanvasLayer/initialsScreen
@onready var _initial_slots: Array[Label] = [
	$CanvasLayer/initialsScreen/slots/slot0,
	$CanvasLayer/initialsScreen/slots/slot1,
	$CanvasLayer/initialsScreen/slots/slot2,
]
@onready var _cursor: Label = $CanvasLayer/startScreen/MenuCursor
@onready var _title_preview: Sprite2D = $CanvasLayer/startScreen/ShipPreview
@onready var _title_items: Array[Button] = [
	$CanvasLayer/startScreen/ButtonPlay,
	$CanvasLayer/startScreen/ButtonShips,
	$CanvasLayer/startScreen/ButtonScores,
	$CanvasLayer/startScreen/ButtonSettings,
]
@onready var _ship_cursor: Label = $CanvasLayer/shipScreen/MenuCursor
@onready var _preview: Sprite2D = $CanvasLayer/shipScreen/ShipPreview
@onready var _settings_cursor: Label = $CanvasLayer/settingsScreen/MenuCursor
@onready var _settings_rows: Array[Control] = [
	$CanvasLayer/settingsScreen/LabelMaster,
	$CanvasLayer/settingsScreen/LabelMusic,
	$CanvasLayer/settingsScreen/LabelSfx,
	$CanvasLayer/settingsScreen/LabelScreen,
	$CanvasLayer/settingsScreen/ButtonBack,
]
@onready var _settings_values: Array[Label] = [
	$CanvasLayer/settingsScreen/ValueMaster,
	$CanvasLayer/settingsScreen/ValueMusic,
	$CanvasLayer/settingsScreen/ValueSfx,
	$CanvasLayer/settingsScreen/ValueScreen,
]
@onready var _wave_label: Label = $CanvasLayer/inGameScreen/LabelWave
@onready var _bonus_label: Label = $CanvasLayer/inGameScreen/LabelBonus
@onready var _combo_label: Label = $CanvasLayer/inGameScreen/LabelCombo
@onready var _boss_bar: Control = $CanvasLayer/inGameScreen/BossBar
@onready var _lives: Array[Sprite2D] = [
	$CanvasLayer/inGameScreen/lives/life1,
	$CanvasLayer/inGameScreen/lives/life2,
	$CanvasLayer/inGameScreen/lives/life3,
]

var _virtual_joystick: Control = null
var _fire_button: Control = null

var _floating_text := preload("res://scenes/floating_text.tscn")
var _game_over_shown := false
var _last_multiplier := 1
var _bonus_busy := false
var _bonus_queue: Array[String] = []
var _menu_time := 0.0
var _banner_tween: Tween = null
var _blink := 0.0
var _has_touch := false
var _screen := "title"
var _menu_index := 0
var _settings_index := 0


func _ready() -> void:
	_has_touch = DisplayServer.is_touchscreen_available()
	Global.reset_values()
	Global.set_mute(Global.mute)

	_show_menu("title")
	_in_game_screen.visible = false
	_game_over_screen.visible = false
	_initials_screen.visible = false
	_touch_controls.visible = false
	_wave_label.visible = false
	_bonus_label.visible = false
	_boss_bar.visible = false
	_combo_label.text = ""

	for button in _all_buttons():
		button.focus_mode = Control.FOCUS_NONE

	$PauseLayer.opened.connect(_hide_banner)
	Global.combo_changed.connect(_on_combo_changed)
	Global.points_awarded.connect(_on_points_awarded)
	Global.bonus_awarded.connect(_on_bonus_awarded)
	Global.high_score_beaten.connect(_on_high_score_beaten)
	_spawner.wave_started.connect(_on_wave_started)
	_spawner.stage_ready.connect(_on_stage_ready)
	_spawner.sector_started.connect(_on_sector_started)
	_spawner.challenge_started.connect(_on_challenge_started)
	_spawner.challenge_finished.connect(_on_challenge_finished)
	_spawner.wave_cleared.connect(_on_wave_cleared)
	_spawner.boss_spawned.connect(_on_boss_spawned)

	$CanvasLayer/startScreen/LabelHigh.text = str(Global.high_score)
	$CanvasLayer/startScreen/HeaderScore.text = str(Global.score)
	_update_ship_preview()
	_update_mute_labels()
	_update_help_text()
	_refresh_title_menu()
	_refresh_settings()
	_fill_ranking($CanvasLayer/scoresScreen/ranks)
	Music.play("menu")

	call_deferred("_setup_mobile_controls")
	if Global.restart_ship > 0:
		Global.chosen_ship = Global.restart_ship
		Global.restart_ship = 0
		call_deferred("_start_game")


func _all_buttons() -> Array:
	var buttons: Array = [
		$CanvasLayer/shipScreen/ButtonShipOne,
		$CanvasLayer/shipScreen/ButtonShipTwo,
		$CanvasLayer/shipScreen/ButtonShipThree,
		$CanvasLayer/shipScreen/ButtonBack,
		$CanvasLayer/scoresScreen/ButtonBack,
		$CanvasLayer/settingsScreen/ButtonBack,
		$CanvasLayer/inGameScreen/ButtonMute,
		$CanvasLayer/gameOverScreen/ButtonMenu,
	]
	buttons.append_array(_title_items)
	return buttons


func _unhandled_input(event: InputEvent) -> void:
	match _screen:
		"title":
			_title_input(event)
			return
		"ship":
			_ship_input(event)
			return
		"scores":
			if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
				_on_back_pressed()
			return
		"settings":
			_settings_input(event)
			return

	if _initials_screen.visible:
		if event.is_action_pressed("ui_up"):
			Global.cycle_initial(1)
			_refresh_initial_slots()
		elif event.is_action_pressed("ui_down"):
			Global.cycle_initial(-1)
			_refresh_initial_slots()
		elif event.is_action_pressed("ui_left"):
			Global.move_initial_cursor(-1)
			_refresh_initial_slots()
		elif event.is_action_pressed("ui_right"):
			Global.move_initial_cursor(1)
			_refresh_initial_slots()
		elif event.is_action_pressed("ui_accept"):
			_on_button_confirm_initials_pressed()
	elif _game_over_screen.visible and event.is_action_pressed("ui_accept"):
		_on_button_menu_pressed()


func _process(delta: float) -> void:
	if _screen != "":
		_menu_time += delta
		_animate_menu()
		return
	if _initials_screen.visible:
		_menu_time += delta
		_blink_initial_cursor()
		return
	if not Global.game_on:
		return

	_touch_controls.visible = _has_touch and not Global.game_over
	$CanvasLayer/inGameScreen/LabelScore.text = str(Global.score)
	$CanvasLayer/inGameScreen/LabelHigh.text = str(Global.high_score)
	$CanvasLayer/inGameScreen/LabelStage.text = "STAGE %d" % maxi(Global.wave, 1)
	_blink += delta
	$CanvasLayer/inGameScreen/Label1Up.modulate.a = 1.0 if fposmod(_blink, 1.0) < 0.6 else 0.0
	for i in _lives.size():
		_lives[i].modulate.a = 1.0 if i < _player.health else 0.15

	if Global.game_over and not _game_over_shown:
		_game_over_shown = true
		_show_game_over()


# --- menus -----------------------------------------------------------------

func _show_menu(name: String) -> void:
	_screen = name
	_start_screen.visible = name == "title"
	_ship_screen.visible = name == "ship"
	_scores_screen.visible = name == "scores"
	_settings_screen.visible = name == "settings"
	_menu_time = 0.0


func _animate_menu() -> void:
	var blink := 1.0 if fposmod(_menu_time, 0.7) < 0.45 else 0.15
	match _screen:
		"title":
			_cursor.modulate.a = blink
			_title_preview.scale = Vector2.ONE * (1.5 + sin(_menu_time * 5.0) * 0.04)
		"ship":
			_ship_cursor.modulate.a = blink
			_preview.scale = Vector2.ONE * (2.2 + sin(_menu_time * 5.0) * 0.06)
		"settings":
			_settings_cursor.modulate.a = blink


func _highlight(items: Array, index: int) -> void:
	for i in items.size():
		items[i].modulate = Color(1.0, 0.83, 0.36) if i == index else Color(0.86, 0.91, 1.0)


# --- title -----------------------------------------------------------------

func _title_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_move_title(-1)
	elif event.is_action_pressed("ui_down"):
		_move_title(1)
	elif event.is_action_pressed("ui_accept"):
		_activate_title()


func _move_title(step: int) -> void:
	_menu_index = wrapi(_menu_index + step, 0, _title_items.size())
	_menu_time = 0.0
	Sfx.play("click", -10.0)
	_refresh_title_menu()


func _refresh_title_menu() -> void:
	_cursor.position.y = _title_items[_menu_index].position.y
	_highlight(_title_items, _menu_index)


func _activate_title() -> void:
	match _menu_index:
		0: _start_game()
		1: _on_button_ships_pressed()
		2: _on_button_scores_pressed()
		3: _on_button_settings_pressed()


func _update_help_text() -> void:
	var help_label: Label = $CanvasLayer/startScreen/LabelHelp
	if DisplayServer.is_touchscreen_available():
		help_label.text = "SLIDE TO FLY     TAP FIRE TO SHOOT"
	else:
		help_label.text = "ARROWS OR A D MOVE\nSPACEBAR FIRES     ESC PAUSES"


# --- ship select -----------------------------------------------------------

func _ship_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_select_ship(Global.chosen_ship - 1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_select_ship(Global.chosen_ship + 1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _select_ship(index: int) -> void:
	Global.chosen_ship = wrapi(index, 1, 4)
	Global.save_settings()
	Sfx.play("click", -4.0)
	_update_ship_preview()


func _update_ship_preview() -> void:
	var ship: int = Global.chosen_ship
	$CanvasLayer/shipScreen/LabelStats.text = SHIP_BLURBS[ship]
	$CanvasLayer/startScreen/LabelShip.text = "SHIP   %s" % SHIP_NAMES[ship]
	_preview.texture = SHIP_TEXTURES[ship]
	_title_preview.texture = SHIP_TEXTURES[ship]
	var tween := create_tween()
	tween.tween_property(_ship_cursor, "position:y", CURSOR_Y[ship], 0.1) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- settings --------------------------------------------------------------

func _settings_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_move_settings(-1)
	elif event.is_action_pressed("ui_down"):
		_move_settings(1)
	elif event.is_action_pressed("ui_left"):
		_adjust_setting(-1)
	elif event.is_action_pressed("ui_right"):
		_adjust_setting(1)
	elif event.is_action_pressed("ui_accept"):
		if _settings_index == _settings_rows.size() - 1:
			_on_back_pressed()
		else:
			_adjust_setting(1)
	elif event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _move_settings(step: int) -> void:
	_settings_index = wrapi(_settings_index + step, 0, _settings_rows.size())
	_menu_time = 0.0
	Sfx.play("click", -10.0)
	_refresh_settings()


func _adjust_setting(step: int) -> void:
	if _settings_index < SETTING_BUSES.size():
		var bus: String = SETTING_BUSES[_settings_index]
		Global.set_volume(bus, snappedf(Global.volumes[bus] + step * 0.1, 0.1))
		Sfx.play("click", -10.0)
	elif _settings_index == SETTING_BUSES.size():
		Global.set_fullscreen(not Global.fullscreen)
		Sfx.play("click", -10.0)
	_refresh_settings()


func _refresh_settings() -> void:
	_settings_cursor.position.y = _settings_rows[_settings_index].position.y
	_highlight(_settings_rows, _settings_index)
	for i in SETTING_BUSES.size():
		_settings_values[i].text = _volume_bar(Global.volumes[SETTING_BUSES[i]])
	_settings_values[SETTING_BUSES.size()].text = \
		"FULLSCREEN" if Global.fullscreen else "WINDOW"
	_highlight(_settings_values, _settings_index)


func _volume_bar(value: float) -> String:
	var filled := roundi(clampf(value, 0.0, 1.0) * 10.0)
	return "[%s%s] %d" % ["#".repeat(filled), ".".repeat(10 - filled), filled]


# --- initials entry --------------------------------------------------------

func _refresh_initial_slots() -> void:
	var letters := Global.initial_letters()
	var cursor := Global.initial_cursor()
	for i in _initial_slots.size():
		_initial_slots[i].text = letters[i]
		var active := i == cursor
		_initial_slots[i].modulate = Color(1.0, 0.83, 0.36) if active else Color(0.6, 0.68, 0.82)


func _blink_initial_cursor() -> void:
	var cursor := Global.initial_cursor()
	var slot := _initial_slots[cursor]
	slot.modulate.a = 1.0 if fposmod(_menu_time, 0.6) < 0.4 else 0.25


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


func _hide_banner() -> void:
	if is_instance_valid(_banner_tween):
		_banner_tween.kill()
	_wave_label.visible = false
	_wave_label.modulate.a = 1.0


func _on_wave_started(wave: int) -> void:
	_banner("STAGE %d" % wave, Color(0.35, 0.85, 1.0), 0.75)


func _on_sector_started(sector: int) -> void:
	_banner("SECTOR %d" % sector, Color(0.6, 0.9, 1.0), 1.0)


func _on_challenge_started(_wave: int) -> void:
	_banner("CHALLENGE\nSTAGE", Color(1.0, 0.83, 0.36), 0.9)
	Music.play("challenge")


func _on_challenge_finished(hits: int, total: int, perfect: bool) -> void:
	Music.play("gameplay")
	if perfect:
		_banner("PERFECT!", Color(1.0, 0.83, 0.36), 1.1)
	else:
		_banner("%d / %d" % [hits, total], Color(0.35, 0.85, 1.0), 0.9)


func _on_stage_ready(wave: int) -> void:
	if wave % 5 == 0:
		_banner("WARNING\nELITE WAVE", Color(1.0, 0.3, 0.35), 0.45)
	elif Global.challenge_active or wave % 5 == 3:
		_banner("SHOOT THEM ALL", Color(1.0, 0.83, 0.36), 0.5)
	else:
		_banner("READY", Color(1.0, 0.3, 0.35), 0.35)


func _on_wave_cleared(_wave: int) -> void:
	_boss_bar.visible = false


func _on_boss_spawned(boss: Node) -> void:
	Music.play("boss")
	_boss_bar.visible = true
	$CanvasLayer/inGameScreen/BossBar/Fill.scale.x = 1.0
	$CanvasLayer/inGameScreen/BossBar/Fill.color = Color(1, 0.239216, 0.431373, 1)
	boss.health_changed.connect(func(fraction: float) -> void:
		if is_inside_tree():
			$CanvasLayer/inGameScreen/BossBar/Fill.scale.x = fraction)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.died.connect(func() -> void:
		if is_inside_tree():
			_boss_bar.visible = false
			Music.play("gameplay"))


const PHASE_BAR_COLORS := [
	Color(1, 0.239216, 0.431373, 1),
	Color(1, 0.6, 0.2, 1),
	Color(1, 0.85, 0.2, 1),
	Color(1, 0.15, 0.15, 1),
]
const PHASE_NAMES := ["", "PHASE 2", "PHASE 3", "ENRAGED"]

func _on_boss_phase_changed(phase: int) -> void:
	$CanvasLayer/inGameScreen/BossBar/Fill.color = PHASE_BAR_COLORS[phase]
	if phase > 0:
		_banner(PHASE_NAMES[phase], PHASE_BAR_COLORS[phase], 0.5)


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

	if Global.qualifies_for_leaderboard():
		Global.begin_initials_entry()
		$CanvasLayer/initialsScreen/LabelScore.text = "SCORE %d" % Global.score
		_refresh_initial_slots()
		_initials_screen.visible = true
		Music.play("high_score")
	else:
		_reveal_game_over()


func _on_button_confirm_initials_pressed() -> void:
	Sfx.play("new_high_score", -3.0)
	Global.submit_leaderboard_entry()
	_initials_screen.visible = false
	_reveal_game_over()


func _reveal_game_over() -> void:
	Music.play("game_over")
	$CanvasLayer/gameOverScreen/LabelScore.text = "SCORE %d" % Global.score
	$CanvasLayer/gameOverScreen/LabelWaveReached.text = "REACHED WAVE %d" % maxi(Global.wave, 1)
	_fill_ranking()
	_game_over_screen.visible = true


func _fill_ranking(container: Node = null) -> void:
	if container == null:
		container = $CanvasLayer/gameOverScreen/ranks
	var rows := Global.leaderboard
	for i in container.get_child_count():
		var label: Label = container.get_child(i)
		if i >= rows.size():
			label.text = ""
			continue
		var row: Dictionary = rows[i]
		label.text = "%2d %-4s %8d" % [i + 1, row["name"], row["score"]]
		label.modulate = Color(1.0, 0.83, 0.36) if i == Global.last_leaderboard_rank else Color(0.72, 0.79, 0.9)


func _update_mute_labels() -> void:
	$CanvasLayer/inGameScreen/ButtonMute.text = "MUTED" if Global.mute else "SOUND"


# --- button handlers -------------------------------------------------------

func _on_button_play_pressed() -> void:
	_start_game()


func _on_button_ships_pressed() -> void:
	Sfx.play("click", -8.0)
	_show_menu("ship")
	_update_ship_preview()


func _on_button_scores_pressed() -> void:
	Sfx.play("click", -8.0)
	_fill_ranking($CanvasLayer/scoresScreen/ranks)
	_show_menu("scores")


func _on_button_settings_pressed() -> void:
	Sfx.play("click", -8.0)
	_settings_index = 0
	_refresh_settings()
	_show_menu("settings")


func _on_back_pressed() -> void:
	Sfx.play("click", -8.0)
	_show_menu("title")
	_refresh_title_menu()


func _on_button_ship_one_pressed() -> void:
	_select_ship(1)


func _on_button_ship_two_pressed() -> void:
	_select_ship(2)


func _on_button_ship_three_pressed() -> void:
	_select_ship(3)


func _start_game() -> void:
	Sfx.play("wave_start", -6.0)
	_player.show_chosen_ship()
	for life in _lives:
		life.texture = SHIP_TEXTURES[Global.chosen_ship]
	_show_menu("")
	_in_game_screen.visible = true
	Global.game_on = true
	_banner("START", Color(1.0, 0.3, 0.35), 0.5)
	Music.play("gameplay")
	_show_mobile_controls(true)


func _on_button_mute_pressed() -> void:
	Global.set_mute(not Global.mute)
	_update_mute_labels()
	Sfx.play("click", -14.0)


func _on_button_menu_pressed() -> void:
	Global.reset_values()
	get_tree().reload_current_scene()


func _setup_mobile_controls() -> void:
	var joystick_scene := preload("res://scenes/virtual_joystick.tscn")
	var fire_button_scene := preload("res://scenes/fire_button.tscn")
	
	var is_mobile := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	
	if not is_mobile:
		is_mobile = DisplayServer.is_touchscreen_available()
	
	if is_mobile:
		_virtual_joystick = joystick_scene.instantiate()
		_virtual_joystick.position = Vector2(40, 880)
		_in_game_screen.add_child(_virtual_joystick)
		_virtual_joystick.visible = false
		
		_fire_button = fire_button_scene.instantiate()
		_fire_button.position = Vector2(660, 880)
		_in_game_screen.add_child(_fire_button)
		_fire_button.visible = false


func _show_mobile_controls(show: bool) -> void:
	if is_instance_valid(_virtual_joystick):
		_virtual_joystick.visible = show
	if is_instance_valid(_fire_button):
		_fire_button.visible = show
