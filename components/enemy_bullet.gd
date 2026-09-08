extends Area2D

@export var speed := 400.0
@export var damage := 1

var direction := Vector2.DOWN


func _ready() -> void:
	rotation = direction.angle() - PI / 2.0


# Movement runs on the physics tick, not the render frame. _process delta
# varies with the frame rate, so a stall - a backgrounded tab, a GC pause -
# would step this far enough to skip clean through a hitbox between two
# collision checks. The physics step is a fixed 1/60s no matter what the
# renderer is doing.
func _physics_process(delta: float) -> void:
	if Global.game_over:
		return
	position += direction * speed * delta
	var screen := get_viewport_rect().size
	if position.y > screen.y + 80.0 or position.y < -80.0 \
			or position.x < -80.0 or position.x > screen.x + 80.0:
		queue_free()


func on_hit() -> void:
	queue_free()
