extends Control

signal direction_changed(direction: Vector2)

@export var dead_zone := 0.15
@export var max_distance := 80.0
@export var return_speed := 20.0

var _touch_index := -1
var _center := Vector2.ZERO
var _current_direction := Vector2.ZERO

@onready var _base: Control = $Base
@onready var _knob: Control = $Knob


func _ready() -> void:
	_center = _base.position + _base.size / 2.0
	_knob.position = _center - _knob.size / 2.0


func _process(delta: float) -> void:
	if _touch_index == -1:
		if _current_direction.length() > 0.01:
			_current_direction = _current_direction.move_toward(Vector2.ZERO, return_speed * delta)
			_update_knob_position()
			direction_changed.emit(_current_direction)


# A finger that slides off the stick releases somewhere else entirely, so the
# touch-up never reaches _gui_input and the stick would stay held. Watch every
# release for the finger we own, wherever it lands.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed \
			and event.index == _touch_index:
		_release()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release()


func _release() -> void:
	_touch_index = -1
	_current_direction = Vector2.ZERO
	direction_changed.emit(_current_direction)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1:
				_touch_index = event.index
				_update_direction(event.position)
		else:
			if event.index == _touch_index:
				_release()
	
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_direction(event.position)


func _update_direction(touch_pos: Vector2) -> void:
	var offset := touch_pos - _center
	var distance := offset.length()
	
	if distance > max_distance:
		offset = offset.normalized() * max_distance
		distance = max_distance
	
	_current_direction = offset / max_distance
	
	if _current_direction.length() < dead_zone:
		_current_direction = Vector2.ZERO
	else:
		_current_direction = (_current_direction - _current_direction.normalized() * dead_zone) / (1.0 - dead_zone)
	
	_update_knob_position()
	direction_changed.emit(_current_direction)


func _update_knob_position() -> void:
	var knob_offset := _current_direction * max_distance
	_knob.position = _center + knob_offset - _knob.size / 2.0


func get_direction() -> Vector2:
	return _current_direction


func is_active() -> bool:
	return _touch_index != -1
