extends Control

signal button_pressed
signal button_released

var _touch_index := -1
var _is_pressed := false

@onready var _button: Control = $Button


func _ready() -> void:
	_update_visual()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1:
				_touch_index = event.index
				_set_pressed(true)
		else:
			if event.index == _touch_index:
				_touch_index = -1
				_set_pressed(false)
	
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			var local_pos: Vector2 = event.position
			var is_inside := Rect2(Vector2.ZERO, size).has_point(local_pos)
			_set_pressed(is_inside)


func _set_pressed(pressed: bool) -> void:
	if _is_pressed != pressed:
		_is_pressed = pressed
		_update_visual()
		if pressed:
			button_pressed.emit()
		else:
			button_released.emit()


func _update_visual() -> void:
	if _button:
		_button.modulate = Color(1.2, 1.2, 1.2) if _is_pressed else Color.WHITE
		_button.scale = Vector2(0.95, 0.95) if _is_pressed else Vector2.ONE


func is_pressed() -> bool:
	return _is_pressed
