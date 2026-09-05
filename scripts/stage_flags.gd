extends Node2D

# Arcade stage flags, drawn bottom-right: one large flag per ten waves and a
# small one for each wave after that. Drawn in code, so no textures needed.

const PIXEL := 3.0

var _shown := -1


func _process(_delta: float) -> void:
	if not Global.game_on:
		return
	if Global.wave != _shown:
		_shown = Global.wave
		queue_redraw()


func _draw() -> void:
	if not Global.game_on:
		return
	var x := 0.0
	for i in mini(Global.wave / 10, 6):
		x -= 30.0
		_flag(Vector2(x, 0.0), Color(0.29, 0.62, 1.0), Color(1, 1, 1), 1.0)
	for i in Global.wave % 10:
		x -= 20.0
		_flag(Vector2(x, 8.0), Color(1.0, 0.6, 0.07), Color(1.0, 0.88, 0.3), 0.7)


func _flag(at: Vector2, banner: Color, trim: Color, size: float) -> void:
	var p := PIXEL * size
	draw_rect(Rect2(at, Vector2(p, p * 9.0)), Color(0.72, 0.76, 0.85))
	draw_rect(Rect2(at + Vector2(p, 0.0), Vector2(p * 5.0, p * 4.0)), banner)
	draw_rect(Rect2(at + Vector2(p, p), Vector2(p * 5.0, p)), trim)
