extends Node2D

# Engine trail. top_level is on in the scene, so local space == world space.

@export var length := 16
@export var width := 10.0
@export var color := Color(0.45, 0.78, 1.0, 0.55)

var _points: PackedVector2Array = PackedVector2Array()


func _process(_delta: float) -> void:
	var ship: Node2D = get_parent()
	if not ship.visible:
		_points.clear()
		queue_redraw()
		return
	_points.insert(0, ship.global_position + Vector2(0, 26))
	while _points.size() > length:
		_points.remove_at(_points.size() - 1)
	queue_redraw()


func _draw() -> void:
	for i in range(1, _points.size()):
		var fade := 1.0 - float(i) / float(_points.size())
		draw_line(_points[i - 1], _points[i],
			Color(color.r, color.g, color.b, color.a * fade), width * fade, true)
