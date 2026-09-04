extends Area2D

# Mini-boss. Holds the top of the screen, sweeps side to side and rotates
# through three attack patterns. Uses the same take_damage / explode interface
# as enemy.gd so lasers and player collisions work unchanged.

signal health_changed(fraction: float)
signal died

@export var max_health := 40
@export var score_value := 400
@export var contact_damage := 2
@export var dies_on_contact := false

var health := 0
var destroyed := false

var _bullet := preload("res://components/enemy_bullet.tscn")
var _explosion := preload("res://scenes/explosion.tscn")
var _powerup := preload("res://components/powerup.tscn")

var _t := 0.0
var _pattern := 0
var _pattern_timer := 5.0
var _shoot_timer := 1.4
var _entering := true
var _hover_y := 250.0
var _center_x := 360.0


func _ready() -> void:
	health = max_health
	_center_x = get_viewport_rect().size.x * 0.5
	position = Vector2(_center_x, -160.0)
	health_changed.emit(1.0)


func _process(delta: float) -> void:
	if destroyed or not Global.game_on or Global.game_over:
		return

	_t += delta

	if _entering:
		position.y = move_toward(position.y, _hover_y, 190.0 * delta)
		if absf(position.y - _hover_y) < 1.0:
			_entering = false
		return

	position.x = _center_x + sin(_t * 0.7) * 200.0
	position.y = _hover_y + sin(_t * 1.3) * 18.0

	_pattern_timer -= delta
	if _pattern_timer <= 0.0:
		_pattern = (_pattern + 1) % 3
		_pattern_timer = 5.0

	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_fire_pattern()


func _fire_pattern() -> void:
	match _pattern:
		0:
			for angle in [-0.5, -0.25, 0.0, 0.25, 0.5]:
				_spawn_bullet(Vector2.DOWN.rotated(angle))
			_shoot_timer = 1.5
		1:
			var direction := Vector2.DOWN
			var player := get_tree().get_first_node_in_group("player")
			if is_instance_valid(player):
				direction = (player.global_position - global_position).normalized()
			for i in 3:
				_spawn_bullet(direction.rotated(randf_range(-0.14, 0.14)))
			_shoot_timer = 1.2
		_:
			_spawn_bullet(Vector2.DOWN.rotated(sin(_t * 2.2) * 0.7))
			_shoot_timer = 0.17
	Sfx.play_varied("enemy_shoot", -14.0, 0.12)


func _spawn_bullet(direction: Vector2) -> void:
	var bullet = _bullet.instantiate()
	bullet.direction = direction
	bullet.speed = 430.0
	get_parent().add_child(bullet)
	bullet.global_position = global_position + Vector2(0.0, 60.0)


func take_damage(amount: int) -> void:
	if destroyed:
		return
	health -= amount
	health_changed.emit(clampf(float(health) / float(max_health), 0.0, 1.0))
	if health <= 0:
		explode(true)
		return
	$Sprite2D.modulate = Color(3, 3, 3)
	var tween := create_tween()
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.1)


func explode(award_score: bool) -> void:
	if destroyed:
		return
	destroyed = true
	set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	Sfx.play("boss_explosion", -2.0)
	Global.shake(22.0)
	if award_score:
		Global.register_kill(score_value, global_position)
		Global.award_bonus("BOSS DEFEATED", 1000)
	died.emit()

	for i in 7:
		if not is_inside_tree():
			return
		var boom = _explosion.instantiate()
		boom.radius = randf_range(60.0, 130.0)
		boom.duration = 0.6
		boom.shards = 12
		get_parent().add_child(boom)
		boom.global_position = global_position + Vector2(randf_range(-95.0, 95.0), randf_range(-50.0, 50.0))
		$Sprite2D.modulate = Color(1, 1, 1, 1.0 - float(i) / 7.0)
		await get_tree().create_timer(0.09).timeout

	if is_inside_tree():
		var drop = _powerup.instantiate()
		drop.position = position
		get_parent().call_deferred("add_child", drop)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if destroyed:
		return
	if area.is_in_group("laser"):
		take_damage(area.damage)
		area.on_hit()
