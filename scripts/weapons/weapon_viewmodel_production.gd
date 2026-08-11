class_name ZombieTownWeaponViewmodelProduction
extends ZombieTownWeaponViewmodelTuned

func set_weapon(data: WeaponData) -> void:
	if data == null:
		return
	if data.id == &"mp5" or data.id == &"olympia":
		current_weapon_id = data.id
		_clear_children(model_root)
		_clear_children(arms_root)
		if data.id == &"mp5":
			_build_suomi()
		else:
			_build_olympia()
		_build_arms(data.weapon_class)
		return
	super.set_weapon(data)

func _build_suomi() -> void:
	# Cylindrical receiver and perforated barrel-jacket silhouette inspired by the KP-31.
	_cylinder(0.055, 0.42, Vector3(0.0, 0.045, -0.27), metal_mid)
	_cylinder(0.048, 0.39, Vector3(0.0, 0.045, -0.64), metal_dark)
	_cylinder(0.062, 0.08, Vector3(0.0, 0.045, -0.86), metal_mid)
	_box(Vector3(0.12, 0.12, 0.20), Vector3(0.0, 0.0, -0.05), metal_mid)
	_box(Vector3(0.105, 0.25, 0.10), Vector3(0.0, -0.16, -0.10), wood_dark, Vector3(deg_to_rad(18.0), 0.0, 0.0))
	_box(Vector3(0.13, 0.11, 0.39), Vector3(0.0, -0.015, 0.25), wood_dark)

	# Drum magazine is the big visual identifier of the Suomi.
	_cylinder(0.13, 0.075, Vector3(0.0, -0.105, -0.33), metal_dark, Vector3(0.0, 0.0, deg_to_rad(90.0)))
	_cylinder(0.105, 0.082, Vector3(0.0, -0.105, -0.33), metal_mid, Vector3(0.0, 0.0, deg_to_rad(90.0)))
	_box(Vector3(0.018, 0.055, 0.045), Vector3(0.0, 0.14, -0.77), metal_light)
	_box(Vector3(0.05, 0.025, 0.035), Vector3(0.0, 0.135, -0.05), metal_light)

func _build_olympia() -> void:
	# Side-by-side double barrels and a wood fore-end make this read as an Olympia immediately.
	_cylinder(0.034, 0.76, Vector3(-0.045, 0.055, -0.60), metal_dark)
	_cylinder(0.034, 0.76, Vector3(0.045, 0.055, -0.60), metal_dark)
	_cylinder(0.045, 0.08, Vector3(-0.045, 0.055, -1.00), metal_mid)
	_cylinder(0.045, 0.08, Vector3(0.045, 0.055, -1.00), metal_mid)
	_box(Vector3(0.16, 0.16, 0.25), Vector3(0.0, 0.015, -0.18), metal_mid)
	_box(Vector3(0.15, 0.12, 0.33), Vector3(0.0, -0.02, -0.47), wood_dark)
	_box(Vector3(0.115, 0.25, 0.12), Vector3(0.0, -0.16, -0.12), wood_dark, Vector3(deg_to_rad(17.0), 0.0, 0.0))
	_box(Vector3(0.14, 0.12, 0.46), Vector3(0.0, -0.01, 0.25), wood_dark)
	_box(Vector3(0.018, 0.055, 0.045), Vector3(0.0, 0.16, -0.88), metal_light)
	_box(Vector3(0.055, 0.025, 0.04), Vector3(0.0, 0.15, -0.07), metal_light)

func _build_ray_gun() -> void:
	super._build_ray_gun()
	_add_ray_sights(false)

func _build_ray_gun_mk2() -> void:
	super._build_ray_gun_mk2()
	_add_ray_sights(true)

func _add_ray_sights(mark_two: bool) -> void:
	var rear_z := -0.08 if mark_two else -0.06
	var front_z := -0.67 if mark_two else -0.54
	var sight_material: Material = ray_blue if mark_two else ray_green
	_box(Vector3(0.065, 0.018, 0.022), Vector3(0.0, 0.225, rear_z), metal_dark)
	_box(Vector3(0.015, 0.045, 0.020), Vector3(-0.030, 0.245, rear_z), sight_material)
	_box(Vector3(0.015, 0.045, 0.020), Vector3(0.030, 0.245, rear_z), sight_material)
	_box(Vector3(0.018, 0.050, 0.022), Vector3(0.0, 0.240, front_z), sight_material)

func muzzle_position_for(data: WeaponData) -> Vector3:
	if data == null:
		return super.muzzle_position_for(data)
	match data.id:
		&"mp5":
			return Vector3(0.0, 0.045, -0.90)
		&"olympia":
			return Vector3(0.0, 0.055, -1.06)
		_:
			return super.muzzle_position_for(data)
