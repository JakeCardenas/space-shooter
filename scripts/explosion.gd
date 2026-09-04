extends Node2D

# Self-freeing explosion: expanding shockwave ring, a hot core, and shards
# that fly outward. Everything is drawn, so there are no assets to load.

@export var color := Color(1.0, 0.65, 0.2)
@export var radius := 60.0
@export var duration := 0.45
@export var shards := 8

var _t := 0.0
var _angles: PackedFloat32Array = PackedFloat32Array()
var _lengths: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	for i in shards:
		_angles.append(randf() * TAU)
		_lengths.append(randf_range(0.55, 1.15))


func _process(delta: float) -> void:
	_t += delta / duration
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var eased := 1.0 - pow(1.0 - _t, 2.2)
	var alpha := 1.0 - _t

	draw_circle(Vector2.ZERO, radius * eased, Color(color.r, color.g, color.b, alpha * 0.4))
	draw_arc(Vector2.ZERO, radius * eased * 1.2, 0.0, TAU, 40,
		Color(1, 1, 1, alpha * 0.85), 3.0, true)

	for i in _angles.size():
		var dir := Vector2.RIGHT.rotated(_angles[i])
		var near := dir * radius * eased * 0.65 * _lengths[i]
		var far := dir * radius * eased * 1.05 * _lengths[i]
		draw_line(near, far, Color(1.0, 0.85, 0.5, alpha), 2.5, true)

	draw_circle(Vector2.ZERO, radius * (1.0 - _t) * 0.6, Color(1, 1, 0.9, alpha))
