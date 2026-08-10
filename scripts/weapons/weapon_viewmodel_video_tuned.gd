class_name ZombieTownWeaponViewmodelVideoTuned
extends ZombieTownWeaponViewmodelTuned

func _build_pistol_hands() -> void:
	# Keep most of the forearms below the camera edge and let the palms sell the grip.
	_arm_cylinder(0.043, 0.29, Vector3(0.17, -0.405, 0.16), Vector3(deg_to_rad(66.0), 0.0, deg_to_rad(-15.0)), sleeve)
	_arm_box(Vector3(0.090, 0.070, 0.075), Vector3(0.085, -0.245, 0.035), sleeve, Vector3(deg_to_rad(12.0), 0.0, deg_to_rad(-8.0)))
	_arm_cylinder(0.038, 0.105, Vector3(0.067, -0.205, 0.020), Vector3(deg_to_rad(68.0), 0.0, deg_to_rad(-12.0)), skin)
	_arm_box(Vector3(0.092, 0.120, 0.078), Vector3(0.026, -0.137, -0.020), skin, Vector3(deg_to_rad(12.0), deg_to_rad(-3.0), deg_to_rad(-5.0)))
	for y_position: float in [-0.118, -0.151, -0.184]:
		_arm_box(Vector3(0.024, 0.042, 0.066), Vector3(-0.018, y_position, -0.058), skin, Vector3(deg_to_rad(10.0), 0.0, deg_to_rad(8.0)))
	_arm_box(Vector3(0.028, 0.038, 0.080), Vector3(0.066, -0.105, -0.050), skin, Vector3(deg_to_rad(8.0), deg_to_rad(-18.0), deg_to_rad(-25.0)))

	_arm_cylinder(0.041, 0.27, Vector3(-0.16, -0.41, 0.145), Vector3(deg_to_rad(68.0), 0.0, deg_to_rad(14.0)), sleeve)
	_arm_box(Vector3(0.086, 0.068, 0.074), Vector3(-0.082, -0.250, 0.030), sleeve, Vector3(deg_to_rad(12.0), 0.0, deg_to_rad(8.0)))
	_arm_cylinder(0.036, 0.10, Vector3(-0.067, -0.207, 0.015), Vector3(deg_to_rad(70.0), 0.0, deg_to_rad(12.0)), skin)
	_arm_box(Vector3(0.082, 0.108, 0.078), Vector3(-0.030, -0.145, -0.035), skin, Vector3(deg_to_rad(13.0), deg_to_rad(5.0), deg_to_rad(7.0)))
	for y_position: float in [-0.128, -0.159, -0.190]:
		_arm_box(Vector3(0.022, 0.038, 0.064), Vector3(0.018, y_position, -0.061), skin, Vector3(deg_to_rad(9.0), 0.0, deg_to_rad(-8.0)))

func _build_wonder_pistol_hands() -> void:
	_arm_cylinder(0.044, 0.30, Vector3(0.18, -0.41, 0.16), Vector3(deg_to_rad(66.0), 0.0, deg_to_rad(-15.0)), sleeve)
	_arm_box(Vector3(0.095, 0.072, 0.080), Vector3(0.090, -0.247, 0.025), sleeve, Vector3(deg_to_rad(12.0), 0.0, deg_to_rad(-8.0)))
	_arm_cylinder(0.038, 0.11, Vector3(0.075, -0.208, 0.010), Vector3(deg_to_rad(69.0), 0.0, deg_to_rad(-12.0)), skin)
	_arm_box(Vector3(0.100, 0.124, 0.086), Vector3(0.032, -0.145, -0.025), skin, Vector3(deg_to_rad(12.0), deg_to_rad(-4.0), deg_to_rad(-5.0)))
	for y_position: float in [-0.127, -0.162, -0.197]:
		_arm_box(Vector3(0.026, 0.043, 0.074), Vector3(-0.018, y_position, -0.066), skin, Vector3(deg_to_rad(10.0), 0.0, deg_to_rad(8.0)))

	_arm_cylinder(0.043, 0.29, Vector3(-0.17, -0.41, 0.13), Vector3(deg_to_rad(69.0), deg_to_rad(-4.0), deg_to_rad(15.0)), sleeve)
	_arm_box(Vector3(0.090, 0.070, 0.078), Vector3(-0.087, -0.248, 0.000), sleeve, Vector3(deg_to_rad(12.0), 0.0, deg_to_rad(8.0)))
	_arm_cylinder(0.037, 0.105, Vector3(-0.070, -0.207, -0.010), Vector3(deg_to_rad(71.0), 0.0, deg_to_rad(13.0)), skin)
	_arm_box(Vector3(0.090, 0.110, 0.086), Vector3(-0.032, -0.136, -0.063), skin, Vector3(deg_to_rad(12.0), deg_to_rad(6.0), deg_to_rad(8.0)))
	_arm_box(Vector3(0.028, 0.046, 0.098), Vector3(0.034, -0.097, -0.107), skin, Vector3(deg_to_rad(5.0), deg_to_rad(-15.0), deg_to_rad(-28.0)))

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

	# Shorter sleeves keep the elbows off-screen and make the hands the focal point.
	_arm_cylinder(0.043, 0.31, Vector3(0.19, -0.405, 0.13), Vector3(deg_to_rad(67.0), 0.0, deg_to_rad(-16.0)), sleeve)
	_arm_box(Vector3(0.092, 0.072, 0.080), Vector3(0.100, -0.247, -0.045), sleeve, Vector3(deg_to_rad(14.0), 0.0, deg_to_rad(-9.0)))
	_arm_cylinder(0.037, 0.105, Vector3(0.084, -0.207, -0.090), Vector3(deg_to_rad(69.0), 0.0, deg_to_rad(-13.0)), skin)
	_arm_box(Vector3(0.094, 0.116, 0.084), Vector3(0.032, -0.150, -0.158), skin, Vector3(deg_to_rad(15.0), deg_to_rad(-3.0), deg_to_rad(-5.0)))
	for y_position: float in [-0.146, -0.181, -0.215]:
		_arm_box(Vector3(0.024, 0.043, 0.070), Vector3(-0.018, y_position, -0.204), skin, Vector3(deg_to_rad(11.0), 0.0, deg_to_rad(8.0)))
	_arm_box(Vector3(0.028, 0.042, 0.090), Vector3(0.071, -0.115, -0.190), skin, Vector3(deg_to_rad(7.0), deg_to_rad(-18.0), deg_to_rad(-24.0)))

	# Support arm approaches from below and mostly disappears below the frame.
	var forearm_z := support_z + 0.25
	_arm_cylinder(0.044, 0.33, Vector3(-0.22, -0.39, forearm_z), Vector3(deg_to_rad(72.0), deg_to_rad(-8.0), deg_to_rad(20.0)), sleeve)
	_arm_box(Vector3(0.094, 0.072, 0.085), Vector3(-0.120, -0.230, support_z + 0.105), sleeve, Vector3(deg_to_rad(10.0), deg_to_rad(-3.0), deg_to_rad(10.0)))
	_arm_cylinder(0.037, 0.105, Vector3(-0.095, -0.178, support_z + 0.060), Vector3(deg_to_rad(74.0), deg_to_rad(-6.0), deg_to_rad(18.0)), skin)
	_arm_box(Vector3(0.112, 0.078, 0.108), Vector3(-0.020, -0.090, support_z), skin, Vector3(deg_to_rad(5.0), deg_to_rad(3.0), deg_to_rad(7.0)))
	var finger_x_positions: Array[float] = [-0.042, -0.014, 0.014, 0.042]
	for x_position: float in finger_x_positions:
		_arm_box(Vector3(0.020, 0.047, 0.066), Vector3(x_position, -0.126, support_z - 0.004), skin, Vector3(deg_to_rad(8.0), 0.0, deg_to_rad(-4.0)))
	_arm_box(Vector3(0.028, 0.042, 0.098), Vector3(0.057, -0.058, support_z + 0.026), skin, Vector3(deg_to_rad(-4.0), deg_to_rad(-20.0), deg_to_rad(-28.0)))
