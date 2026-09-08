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


# Movement runs on the physics tick, not the render frame. _process delta
# varies with the frame rate, so a stall - a backgrounded tab, a GC pause -
# would step this far enough to skip clean through a hitbox between two
# collision checks. The physics step is a fixed 1/60s no matter what the
# renderer is doing.
func _physics_process(delta: float) -> void:
	if Global.game_over:
		return
	position += direction * speed * delta
	if position.y < -120.0 or position.y > get_viewport_rect().size.y + 120.0:
		queue_free()


func on_hit() -> void:
	# Called by the enemy that this laser struck. A pierce shot keeps going and
	# counts every enemy it passes through.
	Global.register_hit()
	if not pierce:
		queue_free()


func _on_timer_timeout() -> void:
	queue_free()
