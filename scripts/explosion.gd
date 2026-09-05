extends Node2D

# Self-freeing pixel explosion: a ring of blocks punching outward, chunky
# shards and a shrinking hot core. Everything snaps to a pixel grid so it
# matches the sprite art instead of looking like smooth vector smoke.

@export var color := Color(1.0, 0.65, 0.2)
@export var radius := 60.0
@export var duration := 0.45
@export var shards := 8
@export var pixel := 6.0

var _t := 0.0
var _angles: PackedFloat32Array = PackedFloat32Array()
var _lengths: PackedFloat32Array = PackedFloat32Array()
var _sizes: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	for i in shards:
		_angles.append(randf() * TAU)
		_lengths.append(randf_range(0.5, 1.2))
		_sizes.append(float(randi_range(1, 2)))


func _process(delta: float) -> void:
	_t += delta / duration
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var eased := 1.0 - pow(1.0 - _t, 2.2)
	var alpha := 1.0 - _t
	var ring := radius * eased

	for i in 16:
		var at := _snap(Vector2.RIGHT.rotated(TAU * float(i) / 16.0) * ring)
		draw_rect(Rect2(at, Vector2(pixel, pixel)), Color(1, 1, 1, alpha * 0.75))

	for i in _angles.size():
		var at := _snap(Vector2.RIGHT.rotated(_angles[i]) * ring * _lengths[i])
		var size := pixel * _sizes[i]
		draw_rect(Rect2(at, Vector2(size, size)),
			Color(color.r, color.g, color.b, alpha))

	var core := snappedf(radius * (1.0 - _t) * 0.8, pixel)
	if core >= pixel:
		draw_rect(Rect2(Vector2(-core, -core) * 0.5, Vector2(core, core)),
			Color(1.0, 1.0, 0.92, alpha))


func _snap(point: Vector2) -> Vector2:
	return Vector2(snappedf(point.x, pixel), snappedf(point.y, pixel))
