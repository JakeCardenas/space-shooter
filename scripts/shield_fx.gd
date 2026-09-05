extends Node2D

# Pulsing ring drawn around a shielded ship. Purely cosmetic — the shield
# state itself lives on the owner.

var _t := 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := 26.0 + sin(_t * 6.0) * 3.0
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(0.3, 0.8, 1.0, 0.85), 3.0, true)
	draw_arc(Vector2.ZERO, r - 5.0, 0.0, TAU, 28, Color(0.3, 0.8, 1.0, 0.3), 2.0, true)
