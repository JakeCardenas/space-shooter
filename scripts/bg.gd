extends Node2D

# Scrolling starfield, drawn directly so it needs no textures.

@export var star_count := 110
@export var scroll_speed := 1.0

var _positions: PackedVector2Array = PackedVector2Array()
var _speeds: PackedFloat32Array = PackedFloat32Array()
var _radii: PackedFloat32Array = PackedFloat32Array()
var _alphas: PackedFloat32Array = PackedFloat32Array()
var _screen := Vector2(720, 1280)


func _ready() -> void:
	_screen = get_viewport_rect().size
	for i in star_count:
		_positions.append(Vector2(randf() * _screen.x, randf() * _screen.y))
		_speeds.append(randf_range(18.0, 140.0))
		_radii.append(randf_range(0.8, 2.4))
		_alphas.append(randf_range(0.25, 0.95))


func _process(delta: float) -> void:
	if Global.game_over:
		return
	# The field drifts slowly on the menus and speeds up once you're playing.
	var boost := 1.0 if Global.game_on else 0.4
	for i in _positions.size():
		var pos := _positions[i]
		pos.y += _speeds[i] * boost * scroll_speed * delta
		if pos.y > _screen.y + 4.0:
			pos.y = -4.0
			pos.x = randf() * _screen.x
		_positions[i] = pos
	queue_redraw()


func _draw() -> void:
	for i in _positions.size():
		draw_circle(_positions[i], _radii[i], Color(0.85, 0.9, 1.0, _alphas[i]))
