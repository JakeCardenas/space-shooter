extends Node2D

# Attract mode. After a few seconds of no input on the title screen, squads of
# enemies drift across the background. Purely cosmetic — these are plain
# sprites, not real enemies, so they never touch the gameplay systems.

@export var idle_delay := 6.0
@export var squad_gap := 3.4

var _textures := [
	preload("res://art/enemy_one.svg"),
	preload("res://art/enemy_fast.svg"),
	preload("res://art/enemy_two.svg"),
	preload("res://art/enemy_special.svg"),
]

var _idle := 0.0
var _next := 0.0


func _input(_event: InputEvent) -> void:
	_idle = 0.0


func _process(delta: float) -> void:
	if Global.game_on:
		_clear()
		_idle = 0.0
		return

	_idle += delta
	if _idle < idle_delay:
		_clear()
		_next = 0.0
		return

	_next -= delta
	if _next <= 0.0:
		_next = squad_gap
		_spawn_squad()

	var screen := get_viewport_rect().size
	for child in get_children():
		var ship := child as Sprite2D
		var dir: float = ship.get_meta("dir")
		var base_y: float = ship.get_meta("base_y")
		var phase: float = ship.get_meta("phase")
		ship.position.x += dir * 210.0 * delta
		ship.position.y = base_y + sin(ship.position.x * 0.011 + phase) * 74.0
		if ship.position.x < -220.0 or ship.position.x > screen.x + 220.0:
			ship.queue_free()


func _spawn_squad() -> void:
	var screen := get_viewport_rect().size
	var texture: Texture2D = _textures[randi() % _textures.size()]
	var from_left := randf() < 0.5
	var base_y := randf_range(screen.y * 0.18, screen.y * 0.72)

	for i in 5:
		var ship := Sprite2D.new()
		ship.texture = texture
		ship.modulate = Color(1.0, 1.0, 1.0, 0.6)
		ship.rotation = -PI / 2.0 if from_left else PI / 2.0
		var offset := 82.0 * i
		ship.position = Vector2(-120.0 - offset if from_left else screen.x + 120.0 + offset, base_y)
		ship.set_meta("dir", 1.0 if from_left else -1.0)
		ship.set_meta("base_y", base_y)
		ship.set_meta("phase", i * 0.55)
		add_child(ship)


func _clear() -> void:
	for child in get_children():
		child.queue_free()
