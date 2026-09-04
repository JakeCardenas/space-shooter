extends Node2D

# Self-freeing explosion effect: an expanding ring plus a fading core.

@export var color := Color(1.0, 0.65, 0.2)
@export var radius := 60.0
@export var duration := 0.45

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta / duration
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var eased := 1.0 - pow(1.0 - _t, 2.0)
	var alpha := 1.0 - _t
	draw_circle(Vector2.ZERO, radius * eased, Color(color.r, color.g, color.b, alpha * 0.45))
	draw_arc(Vector2.ZERO, radius * eased * 1.15, 0.0, TAU, 48, Color(1, 1, 1, alpha * 0.8), 3.0, true)
	draw_circle(Vector2.ZERO, radius * (1.0 - _t) * 0.55, Color(1, 1, 0.88, alpha))
