class_name ZombieTownClaymore
extends Node3D

const ARM_TIME := 0.75
const TRIGGER_RANGE := 4.8
const BLAST_RANGE := 6.2
const TRIGGER_DOT := 0.62
const BLAST_DOT := 0.34
const MAX_DAMAGE := 760.0

var owner_player: ZombieTownAdvancedPlayer
var arm_remaining := ARM_TIME
var exploded := false
var indicator: OmniLight3D

func configure(player: ZombieTownAdvancedPlayer, world_position: Vector3, yaw: float) -> void:
	owner_player = player
	global_position = world_position
	rotation.y = yaw
	_build_visual()

func _physics_process(delta: float) -> void:
	if exploded:
		return
	if arm_remaining > 0.0:
		arm_remaining -= delta
		if arm_remaining <= 0.0 and indicator != null:
			indicator.light_color = Color(0.15, 1.0, 0.28, 1.0)
			indicator.light_energy = 1.3
		return
	var forward: Vector3 = -global_transform.basis.z.normalized()
	for node: Node in get_tree().get_nodes_in_group(&"zombie"):
		if not node is ZombieTownZombie:
			continue
		var zombie := node as ZombieTownZombie
		if not zombie.alive:
			continue
		var offset: Vector3 = zombie.global_position + Vector3(0.0, 0.8, 0.0) - global_position
		var distance: float = offset.length()
		if distance <= 0.05 or distance > TRIGGER_RANGE:
			continue
		if forward.dot(offset / distance) >= TRIGGER_DOT:
			_explode()
			return

func _explode() -> void:
	if exploded:
		return
	exploded = true
	var origin: Vector3 = global_position
	var forward: Vector3 = -global_transform.basis.z.normalized()
	for node: Node in get_tree().get_nodes_in_group(&"zombie"):
		if not node is ZombieTownZombie:
			continue
		var zombie := node as ZombieTownZombie
		if not zombie.alive:
			continue
		var target: Vector3 = zombie.global_position + Vector3(0.0, 0.8, 0.0)
		var offset: Vector3 = target - origin
		var distance: float = offset.length()
		if distance <= 0.05 or distance > BLAST_RANGE:
			continue
		if forward.dot(offset / distance) < BLAST_DOT:
			continue
		var falloff: float = clampf(1.0 - distance / BLAST_RANGE, 0.28, 1.0)
		if owner_player != null and is_instance_valid(owner_player):
			owner_player.apply_weapon_damage(zombie, MAX_DAMAGE * falloff, false)
	var effect: ZombieTownExplosionEffect = ZombieTownExplosionEffect.new()
	get_tree().current_scene.add_child(effect)
	effect.configure_claymore(origin, forward)
	queue_free()

func _build_visual() -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.20, 0.23, 0.15, 1.0)
	body_material.roughness = 0.72
	body_material.metallic = 0.22
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.46, 0.22, 0.16)
	body_mesh.material = body_material
	var body := MeshInstance3D.new()
	body.position = Vector3(0.0, 0.14, 0.0)
	body.mesh = body_mesh
	add_child(body)
	for x_position: float in [-0.16, 0.16]:
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.035, 0.20, 0.035)
		leg_mesh.material = body_material
		var leg := MeshInstance3D.new()
		leg.position = Vector3(x_position, 0.05, 0.03)
		leg.rotation.z = deg_to_rad(18.0 if x_position < 0.0 else -18.0)
		leg.mesh = leg_mesh
		add_child(leg)
	indicator = OmniLight3D.new()
	indicator.position = Vector3(0.0, 0.24, -0.10)
	indicator.light_color = Color(1.0, 0.25, 0.08, 1.0)
	indicator.light_energy = 0.7
	indicator.omni_range = 1.2
	add_child(indicator)
