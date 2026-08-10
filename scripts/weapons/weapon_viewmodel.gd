class_name ZombieTownWeaponViewmodel
extends Node3D

var model_root: Node3D
var arms_root: Node3D
var fire_kick := 0.0
var reload_time := 0.0
var reload_duration := 0.0
var shell_reload := false
var current_weapon_id: StringName = &""

var metal_dark: StandardMaterial3D
var metal_mid: StandardMaterial3D
var metal_light: StandardMaterial3D
var wood_dark: StandardMaterial3D
var polymer_dark: StandardMaterial3D
var skin: StandardMaterial3D
var sleeve: StandardMaterial3D
var ray_green: StandardMaterial3D
var ray_blue: StandardMaterial3D

func _ready() -> void:
	_build_materials()
	model_root = Node3D.new()
	model_root.name = "ModelRoot"
	add_child(model_root)
	arms_root = Node3D.new()
	arms_root.name = "ArmsRoot"
	add_child(arms_root)
	_build_arms(&"pistol")

func _process(delta: float) -> void:
	fire_kick = move_toward(fire_kick, 0.0, delta * 8.5)
	var reload_alpha := 0.0
	if reload_time > 0.0:
		reload_time = maxf(0.0, reload_time - delta)
		if reload_duration > 0.0:
			var progress := 1.0 - reload_time / reload_duration
			reload_alpha = sin(progress * PI)
	var kick_rotation := Vector3(deg_to_rad(-4.5) * fire_kick, deg_to_rad(1.3) * fire_kick, deg_to_rad(1.0) * fire_kick)
	var reload_rotation := Vector3(deg_to_rad(18.0) * reload_alpha, deg_to_rad(-10.0) * reload_alpha, deg_to_rad(12.0) * reload_alpha)
	model_root.rotation = kick_rotation + reload_rotation
	model_root.position = Vector3(0.0, -0.015 * reload_alpha, 0.055 * fire_kick + 0.08 * reload_alpha)
	arms_root.rotation = Vector3(deg_to_rad(8.0) * reload_alpha, deg_to_rad(-5.0) * reload_alpha, deg_to_rad(6.0) * reload_alpha)

func set_weapon(data: WeaponData) -> void:
	if data == null:
		return
	current_weapon_id = data.id
	_clear_children(model_root)
	_clear_children(arms_root)
	match data.id:
		&"m1911", &"luger", &"flaregun":
			_build_pistol(data.id)
		&"ak74u":
			_build_ak()
		&"galil":
			_build_galil()
		&"raygun":
			_build_ray_gun()
		&"raygun2":
			_build_ray_gun_mk2()
		_:
			_build_class_fallback(data.weapon_class)
	_build_arms(data.weapon_class)

func animate_fire() -> void:
	fire_kick = minf(fire_kick + 0.72, 1.0)

func animate_reload(duration: float, is_shell_reload: bool) -> void:
	reload_duration = maxf(duration, 0.01)
	reload_time = reload_duration
	shell_reload = is_shell_reload

func muzzle_position_for(data: WeaponData) -> Vector3:
	if data == null:
		return Vector3(0.0, 0.02, -0.55)
	match data.id:
		&"m1911", &"luger", &"flaregun":
			return Vector3(0.0, 0.055, -0.47)
		&"ak74u":
			return Vector3(0.0, 0.055, -0.94)
		&"galil":
			return Vector3(0.0, 0.06, -1.02)
		&"raygun":
			return Vector3(0.0, 0.09, -0.62)
		&"raygun2":
			return Vector3(0.0, 0.10, -0.74)
		_:
			return Vector3(0.0, 0.04, -0.78)

func _build_materials() -> void:
	metal_dark = _material(Color(0.055, 0.06, 0.07, 1.0), 0.68, 0.72)
	metal_mid = _material(Color(0.13, 0.14, 0.16, 1.0), 0.54, 0.68)
	metal_light = _material(Color(0.30, 0.32, 0.35, 1.0), 0.42, 0.72)
	wood_dark = _material(Color(0.22, 0.085, 0.035, 1.0), 0.82, 0.05)
	polymer_dark = _material(Color(0.07, 0.075, 0.08, 1.0), 0.86, 0.12)
	skin = _material(Color(0.48, 0.30, 0.22, 1.0), 0.96, 0.0)
	sleeve = _material(Color(0.12, 0.15, 0.12, 1.0), 0.94, 0.0)
	ray_green = _emissive_material(Color(0.18, 0.92, 0.34, 1.0), 3.8)
	ray_blue = _emissive_material(Color(0.16, 0.58, 1.0, 1.0), 3.8)

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color.darkened(0.35), 0.34, 0.48)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _build_pistol(weapon_id: StringName) -> void:
	var slide_length := 0.39
	var barrel_length := 0.31
	if weapon_id == &"luger":
		slide_length = 0.43
		barrel_length = 0.37
	elif weapon_id == &"flaregun":
		slide_length = 0.34
		barrel_length = 0.29
	_box(Vector3(0.11, 0.095, slide_length), Vector3(0.0, 0.045, -0.19), metal_mid)
	_box(Vector3(0.095, 0.032, slide_length * 0.92), Vector3(0.0, 0.105, -0.19), metal_light)
	_cylinder(0.026, barrel_length, Vector3(0.0, 0.05, -0.32), metal_dark)
	_box(Vector3(0.10, 0.21, 0.115), Vector3(0.0, -0.105, -0.03), polymer_dark, Vector3(deg_to_rad(14.0), 0.0, 0.0))
	_box(Vector3(0.074, 0.12, 0.09), Vector3(0.0, -0.19, -0.015), wood_dark, Vector3(deg_to_rad(14.0), 0.0, 0.0))
	_box(Vector3(0.015, 0.026, 0.045), Vector3(0.0, 0.13, -0.37), metal_dark)
	_box(Vector3(0.045, 0.018, 0.032), Vector3(0.0, 0.12, -0.04), metal_dark)
	_box(Vector3(0.075, 0.018, 0.12), Vector3(0.0, -0.02, -0.22), metal_dark)
	if weapon_id == &"flaregun":
		_cylinder(0.048, 0.24, Vector3(0.0, 0.055, -0.31), metal_mid)
		_box(Vector3(0.06, 0.035, 0.05), Vector3(0.0, 0.055, -0.46), metal_dark)

func _build_ak() -> void:
	_box(Vector3(0.15, 0.14, 0.42), Vector3(0.0, 0.015, -0.18), metal_mid)
	_box(Vector3(0.13, 0.075, 0.34), Vector3(0.0, 0.09, -0.24), metal_dark)
	_box(Vector3(0.14, 0.115, 0.34), Vector3(0.0, 0.005, -0.52), wood_dark)
	_cylinder(0.024, 0.48, Vector3(0.0, 0.055, -0.76), metal_dark)
	_cylinder(0.038, 0.10, Vector3(0.0, 0.055, -0.96), metal_mid)
	_box(Vector3(0.105, 0.26, 0.11), Vector3(0.0, -0.17, -0.20), wood_dark, Vector3(deg_to_rad(20.0), 0.0, deg_to_rad(-3.0)))
	_box(Vector3(0.10, 0.29, 0.095), Vector3(0.0, -0.145, -0.36), metal_mid, Vector3(deg_to_rad(-9.0), 0.0, 0.0))
	_box(Vector3(0.085, 0.20, 0.075), Vector3(0.0, -0.26, -0.33), metal_mid, Vector3(deg_to_rad(-16.0), 0.0, 0.0))
	_box(Vector3(0.12, 0.12, 0.42), Vector3(0.0, -0.005, 0.22), wood_dark, Vector3(0.0, 0.0, deg_to_rad(-4.0)))
	_box(Vector3(0.018, 0.055, 0.05), Vector3(0.0, 0.16, -0.84), metal_dark)
	_box(Vector3(0.055, 0.025, 0.035), Vector3(0.0, 0.15, -0.04), metal_dark)
	_box(Vector3(0.018, 0.045, 0.20), Vector3(-0.085, 0.06, -0.15), metal_light)

func _build_galil() -> void:
	_box(Vector3(0.16, 0.15, 0.43), Vector3(0.0, 0.015, -0.17), metal_mid)
	_box(Vector3(0.13, 0.07, 0.34), Vector3(0.0, 0.10, -0.24), metal_dark)
	_box(Vector3(0.145, 0.12, 0.38), Vector3(0.0, 0.005, -0.53), polymer_dark)
	_cylinder(0.025, 0.53, Vector3(0.0, 0.06, -0.83), metal_dark)
	_cylinder(0.042, 0.12, Vector3(0.0, 0.06, -1.02), metal_mid)
	_box(Vector3(0.11, 0.28, 0.10), Vector3(0.0, -0.16, -0.20), polymer_dark, Vector3(deg_to_rad(18.0), 0.0, 0.0))
	_box(Vector3(0.105, 0.31, 0.10), Vector3(0.0, -0.15, -0.38), metal_mid, Vector3(deg_to_rad(-7.0), 0.0, 0.0))
	_box(Vector3(0.09, 0.18, 0.08), Vector3(0.0, -0.29, -0.36), metal_mid, Vector3(deg_to_rad(-11.0), 0.0, 0.0))
	_box(Vector3(0.035, 0.035, 0.43), Vector3(-0.075, 0.02, 0.22), metal_light)
	_box(Vector3(0.035, 0.035, 0.43), Vector3(0.075, 0.02, 0.22), metal_light)
	_box(Vector3(0.16, 0.10, 0.10), Vector3(0.0, 0.02, 0.42), polymer_dark)
	_box(Vector3(0.018, 0.055, 0.05), Vector3(0.0, 0.17, -0.91), metal_dark)
	_box(Vector3(0.06, 0.028, 0.04), Vector3(0.0, 0.16, -0.04), metal_dark)

func _build_ray_gun() -> void:
	_box(Vector3(0.20, 0.18, 0.32), Vector3(0.0, 0.03, -0.14), metal_mid)
	_sphere(0.105, Vector3(0.0, 0.12, -0.18), ray_green, Vector3(1.0, 0.82, 1.16))
	_cylinder(0.055, 0.34, Vector3(0.0, 0.09, -0.41), metal_light)
	_cylinder(0.072, 0.07, Vector3(0.0, 0.09, -0.60), ray_green)
	_box(Vector3(0.12, 0.25, 0.13), Vector3(0.0, -0.14, -0.02), wood_dark, Vector3(deg_to_rad(18.0), 0.0, 0.0))
	_box(Vector3(0.16, 0.055, 0.16), Vector3(0.0, -0.015, -0.02), metal_dark)
	_cylinder(0.02, 0.22, Vector3(-0.10, 0.055, -0.25), ray_green)
	_cylinder(0.02, 0.22, Vector3(0.10, 0.055, -0.25), ray_green)
	_box(Vector3(0.05, 0.035, 0.04), Vector3(0.0, 0.22, -0.20), metal_dark)

func _build_ray_gun_mk2() -> void:
	_box(Vector3(0.22, 0.20, 0.40), Vector3(0.0, 0.035, -0.16), metal_mid)
	_box(Vector3(0.16, 0.075, 0.34), Vector3(0.0, 0.15, -0.19), polymer_dark)
	_sphere(0.09, Vector3(0.0, 0.11, -0.22), ray_blue, Vector3(1.1, 0.78, 1.25))
	_cylinder(0.035, 0.44, Vector3(-0.07, 0.10, -0.48), metal_light)
	_cylinder(0.035, 0.44, Vector3(0.07, 0.10, -0.48), metal_light)
	_cylinder(0.045, 0.10, Vector3(-0.07, 0.10, -0.73), ray_blue)
	_cylinder(0.045, 0.10, Vector3(0.07, 0.10, -0.73), ray_blue)
	_box(Vector3(0.13, 0.27, 0.13), Vector3(0.0, -0.15, -0.02), polymer_dark, Vector3(deg_to_rad(20.0), 0.0, 0.0))
	_box(Vector3(0.18, 0.045, 0.20), Vector3(0.0, -0.015, -0.02), metal_dark)
	_box(Vector3(0.045, 0.04, 0.04), Vector3(0.0, 0.235, -0.20), ray_blue)

func _build_class_fallback(weapon_class: StringName) -> void:
	match weapon_class:
		&"smg":
			_box(Vector3(0.15, 0.14, 0.46), Vector3(0.0, 0.02, -0.22), metal_mid)
			_cylinder(0.022, 0.38, Vector3(0.0, 0.055, -0.61), metal_dark)
			_box(Vector3(0.10, 0.24, 0.10), Vector3(0.0, -0.15, -0.18), polymer_dark, Vector3(deg_to_rad(16.0), 0.0, 0.0))
		&"rifle":
			_box(Vector3(0.16, 0.15, 0.52), Vector3(0.0, 0.02, -0.25), metal_mid)
			_cylinder(0.024, 0.52, Vector3(0.0, 0.06, -0.75), metal_dark)
			_box(Vector3(0.10, 0.28, 0.11), Vector3(0.0, -0.17, -0.22), polymer_dark, Vector3(deg_to_rad(18.0), 0.0, 0.0))
			_box(Vector3(0.13, 0.11, 0.36), Vector3(0.0, 0.0, 0.26), polymer_dark)
		&"shotgun":
			_box(Vector3(0.14, 0.14, 0.48), Vector3(0.0, 0.01, -0.22), metal_mid)
			_cylinder(0.028, 0.70, Vector3(0.0, 0.06, -0.78), metal_dark)
			_cylinder(0.035, 0.48, Vector3(0.0, -0.015, -0.63), metal_mid)
			_box(Vector3(0.11, 0.26, 0.11), Vector3(0.0, -0.16, -0.20), wood_dark, Vector3(deg_to_rad(17.0), 0.0, 0.0))
		&"lmg":
			_box(Vector3(0.19, 0.17, 0.58), Vector3(0.0, 0.02, -0.28), metal_mid)
			_cylinder(0.028, 0.62, Vector3(0.0, 0.065, -0.86), metal_dark)
			_box(Vector3(0.15, 0.20, 0.16), Vector3(0.0, -0.13, -0.32), metal_dark)
			_box(Vector3(0.12, 0.27, 0.11), Vector3(0.0, -0.17, -0.18), polymer_dark, Vector3(deg_to_rad(18.0), 0.0, 0.0))
		&"sniper":
			_box(Vector3(0.15, 0.14, 0.58), Vector3(0.0, 0.02, -0.25), metal_mid)
			_cylinder(0.024, 0.80, Vector3(0.0, 0.06, -0.92), metal_dark)
			_cylinder(0.055, 0.30, Vector3(0.0, 0.18, -0.30), metal_dark)
			_box(Vector3(0.11, 0.26, 0.11), Vector3(0.0, -0.17, -0.18), polymer_dark, Vector3(deg_to_rad(18.0), 0.0, 0.0))
		&"wonder":
			_box(Vector3(0.22, 0.18, 0.44), Vector3(0.0, 0.03, -0.20), metal_mid)
			_cylinder(0.045, 0.46, Vector3(0.0, 0.09, -0.58), ray_blue)
			_box(Vector3(0.13, 0.26, 0.12), Vector3(0.0, -0.15, -0.03), polymer_dark, Vector3(deg_to_rad(18.0), 0.0, 0.0))
		_:
			_build_pistol(&"m1911")

func _build_arms(weapon_class: StringName) -> void:
	var long_gun := weapon_class in [&"smg", &"rifle", &"shotgun", &"lmg", &"sniper", &"wonder"]
	_cylinder_arm(0.055, 0.42, Vector3(0.14, -0.34, 0.12), Vector3(deg_to_rad(68.0), 0.0, deg_to_rad(-15.0)), sleeve)
	_sphere_arm(0.075, Vector3(0.08, -0.14, -0.02), skin, Vector3(0.8, 1.2, 0.75))
	if long_gun:
		_cylinder_arm(0.055, 0.46, Vector3(-0.25, -0.31, -0.12), Vector3(deg_to_rad(73.0), deg_to_rad(-10.0), deg_to_rad(22.0)), sleeve)
		_sphere_arm(0.075, Vector3(-0.13, -0.10, -0.43), skin, Vector3(0.9, 1.15, 0.8))
	else:
		_cylinder_arm(0.05, 0.36, Vector3(-0.15, -0.35, 0.08), Vector3(deg_to_rad(72.0), 0.0, deg_to_rad(10.0)), sleeve)
		_sphere_arm(0.07, Vector3(-0.06, -0.14, -0.02), skin, Vector3(0.8, 1.15, 0.75))

func _box(size: Vector3, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.position = position
	instance.rotation = rotation
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model_root.add_child(instance)

func _cylinder(radius: float, length: float, position: Vector3, material: Material, rotation: Vector3 = Vector3(deg_to_rad(90.0), 0.0, 0.0)) -> void:
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
	model_root.add_child(instance)

func _sphere(radius: float, position: Vector3, material: Material, scale_value: Vector3 = Vector3.ONE) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.position = position
	instance.scale = scale_value
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model_root.add_child(instance)

func _cylinder_arm(radius: float, length: float, position: Vector3, rotation: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.1
	mesh.height = length
	mesh.radial_segments = 10
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.position = position
	instance.rotation = rotation
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arms_root.add_child(instance)

func _sphere_arm(radius: float, position: Vector3, material: Material, scale_value: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.position = position
	instance.scale = scale_value
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arms_root.add_child(instance)

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		child.queue_free()
