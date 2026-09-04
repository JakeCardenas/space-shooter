extends Camera2D

@export var decay := 9.0
@export var max_strength := 26.0

var _strength := 0.0


func _ready() -> void:
	Global.shake_requested.connect(add_shake)
	make_current()


func add_shake(strength: float) -> void:
	_strength = minf(_strength + strength, max_strength)


func _process(delta: float) -> void:
	if _strength <= 0.05:
		_strength = 0.0
		offset = Vector2.ZERO
		return
	_strength = lerpf(_strength, 0.0, decay * delta)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _strength
