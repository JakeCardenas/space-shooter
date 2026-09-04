extends Area2D

# Shared script for every falling object: enemy ships, meteors and power-ups.
# The differences live in the exported values, set per-scene in the editor.

@export var health := 1
@export var speed := 180.0
@export var score_value := 1
@export var kind := "ship"          ## "ship", "meteor" or "powerup"
@export var contact_damage := 1     ## health the player loses on collision
@export var weave_amplitude := 0.0  ## sideways drift, in pixels
@export var weave_speed := 2.0
@export var spin_speed := 0.0
@export var explosion_radius := 55.0

var destroyed := false

var _explosion := preload("res://scenes/explosion.tscn")
var _time := 0.0
var _start_x := 0.0


func _ready() -> void:
	_start_x = position.x
	_time = randf() * TAU


func _process(delta: float) -> void:
	if destroyed or not Global.game_on or Global.game_over:
		return

	_time += delta
	position.y += speed * delta
	if weave_amplitude > 0.0:
		position.x = _start_x + sin(_time * weave_speed) * weave_amplitude
	if spin_speed != 0.0:
		$Sprite2D.rotation += spin_speed * delta

	# Clean up once it has fallen past the bottom of the screen.
	if position.y > get_viewport_rect().size.y + 140.0:
		queue_free()


func take_damage(amount: int) -> void:
	if destroyed:
		return
	health -= amount
	if health <= 0:
		explode(true)
	else:
		_flash()


func explode(award_score: bool) -> void:
	if destroyed:
		return
	destroyed = true
	if award_score:
		Global.add_score(score_value)

	set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	speed = 0.0
	Sfx.play("explosion", -4.0, randf_range(0.9, 1.15))

	var boom = _explosion.instantiate()
	boom.radius = explosion_radius
	boom.color = Color(1.0, 0.55, 0.2) if kind != "meteor" else Color(0.8, 0.7, 0.55)
	get_parent().add_child(boom)
	boom.global_position = global_position

	var tween := create_tween().set_parallel(true)
	tween.tween_property($Sprite2D, "scale", $Sprite2D.scale * 1.6, 0.22)
	tween.tween_property($Sprite2D, "modulate", Color(1, 1, 1, 0), 0.22)
	await tween.finished
	queue_free()


func collect() -> void:
	# Power-ups are picked up rather than destroyed.
	if destroyed:
		return
	destroyed = true
	set_deferred("monitoring", false)
	queue_free()


func _flash() -> void:
	$Sprite2D.modulate = Color(4, 4, 4)
	var tween := create_tween()
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.14)


func _on_area_entered(area: Area2D) -> void:
	if destroyed:
		return
	# Power-ups ignore gunfire so you can't accidentally shoot them away.
	if kind != "powerup" and area.is_in_group("laser"):
		take_damage(area.damage)
		area.on_hit()
