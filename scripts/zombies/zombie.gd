class_name ZombieTownZombie
extends CharacterBody3D

signal died(zombie: ZombieTownZombie)

@export var max_health := 120.0
@export var move_speed := 2.2
@export var attack_damage := 20.0
@export var attack_range := 1.35
@export var attack_cooldown := 1.0
@export var turn_speed := 8.0

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var health := 120.0
var target: Node3D
var alive := true
var attack_remaining := 0.0

func _ready() -> void:
	add_to_group(&"zombie")
	health = max_health

func set_target(node: Node3D) -> void:
	target = node
	if navigation_agent != null and is_instance_valid(node):
		navigation_agent.target_position = node.global_position

func _physics_process(delta: float) -> void:
	if not alive:
		return

	if not is_on_floor():
		var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1

	attack_remaining = maxf(0.0, attack_remaining - delta)
	if target == null or not is_instance_valid(target):
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
		move_and_slide()
		return

	var offset: Vector3 = target.global_position - global_position
	var planar := Vector3(offset.x, 0.0, offset.z)
	var distance := planar.length()
	if distance > attack_range:
		var direction := _navigation_direction(planar)
		if is_on_wall():
			var wall_normal := get_wall_normal()
			wall_normal.y = 0.0
			if wall_normal.length_squared() > 0.001:
				var slide_direction := direction.slide(wall_normal.normalized())
				if slide_direction.length_squared() > 0.04:
					direction = slide_direction.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		var desired_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-delta * turn_speed))
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)
		if attack_remaining <= 0.0 and target.has_method("take_damage"):
			attack_remaining = attack_cooldown
			target.take_damage(attack_damage)

	move_and_slide()

func _navigation_direction(fallback_planar: Vector3) -> Vector3:
	var fallback := fallback_planar.normalized()
	if navigation_agent == null or target == null or not is_instance_valid(target):
		return fallback

	navigation_agent.max_speed = maxf(move_speed, 0.1)
	navigation_agent.target_position = target.global_position
	var next_position := navigation_agent.get_next_path_position()
	var path_delta := next_position - global_position
	path_delta.y = 0.0
	if path_delta.length_squared() > 0.01:
		return path_delta.normalized()
	return fallback

func is_headshot_point(world_point: Vector3) -> bool:
	return world_point.y > global_position.y + 1.38

func take_damage(amount: float, _headshot := false, _source: Node = null) -> Dictionary:
	if not alive:
		return {"killed": false}
	health -= amount
	if health > 0.0:
		return {"killed": false}
	alive = false
	died.emit(self)
	queue_free()
	return {"killed": true}
