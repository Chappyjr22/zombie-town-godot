class_name ZombieTownPlayerMelee
extends Node

signal melee_state_changed(attacking: bool)

const MELEE_DAMAGE := 150.0
const MELEE_RANGE := 2.2
const MELEE_RECOVERY := 0.75
const MELEE_HIT_TIME := 0.14

var player: ZombieTownGameplayPlayer
var camera: Camera3D
var knife_root: Node3D
var attacking := false
var attack_elapsed := 0.0
var hit_resolved := false

func _ready() -> void:
	player = get_parent() as ZombieTownGameplayPlayer
	if player == null:
		set_process(false)
		return
	camera = player.get_node("Head/Camera3D") as Camera3D
	_build_viewmodel()
	_ensure_input_map()

func _process(delta: float) -> void:
	if player == null or not player.alive:
		if attacking:
			_finish_attack()
		return
	if not attacking and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed(&"melee"):
		_start_attack()
	if attacking:
		_update_attack(delta)

func is_attacking() -> bool:
	return attacking

func _start_attack() -> void:
	if attacking or camera == null:
		return
	attacking = true
	attack_elapsed = 0.0
	hit_resolved = false
	player.reloading = false
	player.reload_remaining = 0.0
	player.burst_remaining = 0
	player.ammo_changed.emit(player.ammo, player.reserve_ammo, false)
	player.weapon_root.visible = false
	knife_root.visible = true
	melee_state_changed.emit(true)

func _update_attack(delta: float) -> void:
	attack_elapsed += delta
	var progress: float = clampf(attack_elapsed / MELEE_RECOVERY, 0.0, 1.0)
	var start_position := Vector3(0.34, -0.34, -0.28)
	var strike_position := Vector3(0.05, -0.13, -0.82)
	var start_rotation := Vector3(deg_to_rad(-12.0), deg_to_rad(24.0), deg_to_rad(-20.0))
	var strike_rotation := Vector3(deg_to_rad(-2.0), deg_to_rad(4.0), deg_to_rad(-2.0))
	if progress < 0.30:
		var thrust_alpha: float = progress / 0.30
		knife_root.position = start_position.lerp(strike_position, thrust_alpha)
		knife_root.rotation = start_rotation.lerp(strike_rotation, thrust_alpha)
	elif progress < 0.55:
		knife_root.position = strike_position
		knife_root.rotation = strike_rotation
	else:
		var return_alpha: float = (progress - 0.55) / 0.45
		knife_root.position = strike_position.lerp(start_position, return_alpha)
		knife_root.rotation = strike_rotation.lerp(start_rotation, return_alpha)

	if not hit_resolved and attack_elapsed >= MELEE_HIT_TIME:
		hit_resolved = true
		_resolve_hit()
	if attack_elapsed >= MELEE_RECOVERY:
		_finish_attack()

func _resolve_hit() -> void:
	var target := _find_melee_target()
	if target == null:
		return
	player.apply_melee_damage(target, MELEE_DAMAGE)

func _find_melee_target() -> ZombieTownZombie:
	if camera == null:
		return null
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x
	var up: Vector3 = camera.global_transform.basis.y
	var directions: Array[Vector3] = [
		forward.normalized(),
		(forward + right * 0.07).normalized(),
		(forward - right * 0.07).normalized(),
		(forward + up * 0.055).normalized(),
		(forward - up * 0.055).normalized()
	]
	var best_target: ZombieTownZombie
	var best_distance := INF
	for direction: Vector3 in directions:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * MELEE_RANGE)
		query.exclude = [player.get_rid()]
		query.collision_mask = 3
		var result: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			continue
		var collider_variant: Variant = result.get("collider")
		if not collider_variant is ZombieTownZombie:
			continue
		var zombie: ZombieTownZombie = collider_variant
		if not zombie.alive:
			continue
		var position_variant: Variant = result.get("position")
		if not position_variant is Vector3:
			continue
		var hit_position: Vector3 = position_variant
		var distance: float = origin.distance_to(hit_position)
		if distance < best_distance:
			best_distance = distance
			best_target = zombie
	return best_target

func _finish_attack() -> void:
	attacking = false
	attack_elapsed = 0.0
	hit_resolved = false
	if knife_root != null:
		knife_root.visible = false
	if player != null and is_instance_valid(player):
		player.weapon_root.visible = true
	melee_state_changed.emit(false)

func _build_viewmodel() -> void:
	knife_root = Node3D.new()
	knife_root.name = "MeleeKnifeRoot"
	knife_root.visible = false
	knife_root.position = Vector3(0.34, -0.34, -0.28)
	knife_root.rotation = Vector3(deg_to_rad(-12.0), deg_to_rad(24.0), deg_to_rad(-20.0))
	camera.add_child(knife_root)

	var sleeve_material := StandardMaterial3D.new()
	sleeve_material.albedo_color = Color(0.11, 0.16, 0.10, 1.0)
	sleeve_material.roughness = 0.92
	var skin_material := StandardMaterial3D.new()
	skin_material.albedo_color = Color(0.58, 0.39, 0.28, 1.0)
	skin_material.roughness = 0.92
	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color(0.08, 0.085, 0.075, 1.0)
	handle_material.roughness = 0.72
	var blade_material := StandardMaterial3D.new()
	blade_material.albedo_color = Color(0.56, 0.58, 0.60, 1.0)
	blade_material.metallic = 0.82
	blade_material.roughness = 0.28

	_add_cylinder(0.058, 0.43, Vector3(0.19, -0.22, 0.15), Vector3(deg_to_rad(68.0), 0.0, deg_to_rad(-18.0)), sleeve_material)
	_add_box(Vector3(0.12, 0.11, 0.14), Vector3(0.045, -0.055, -0.02), skin_material, Vector3(deg_to_rad(8.0), 0.0, deg_to_rad(-8.0)))
	_add_cylinder(0.036, 0.24, Vector3(0.015, -0.01, -0.17), Vector3(deg_to_rad(90.0), 0.0, 0.0), handle_material)
	_add_box(Vector3(0.085, 0.025, 0.055), Vector3(0.015, -0.01, -0.30), blade_material)
	_add_box(Vector3(0.045, 0.018, 0.38), Vector3(0.015, 0.0, -0.515), blade_material)

func _add_box(size: Vector3, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.position = position
	instance.rotation = rotation
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	knife_root.add_child(instance)

func _add_cylinder(radius: float, length: float, position: Vector3, rotation: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.position = position
	instance.rotation = rotation
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	knife_root.add_child(instance)

func _ensure_input_map() -> void:
	if InputMap.has_action(&"melee"):
		return
	InputMap.add_action(&"melee", 0.18)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_V
	InputMap.action_add_event(&"melee", key_event)
	var joy_event := InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_RIGHT_STICK
	InputMap.action_add_event(&"melee", joy_event)
