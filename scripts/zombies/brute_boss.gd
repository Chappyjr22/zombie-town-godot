class_name ZombieTownBruteBoss
extends ZombieTownZombie

signal boss_health_changed(current: float, maximum: float)

@export var slam_damage := 46.0
@export var slam_radius := 4.2
@export var slam_cooldown := 6.0

var slam_remaining := 2.8
var visual_root: Node3D

func _ready() -> void:
	insta_kill_immune = true
	nuke_immune = true
	thundergun_immune = true
	super._ready()
	add_to_group(&"boss_zombie")
	_build_visuals()
	boss_health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	slam_remaining = maxf(0.0, slam_remaining - delta)
	if target != null and is_instance_valid(target) and slam_remaining <= 0.0:
		var offset: Vector3 = target.global_position - global_position
		offset.y = 0.0
		if offset.length() <= slam_radius:
			slam_remaining = slam_cooldown
			_perform_slam()
	super._physics_process(delta)

func is_headshot_point(world_point: Vector3) -> bool:
	return world_point.y > global_position.y + 1.82

func take_damage(amount: float, _headshot := false, _source: Node = null) -> Dictionary:
	if not alive or amount <= 0.0:
		return {"killed": false}
	health = maxf(0.0, health - amount)
	boss_health_changed.emit(health, max_health)
	if health > 0.0:
		return {"killed": false}
	alive = false
	died.emit(self)
	queue_free()
	return {"killed": true}

func _perform_slam() -> void:
	_spawn_slam_effect()
	if target == null or not is_instance_valid(target):
		return
	var planar_offset: Vector3 = target.global_position - global_position
	planar_offset.y = 0.0
	if planar_offset.length() > slam_radius:
		return
	if target.has_method(&"take_damage"):
		target.call(&"take_damage", slam_damage)

func _spawn_slam_effect() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.24, 0.05, 0.58)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.11, 0.02, 1.0)
	material.emission_energy_multiplier = 5.5

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.72
	mesh.bottom_radius = 0.82
	mesh.height = 0.06
	mesh.radial_segments = 28
	mesh.material = material

	var shockwave := MeshInstance3D.new()
	shockwave.mesh = mesh
	shockwave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(shockwave)
	shockwave.global_position = global_position + Vector3(0.0, 0.08, 0.0)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.18, 0.04, 1.0)
	light.light_energy = 6.0
	light.omni_range = 6.0
	shockwave.add_child(light)

	var scale_amount: float = slam_radius / 0.72
	var tween: Tween = shockwave.create_tween()
	tween.tween_property(shockwave, "scale", Vector3(scale_amount, 1.0, scale_amount), 0.34)
	tween.parallel().tween_property(shockwave, "modulate:a", 0.0, 0.40)
	tween.tween_callback(shockwave.queue_free)

func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "BruteVisuals"
	add_child(visual_root)

	var flesh := StandardMaterial3D.new()
	flesh.albedo_color = Color(0.20, 0.18, 0.14, 1.0)
	flesh.roughness = 0.96

	var armor := StandardMaterial3D.new()
	armor.albedo_color = Color(0.085, 0.09, 0.08, 1.0)
	armor.metallic = 0.58
	armor.roughness = 0.48

	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.46, 0.43, 0.34, 1.0)
	bone.roughness = 0.92

	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.12, 0.025, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.035, 0.01, 1.0)
	glow.emission_energy_multiplier = 5.0

	_add_box(Vector3(1.16, 1.26, 0.72), Vector3(0.0, 1.18, 0.0), flesh)
	_add_box(Vector3(1.58, 0.38, 0.82), Vector3(0.0, 1.72, 0.0), armor)
	_add_box(Vector3(0.96, 0.54, 0.14), Vector3(0.0, 1.34, -0.42), armor)
	_add_box(Vector3(0.22, 0.30, 0.12), Vector3(0.0, 1.38, -0.51), glow)

	_add_box(Vector3(0.34, 1.30, 0.38), Vector3(-0.76, 1.05, 0.0), flesh, Vector3(0.0, 0.0, deg_to_rad(-7.0)))
	_add_box(Vector3(0.34, 1.30, 0.38), Vector3(0.76, 1.05, 0.0), flesh, Vector3(0.0, 0.0, deg_to_rad(7.0)))
	_add_box(Vector3(0.45, 0.28, 0.50), Vector3(-0.78, 1.62, 0.0), armor)
	_add_box(Vector3(0.45, 0.28, 0.50), Vector3(0.78, 1.62, 0.0), armor)

	_add_box(Vector3(0.40, 0.92, 0.44), Vector3(-0.29, 0.48, 0.0), armor, Vector3(0.0, 0.0, deg_to_rad(3.0)))
	_add_box(Vector3(0.40, 0.92, 0.44), Vector3(0.29, 0.48, 0.0), armor, Vector3(0.0, 0.0, deg_to_rad(-3.0)))

	_add_sphere(Vector3(0.0, 2.18, 0.0), Vector3(0.46, 0.52, 0.44), bone)
	_add_box(Vector3(0.58, 0.22, 0.16), Vector3(0.0, 2.08, -0.39), armor)
	_add_sphere(Vector3(-0.15, 2.23, -0.40), Vector3(0.07, 0.06, 0.045), glow)
	_add_sphere(Vector3(0.15, 2.23, -0.40), Vector3(0.07, 0.06, 0.045), glow)

	var aura := OmniLight3D.new()
	aura.position = Vector3(0.0, 1.45, -0.2)
	aura.light_color = Color(1.0, 0.11, 0.025, 1.0)
	aura.light_energy = 2.2
	aura.omni_range = 4.5
	visual_root.add_child(aura)

func _add_box(size: Vector3, position: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.position = position
	instance.rotation = rotation_value
	instance.mesh = mesh
	visual_root.add_child(instance)

func _add_sphere(position: Vector3, scale_value: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.position = position
	instance.scale = scale_value
	instance.mesh = mesh
	visual_root.add_child(instance)
