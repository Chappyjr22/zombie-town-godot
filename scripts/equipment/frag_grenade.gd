class_name ZombieTownFragGrenade
extends Node3D

const FUSE_TIME := 2.6
const BLAST_RADIUS := 5.4
const MAX_DAMAGE := 520.0
const SELF_DAMAGE := 115.0

var owner_player: ZombieTownAdvancedPlayer
var velocity := Vector3.ZERO
var fuse_remaining := FUSE_TIME
var exploded := false
var visual: MeshInstance3D
var blink_light: OmniLight3D

func configure(player: ZombieTownAdvancedPlayer, origin: Vector3, launch_velocity: Vector3) -> void:
	owner_player = player
	global_position = origin
	velocity = launch_velocity
	_build_visual()

func _physics_process(delta: float) -> void:
	if exploded:
		return
	fuse_remaining -= delta
	if fuse_remaining <= 0.0:
		_explode()
		return
	velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * delta
	var start: Vector3 = global_position
	var finish: Vector3 = start + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(start, finish)
	if owner_player != null and is_instance_valid(owner_player):
		query.exclude = [owner_player.get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		global_position = finish
	else:
		var position_variant: Variant = result.get("position")
		var normal_variant: Variant = result.get("normal")
		if position_variant is Vector3:
			var hit_position: Vector3 = position_variant
			global_position = hit_position
		if normal_variant is Vector3:
			var normal: Vector3 = normal_variant
			velocity = velocity.bounce(normal) * 0.42
			if absf(normal.y) > 0.7 and velocity.length() < 2.0:
				velocity = Vector3.ZERO
	rotation.x += delta * 7.0
	rotation.z += delta * 5.0
	if blink_light != null:
		blink_light.light_energy = 2.4 if fmod(fuse_remaining, 0.42) < 0.12 else 0.25

func _explode() -> void:
	if exploded:
		return
	exploded = true
	var origin: Vector3 = global_position
	for node: Node in get_tree().get_nodes_in_group(&"zombie"):
		if not node is ZombieTownZombie:
			continue
		var zombie := node as ZombieTownZombie
		if not zombie.alive:
			continue
		var distance: float = zombie.global_position.distance_to(origin)
		if distance > BLAST_RADIUS:
			continue
		var falloff: float = clampf(1.0 - distance / BLAST_RADIUS, 0.22, 1.0)
		if owner_player != null and is_instance_valid(owner_player):
			owner_player.apply_weapon_damage(zombie, MAX_DAMAGE * falloff, false)
	if owner_player != null and is_instance_valid(owner_player) and owner_player.alive:
		var player_distance: float = owner_player.global_position.distance_to(origin)
		if player_distance < BLAST_RADIUS:
			var player_falloff: float = clampf(1.0 - player_distance / BLAST_RADIUS, 0.0, 1.0)
			owner_player.take_damage(SELF_DAMAGE * player_falloff)
	var effect: ZombieTownExplosionEffect = ZombieTownExplosionEffect.new()
	get_tree().current_scene.add_child(effect)
	effect.configure_frag(origin)
	queue_free()

func _build_visual() -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.16, 0.19, 0.12, 1.0)
	body_material.roughness = 0.74
	body_material.metallic = 0.28
	var mesh := SphereMesh.new()
	mesh.radius = 0.105
	mesh.height = 0.21
	mesh.material = body_material
	visual = MeshInstance3D.new()
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(visual)
	var lever_mesh := BoxMesh.new()
	lever_mesh.size = Vector3(0.055, 0.025, 0.17)
	lever_mesh.material = body_material
	var lever := MeshInstance3D.new()
	lever.position = Vector3(0.0, 0.115, 0.015)
	lever.mesh = lever_mesh
	add_child(lever)
	blink_light = OmniLight3D.new()
	blink_light.light_color = Color(1.0, 0.22, 0.08, 1.0)
	blink_light.light_energy = 0.25
	blink_light.omni_range = 1.4
	add_child(blink_light)
