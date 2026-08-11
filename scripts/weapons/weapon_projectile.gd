class_name ZombieTownWeaponProjectile
extends Node3D

var owner_player: ZombieTownPlayer
var direction := Vector3.FORWARD
var speed := 40.0
var gravity := 0.0
var max_distance := 100.0
var direct_damage := 0.0
var splash_damage := 0.0
var splash_radius := 0.0
var allow_self_damage := false
var traveled := 0.0
var velocity := Vector3.ZERO
var glow_color := Color(0.35, 0.85, 1.0, 1.0)
var projectile_type: StringName = &""

func configure(
	player: ZombieTownPlayer,
	origin: Vector3,
	shot_direction: Vector3,
	weapon: WeaponData,
	color: Color
) -> void:
	owner_player = player
	global_position = origin
	direction = shot_direction.normalized()
	speed = weapon.projectile_speed
	gravity = weapon.projectile_gravity
	max_distance = weapon.range
	direct_damage = weapon.damage
	splash_damage = weapon.splash_damage
	splash_radius = weapon.splash_radius
	allow_self_damage = weapon.self_damage
	projectile_type = weapon.projectile_type
	velocity = direction * speed
	glow_color = color
	_build_visual()
	if projectile_type == &"knife":
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		queue_free()
		return

	var start: Vector3 = global_position
	velocity.y -= gravity * delta
	var displacement: Vector3 = velocity * delta
	var end: Vector3 = start + displacement
	var query := PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [owner_player.get_rid()]
	var result: Dictionary = owner_player.get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var hit_position_variant: Variant = result.get("position")
		var hit_position: Vector3 = end
		if hit_position_variant is Vector3:
			hit_position = hit_position_variant
		var collider_variant: Variant = result.get("collider")
		if collider_variant is ZombieTownZombie:
			var zombie: ZombieTownZombie = collider_variant
			_apply_damage(zombie, direct_damage)
		_explode(hit_position)
		return

	global_position = end
	if projectile_type == &"knife" and velocity.length_squared() > 0.01:
		look_at(global_position + velocity.normalized(), Vector3.UP)
	traveled += displacement.length()
	if traveled >= max_distance:
		_explode(global_position)

func _explode(position: Vector3) -> void:
	_spawn_impact_flash(position)
	if splash_radius > 0.0 and splash_damage > 0.0:
		for node: Node in get_tree().get_nodes_in_group(&"zombie"):
			if node is ZombieTownZombie:
				var zombie := node as ZombieTownZombie
				if not zombie.alive:
					continue
				var distance: float = zombie.global_position.distance_to(position)
				if distance <= splash_radius:
					var falloff: float = 1.0 - clampf(distance / maxf(splash_radius, 0.01), 0.0, 0.75)
					_apply_damage(zombie, splash_damage * falloff)

		if allow_self_damage and owner_player.global_position.distance_to(position) <= splash_radius:
			var self_distance: float = owner_player.global_position.distance_to(position)
			var self_falloff: float = 1.0 - clampf(self_distance / maxf(splash_radius, 0.01), 0.0, 0.85)
			owner_player.take_damage(splash_damage * 0.35 * self_falloff)
	queue_free()

func _apply_damage(zombie: ZombieTownZombie, amount: float) -> void:
	if amount <= 0.0 or owner_player == null or not owner_player.has_method(&"apply_weapon_damage"):
		return
	owner_player.call(&"apply_weapon_damage", zombie, amount, false)

func _build_visual() -> void:
	if projectile_type == &"knife":
		_build_knife_visual()
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = glow_color
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = 4.0

	var mesh := SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.22
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)

	var light := OmniLight3D.new()
	light.light_color = glow_color
	light.light_energy = 2.5
	light.omni_range = 2.6
	add_child(light)

func _build_knife_visual() -> void:
	var blade_material := StandardMaterial3D.new()
	blade_material.albedo_color = Color(0.62, 0.64, 0.66, 1.0)
	blade_material.metallic = 0.88
	blade_material.roughness = 0.24
	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color(0.075, 0.08, 0.07, 1.0)
	handle_material.roughness = 0.74

	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.045, 0.018, 0.34)
	blade_mesh.material = blade_material
	var blade := MeshInstance3D.new()
	blade.position = Vector3(0.0, 0.0, -0.17)
	blade.mesh = blade_mesh
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(blade)

	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.085, 0.025, 0.04)
	guard_mesh.material = blade_material
	var guard := MeshInstance3D.new()
	guard.position = Vector3(0.0, 0.0, 0.025)
	guard.mesh = guard_mesh
	guard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(guard)

	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.032
	handle_mesh.bottom_radius = 0.034
	handle_mesh.height = 0.18
	handle_mesh.radial_segments = 10
	handle_mesh.material = handle_material
	var handle := MeshInstance3D.new()
	handle.position = Vector3(0.0, 0.0, 0.13)
	handle.rotation.x = deg_to_rad(90.0)
	handle.mesh = handle_mesh
	handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(handle)

func _spawn_impact_flash(position: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.10 if projectile_type == &"knife" else maxf(0.24, splash_radius * 0.16)
	mesh.height = mesh.radius * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var impact_color := Color(0.92, 0.78, 0.48, 0.48) if projectile_type == &"knife" else Color(glow_color.r, glow_color.g, glow_color.b, 0.58)
	material.albedo_color = impact_color
	material.emission_enabled = true
	material.emission = Color(impact_color.r, impact_color.g, impact_color.b, 1.0)
	material.emission_energy_multiplier = 2.2 if projectile_type == &"knife" else 3.2
	mesh.material = material
	flash.mesh = mesh
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(flash)
	flash.global_position = position
	var tween: Tween = flash.create_tween()
	var target_scale := Vector3.ONE * (1.8 if projectile_type == &"knife" else 3.5)
	tween.tween_property(flash, "scale", target_scale, 0.10 if projectile_type == &"knife" else 0.14)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.10 if projectile_type == &"knife" else 0.14)
	tween.tween_callback(flash.queue_free)
