extends CanvasLayer

signal opened

# Pause overlay. Sits on its own layer with process_mode ALWAYS so Escape and
# the menu keep responding while the rest of the tree is frozen.

@onready var _cursor: Label = $Panel/MenuCursor
@onready var _items: Array[Button] = [
	$Panel/ButtonResume,
	$Panel/ButtonRestart,
	$Panel/ButtonQuit,
]

# SPACE fires and is also Godot's default ui_accept, so a bolt fired on the
# same frame as ESC would instantly pick whatever the cursor is sitting on.
const ACCEPT_GUARD := 0.3

var _index := 0
var _blink := 0.0
var _opened_at := 0.0


func _ready() -> void:
	for button in _items:
		button.focus_mode = Control.FOCUS_NONE
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_blink += delta
	_cursor.modulate.a = 1.0 if fposmod(_blink, 0.7) < 0.45 else 0.15


func _unhandled_input(event: InputEvent) -> void:
	var action := ""
	for name in ["pause", "ui_cancel", "ui_up", "ui_down", "ui_accept"]:
		if event.is_action_pressed(name):
			action = name
			break
	if action == "":
		return

	if not visible:
		if action == "pause" and Global.game_on and not Global.game_over:
			get_viewport().set_input_as_handled()
			_open()
		return

	# Marked handled first: RESTART and QUIT free this node on the spot.
	get_viewport().set_input_as_handled()
	match action:
		"pause", "ui_cancel":
			_close()
		"ui_up":
			_move(-1)
		"ui_down":
			_move(1)
		"ui_accept":
			if Time.get_ticks_msec() - _opened_at >= ACCEPT_GUARD * 1000.0:
				_activate()


func _open() -> void:
	Sfx.play("click", -6.0)
	_index = 0
	_blink = 0.0
	_refresh()
	visible = true
	_opened_at = Time.get_ticks_msec()
	opened.emit()
	get_tree().paused = true


func _close() -> void:
	get_tree().paused = false
	visible = false
	Sfx.play("click", -10.0)


func _move(step: int) -> void:
	_index = wrapi(_index + step, 0, _items.size())
	_blink = 0.0
	_refresh()
	Sfx.play("click", -12.0)


func _refresh() -> void:
	_cursor.position.y = _items[_index].position.y
	for i in _items.size():
		_items[i].modulate = Color(1.0, 0.83, 0.36) if i == _index else Color(0.86, 0.91, 1.0)


func _activate() -> void:
	match _index:
		0: _close()
		1: _on_restart_pressed()
		2: _on_quit_pressed()


func _on_resume_pressed() -> void:
	_close()


func _on_restart_pressed() -> void:
	Global.restart_ship = Global.chosen_ship
	_reload()


func _on_quit_pressed() -> void:
	_reload()


func _reload() -> void:
	get_tree().paused = false
	visible = false
	Global.reset_values()
	get_tree().reload_current_scene()
