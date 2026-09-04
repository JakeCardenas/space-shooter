extends Label

func setup(value: String, tint: Color) -> void:
	text = value
	modulate = tint


func _ready() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 70.0, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.9).set_delay(0.3)
	await tween.finished
	queue_free()
