extends Area2D

# One shot fired by the player. Travels in a straight line until it hits
# something, leaves the screen, or its lifetime Timer runs out.

@export var speed := 950.0
@export var damage := 1
@export var pierce := false   ## true = keeps going after a hit (ZAP orb)

var direction := Vector2.UP


func _ready() -> void:
	# The sprites point up, so rotation 0 must mean Vector2.UP.
	rotation = direction.angle() + PI / 2.0


func _process(delta: float) -> void:
	if Global.game_over:
		return
	position += direction * speed * delta
	if position.y < -120.0 or position.y > get_viewport_rect().size.y + 120.0:
		queue_free()


func on_hit() -> void:
	# Called by the enemy that this laser struck.
	if not pierce:
		queue_free()


func _on_timer_timeout() -> void:
	queue_free()
