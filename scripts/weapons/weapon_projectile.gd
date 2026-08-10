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
	velocity = direction * speed
	glow_color = color
	_build_visual()

func _physics_process(delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		queue_free()
		return

	var start := global_position
	velocity.y -= gravity * delta
	var displacement := velocity * delta
	var end := start + displacement
	var query := PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [owner_player.get_rid()]
	var result: Dictionary = owner_player.get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var hit_position_variant: Variant = result.get("position")
		var hit_position := end
		if hit_position_variant is Vector3:
			hit_position = hit_position_variant
		var collider_variant: Variant = result.get("collider")
		if collider_variant is ZombieTownZombie:
			var zombie: ZombieTownZombie = collider_variant
			_apply_damage(zombie, direct_damage)
		_explode(hit_position)
		return

	global_position = end
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
				var distance := zombie.global_position.distance_to(position)
				if distance <= splash_radius:
					var falloff := 1.0 - clampf(distance / maxf(splash_radius, 0.01), 0.0, 0.75)
					_apply_damage(zombie, splash_damage * falloff)

		if allow_self_damage and owner_player.global_position.distance_to(position) <= splash_radius:
			var self_distance := owner_player.global_position.distance_to(position)
			var self_falloff := 1.0 - clampf(self_distance / maxf(splash_radius, 0.01), 0.0, 0.85)
			owner_player.take_damage(splash_damage * 0.35 * self_falloff)
	queue_free()

func _apply_damage(zombie: ZombieTownZombie, amount: float) -> void:
	if owner_player == null or not owner_player.has_method(&"apply_weapon_damage"):
		return
	owner_player.call(&"apply_weapon_damage", zombie, amount, false)

func _build_visual() -> void:
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

func _spawn_impact_flash(position: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = maxf(0.24, splash_radius * 0.16)
	mesh.height = mesh.radius * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.58)
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = 3.2
	mesh.material = material
	flash.mesh = mesh
	get_tree().current_scene.add_child(flash)
	flash.global_position = position
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 3.5, 0.14)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.14)
	tween.tween_callback(flash.queue_free)
