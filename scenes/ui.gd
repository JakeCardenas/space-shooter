extends Node2D

# Lives on the main scene. Owns the four screens (start / choose / in-game /
# game over) and keeps the HUD in sync with Global.

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
@onready var _start_screen: Control = $CanvasLayer/startScreen
@onready var _choose_screen: Control = $CanvasLayer/chooseScreen
@onready var _in_game_screen: Control = $CanvasLayer/inGameScreen
@onready var _game_over_screen: Control = $CanvasLayer/gameOverScreen
@onready var _lives: Array[TextureRect] = [
	$CanvasLayer/inGameScreen/lives/life1,
	$CanvasLayer/inGameScreen/lives/life2,
	$CanvasLayer/inGameScreen/lives/life3,
]

var _game_over_shown := false


func _ready() -> void:
	Global.reset_values()
	Global.set_mute(Global.mute)

	_start_screen.visible = true
	_choose_screen.visible = false
	_in_game_screen.visible = false
	_game_over_screen.visible = false

	_update_ship_preview()
	_update_mute_labels()


func _process(_delta: float) -> void:
	if not Global.game_on:
		return

	$CanvasLayer/inGameScreen/LabelScore.text = str(Global.score)
	for i in _lives.size():
		_lives[i].modulate.a = 1.0 if i < _player.health else 0.18

	if Global.game_over and not _game_over_shown:
		_game_over_shown = true
		_show_game_over()


func _show_game_over() -> void:
	await get_tree().create_timer(0.9).timeout
	_in_game_screen.visible = false
	$CanvasLayer/gameOverScreen/LabelScore.text = "SCORE   %d" % Global.score
	$CanvasLayer/gameOverScreen/LabelBest.text = "BEST   %d" % Global.high_score
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


# --- Button handlers -------------------------------------------------------

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
