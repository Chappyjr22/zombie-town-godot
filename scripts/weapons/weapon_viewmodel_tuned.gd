class_name ZombieTownWeaponViewmodelTuned
extends ZombieTownWeaponViewmodel

func _build_arms(weapon_class: StringName) -> void:
	if current_weapon_id in [&"m1911", &"luger", &"flaregun"]:
		_build_pistol_hands()
		return
	if current_weapon_id in [&"raygun", &"raygun2"]:
		_build_wonder_pistol_hands()
		return
	_build_long_gun_hands(weapon_class)

func _build_pistol_hands() -> void:
	# Right forearm and wrist lead directly into the pistol grip.
	_arm_cylinder(0.047, 0.40, Vector3(0.15, -0.34, 0.13), Vector3(deg_to_rad(67.0), 0.0, deg_to_rad(-14.0)), sleeve)
	_arm_cylinder(0.042, 0.13, Vector3(0.075, -0.205, 0.035), Vector3(deg_to_rad(68.0), 0.0, deg_to_rad(-12.0)), skin)
	_arm_box(Vector3(0.095, 0.125, 0.080), Vector3(0.030, -0.135, -0.015), skin, Vector3(deg_to_rad(12.0), deg_to_rad(-3.0), deg_to_rad(-5.0)))

	# Trigger-hand fingers wrap the front of the grip instead of floating beside it.
	for y_position: float in [-0.115, -0.150, -0.185]:
		_arm_box(Vector3(0.026, 0.045, 0.072), Vector3(-0.020, y_position, -0.055), skin, Vector3(deg_to_rad(10.0), 0.0, deg_to_rad(8.0)))
	_arm_box(Vector3(0.030, 0.040, 0.085), Vector3(0.070, -0.105, -0.045), skin, Vector3(deg_to_rad(8.0), deg_to_rad(-18.0), deg_to_rad(-25.0)))

	# Support hand cups the firing hand and lower grip for a two-handed pistol stance.
	_arm_cylinder(0.045, 0.37, Vector3(-0.14, -0.35, 0.11), Vector3(deg_to_rad(69.0), 0.0, deg_to_rad(13.0)), sleeve)
	_arm_cylinder(0.040, 0.12, Vector3(-0.075, -0.215, 0.025), Vector3(deg_to_rad(70.0), 0.0, deg_to_rad(12.0)), skin)
	_arm_box(Vector3(0.085, 0.115, 0.082), Vector3(-0.035, -0.145, -0.030), skin, Vector3(deg_to_rad(13.0), deg_to_rad(5.0), deg_to_rad(7.0)))
	for y_position: float in [-0.125, -0.158, -0.190]:
		_arm_box(Vector3(0.024, 0.040, 0.068), Vector3(0.020, y_position, -0.060), skin, Vector3(deg_to_rad(9.0), 0.0, deg_to_rad(-8.0)))

func _build_wonder_pistol_hands() -> void:
	# Ray Guns are large pistols, so keep both hands near the grip/body rather than
	# pretending the support hand is holding a rifle fore-end.
	_arm_cylinder(0.048, 0.42, Vector3(0.16, -0.35, 0.13), Vector3(deg_to_rad(67.0), 0.0, deg_to_rad(-15.0)), sleeve)
	_arm_cylinder(0.042, 0.14, Vector3(0.080, -0.215, 0.025), Vector3(deg_to_rad(69.0), 0.0, deg_to_rad(-12.0)), skin)
	_arm_box(Vector3(0.105, 0.130, 0.090), Vector3(0.035, -0.145, -0.020), skin, Vector3(deg_to_rad(12.0), deg_to_rad(-4.0), deg_to_rad(-5.0)))
	for y_position: float in [-0.125, -0.162, -0.198]:
		_arm_box(Vector3(0.028, 0.046, 0.078), Vector3(-0.020, y_position, -0.065), skin, Vector3(deg_to_rad(10.0), 0.0, deg_to_rad(8.0)))

	_arm_cylinder(0.047, 0.40, Vector3(-0.15, -0.35, 0.10), Vector3(deg_to_rad(70.0), deg_to_rad(-4.0), deg_to_rad(15.0)), sleeve)
	_arm_cylinder(0.041, 0.13, Vector3(-0.075, -0.215, -0.005), Vector3(deg_to_rad(71.0), 0.0, deg_to_rad(13.0)), skin)
	_arm_box(Vector3(0.095, 0.115, 0.090), Vector3(-0.035, -0.135, -0.060), skin, Vector3(deg_to_rad(12.0), deg_to_rad(6.0), deg_to_rad(8.0)))
	_arm_box(Vector3(0.030, 0.050, 0.105), Vector3(0.035, -0.095, -0.105), skin, Vector3(deg_to_rad(5.0), deg_to_rad(-15.0), deg_to_rad(-28.0)))

func _build_long_gun_hands(weapon_class: StringName) -> void:
	var support_z := -0.50
	match weapon_class:
		&"smg":
			support_z = -0.43
		&"shotgun":
			support_z = -0.61
		&"lmg":
			support_z = -0.56
		&"sniper":
			support_z = -0.58
		&"wonder":
			support_z = -0.46

	# Firing hand grips the pistol grip / receiver junction.
	_arm_cylinder(0.048, 0.43, Vector3(0.17, -0.35, 0.10), Vector3(deg_to_rad(68.0), 0.0, deg_to_rad(-16.0)), sleeve)
	_arm_cylinder(0.041, 0.14, Vector3(0.090, -0.220, -0.065), Vector3(deg_to_rad(69.0), 0.0, deg_to_rad(-13.0)), skin)
	_arm_box(Vector3(0.100, 0.125, 0.090), Vector3(0.035, -0.150, -0.155), skin, Vector3(deg_to_rad(15.0), deg_to_rad(-3.0), deg_to_rad(-5.0)))
	for y_position: float in [-0.145, -0.182, -0.218]:
		_arm_box(Vector3(0.026, 0.046, 0.075), Vector3(-0.020, y_position, -0.205), skin, Vector3(deg_to_rad(11.0), 0.0, deg_to_rad(8.0)))
	_arm_box(Vector3(0.030, 0.045, 0.095), Vector3(0.075, -0.115, -0.190), skin, Vector3(deg_to_rad(7.0), deg_to_rad(-18.0), deg_to_rad(-24.0)))

	# Support forearm rises underneath the gun and the palm physically cups the fore-end.
	var forearm_z := support_z + 0.20
	_arm_cylinder(0.049, 0.47, Vector3(-0.23, -0.31, forearm_z), Vector3(deg_to_rad(73.0), deg_to_rad(-8.0), deg_to_rad(20.0)), sleeve)
	_arm_cylinder(0.042, 0.15, Vector3(-0.105, -0.175, support_z + 0.07), Vector3(deg_to_rad(75.0), deg_to_rad(-6.0), deg_to_rad(18.0)), skin)
	_arm_box(Vector3(0.120, 0.082, 0.115), Vector3(-0.025, -0.090, support_z), skin, Vector3(deg_to_rad(5.0), deg_to_rad(3.0), deg_to_rad(7.0)))

	# Four fingers curl under the fore-end. Keeping them close to the centerline removes
	# the detached "mitt" silhouette from the first live viewmodel test.
	var finger_x_positions: Array[float] = [-0.045, -0.015, 0.015, 0.045]
	for x_position: float in finger_x_positions:
		_arm_box(Vector3(0.022, 0.052, 0.070), Vector3(x_position, -0.130, support_z - 0.005), skin, Vector3(deg_to_rad(8.0), 0.0, deg_to_rad(-4.0)))
	_arm_box(Vector3(0.030, 0.046, 0.105), Vector3(0.060, -0.060, support_z + 0.025), skin, Vector3(deg_to_rad(-4.0), deg_to_rad(-20.0), deg_to_rad(-28.0)))

func _arm_box(size: Vector3, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.position = position
	instance.rotation = rotation
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arms_root.add_child(instance)

func _arm_cylinder(radius: float, length: float, position: Vector3, rotation: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = length
	mesh.radial_segments = 12
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.position = position
	instance.rotation = rotation
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arms_root.add_child(instance)
