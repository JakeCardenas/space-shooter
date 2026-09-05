extends Node2D

# Scrolling pixel starfield, drawn directly so it needs no textures. Stars are
# square and land on whole pixels, and a few of them twinkle in arcade colours.

const STAR_COLORS := [
	Color(1.0, 1.0, 1.0),
	Color(0.45, 0.85, 1.0),
	Color(1.0, 0.85, 0.35),
	Color(1.0, 0.42, 0.58),
	Color(0.5, 1.0, 0.6),
]

@export var star_count := 130
@export var scroll_speed := 1.0

var _positions: PackedVector2Array = PackedVector2Array()
var _speeds: PackedFloat32Array = PackedFloat32Array()
var _sizes: PackedFloat32Array = PackedFloat32Array()
var _alphas: PackedFloat32Array = PackedFloat32Array()
var _phases: PackedFloat32Array = PackedFloat32Array()
var _colors: PackedColorArray = PackedColorArray()
var _screen := Vector2(840, 1080)
var _t := 0.0


func _ready() -> void:
	_screen = get_viewport_rect().size
	for i in star_count:
		_positions.append(Vector2(randf() * _screen.x, randf() * _screen.y))
		_speeds.append(randf_range(20.0, 150.0))
		_sizes.append(3.0 if randf() < 0.72 else 6.0)
		_alphas.append(randf_range(0.3, 1.0))
		_phases.append(randf() * TAU)
		_colors.append(STAR_COLORS[randi() % STAR_COLORS.size()])


func _process(delta: float) -> void:
	if Global.game_over:
		return
	_t += delta
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
		var size := _sizes[i]
		var at := Vector2(snappedf(_positions[i].x, size), snappedf(_positions[i].y, size))
		var twinkle := 0.65 + 0.35 * sin(_t * 3.0 + _phases[i])
		var tint := _colors[i]
		tint.a = _alphas[i] * twinkle
		draw_rect(Rect2(at, Vector2(size, size)), tint)
