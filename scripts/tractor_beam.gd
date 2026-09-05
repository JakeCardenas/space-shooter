extends Node2D

# Original capture beam: a widening pixel cone with scan bands sliding down it.
# The enemy that owns it asks contains() to decide whether the player is held.

const HALF_ANGLE := 0.30

var length := 460.0
var strength := 0.0

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func contains(point: Vector2) -> bool:
	if strength <= 0.05:
		return false
	var local := to_local(point)
	if local.y <= 0.0 or local.y > length * strength:
		return false
	return absf(local.x) <= local.y * tan(HALF_ANGLE)


func _draw() -> void:
	if strength <= 0.01:
		return
	var reach := length * strength
	var spread := reach * tan(HALF_ANGLE)

	draw_colored_polygon(
		PackedVector2Array([Vector2(-6, 0), Vector2(6, 0),
			Vector2(spread, reach), Vector2(-spread, reach)]),
		Color(0.75, 0.35, 1.0, 0.18 * strength))

	# scan bands, snapped to a pixel step so they stay chunky
	var step := 26.0
	var offset := fposmod(_t * 150.0, step)
	var y := offset
	while y < reach:
		var w := y * tan(HALF_ANGLE)
		var fade := (1.0 - y / reach) * strength
		draw_rect(Rect2(-w, snappedf(y, 4.0), w * 2.0, 4.0),
			Color(0.95, 0.7, 1.0, 0.55 * fade))
		y += step

	var edge := Color(0.85, 0.45, 1.0, 0.8 * strength)
	draw_line(Vector2(-6, 0), Vector2(-spread, reach), edge, 3.0)
	draw_line(Vector2(6, 0), Vector2(spread, reach), edge, 3.0)
