class_name ZombieTownWeaponViewmodelProduction
extends ZombieTownWeaponViewmodelVideoTuned

var imported_muzzle_positions: Dictionary = {}

func set_weapon(data: WeaponData) -> void:
	if data == null:
		return
	if _try_build_production_asset(data):
		return
	if data.id == &"mp5" or data.id == &"olympia" or data.id == &"bknife":
		current_weapon_id = data.id
		_clear_children(model_root)
		_clear_children(arms_root)
		if data.id == &"mp5":
			_build_suomi()
			_build_arms(data.weapon_class)
		elif data.id == &"olympia":
			_build_olympia()
			_build_arms(data.weapon_class)
		else:
			_build_ballistic_knife()
			_build_pistol_hands()
		return
	super.set_weapon(data)

func _try_build_production_asset(data: WeaponData) -> bool:
	if not ZombieTownProductionWeaponAssets.supports(data.id):
		return false
	if not ZombieTownProductionWeaponAssets.asset_available(data.id):
		return false
	var asset_path: String = ZombieTownProductionWeaponAssets.asset_path(data.id)
	var loaded_resource: Resource = ResourceLoader.load(asset_path)
	if not loaded_resource is PackedScene:
		push_warning("Production weapon asset is not a PackedScene: %s" % asset_path)
		return false
	var packed_scene: PackedScene = loaded_resource as PackedScene
	var instance_node: Node = packed_scene.instantiate()
	if not instance_node is Node3D:
		instance_node.queue_free()
		push_warning("Production weapon asset root is not Node3D: %s" % asset_path)
		return false

	current_weapon_id = data.id
	_clear_children(model_root)
	_clear_children(arms_root)
	imported_muzzle_positions.erase(data.id)

	var anchor := Node3D.new()
	anchor.name = "ProductionAssetAnchor"
	model_root.add_child(anchor)
	var asset_root: Node3D = instance_node as Node3D
	asset_root.name = "ImportedWeapon"
	anchor.add_child(asset_root)
	asset_root.rotation = ZombieTownProductionWeaponAssets.rotation_radians(data.id)
	_prepare_imported_meshes(asset_root)
	_auto_orient_long_axis(asset_root, anchor)
	_normalize_imported_weapon(asset_root, anchor, data.id)
	_remove_known_loose_components(asset_root, data.id)
	_build_arms(data.weapon_class)
	return true

func _remove_known_loose_components(asset_root: Node3D, weapon_id: StringName) -> void:
	if weapon_id != &"m1911":
		return
	var loose_magazine: Node = asset_root.find_child("Magazine", true, false)
	if loose_magazine != null:
		loose_magazine.free()

func _prepare_imported_meshes(root: Node) -> void:
	if root is MeshInstance3D:
		var root_mesh := root as MeshInstance3D
		root_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in root.get_children():
		_prepare_imported_meshes(child)

func _auto_orient_long_axis(asset_root: Node3D, anchor: Node3D) -> void:
	var bounds: AABB = _bounds_for_subtree(asset_root, anchor)
	if bounds.size.length_squared() <= 0.000001:
		return
	if bounds.size.x > bounds.size.z * 1.18 and bounds.size.x >= bounds.size.y:
		asset_root.rotation.y += deg_to_rad(90.0)
	elif bounds.size.y > bounds.size.z * 1.18 and bounds.size.y >= bounds.size.x:
		asset_root.rotation.x += deg_to_rad(90.0)

func _normalize_imported_weapon(asset_root: Node3D, anchor: Node3D, weapon_id: StringName) -> void:
	var bounds: AABB = _bounds_for_subtree(asset_root, anchor)
	if bounds.size.length_squared() <= 0.000001:
		push_warning("Production weapon has no measurable mesh bounds: %s" % weapon_id)
		return
	var source_length: float = maxf(bounds.size.z, 0.0001)
	var target_length: float = ZombieTownProductionWeaponAssets.target_length(weapon_id)
	var uniform_scale: float = target_length / source_length
	asset_root.scale = Vector3.ONE * uniform_scale

	bounds = _bounds_for_subtree(asset_root, anchor)
	var center: Vector3 = bounds.position + bounds.size * 0.5
	var desired_back_z: float = ZombieTownProductionWeaponAssets.back_z(weapon_id)
	asset_root.position += Vector3(-center.x, -center.y, desired_back_z - bounds.end.z)

	bounds = _bounds_for_subtree(asset_root, anchor)
	var muzzle_y: float = bounds.position.y + bounds.size.y * 0.57
	var muzzle_position := Vector3(0.0, muzzle_y, bounds.position.z - 0.025)
	imported_muzzle_positions[weapon_id] = muzzle_position

func _bounds_for_subtree(subtree: Node, relative_to: Node3D) -> AABB:
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(subtree, mesh_instances)
	if mesh_instances.is_empty():
		return AABB()
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var relative_inverse: Transform3D = relative_to.global_transform.affine_inverse()
	for mesh_instance: MeshInstance3D in mesh_instances:
		if mesh_instance.mesh == null:
			continue
		var local_bounds: AABB = mesh_instance.get_aabb()
		var to_relative: Transform3D = relative_inverse * mesh_instance.global_transform
		for x_index in 2:
			for y_index in 2:
				for z_index in 2:
					var corner := local_bounds.position + Vector3(
						local_bounds.size.x * float(x_index),
						local_bounds.size.y * float(y_index),
						local_bounds.size.z * float(z_index)
					)
					var point: Vector3 = to_relative * corner
					minimum = Vector3(
						minf(minimum.x, point.x),
						minf(minimum.y, point.y),
						minf(minimum.z, point.z)
					)
					maximum = Vector3(
						maxf(maximum.x, point.x),
						maxf(maximum.y, point.y),
						maxf(maximum.z, point.z)
					)
	if minimum.x == INF:
		return AABB()
	return AABB(minimum, maximum - minimum)

func _collect_mesh_instances(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_mesh_instances(child, output)

func _build_suomi() -> void:
	_cylinder(0.055, 0.42, Vector3(0.0, 0.045, -0.27), metal_mid)
	_cylinder(0.048, 0.39, Vector3(0.0, 0.045, -0.64), metal_dark)
	_cylinder(0.062, 0.08, Vector3(0.0, 0.045, -0.86), metal_mid)
	_box(Vector3(0.12, 0.12, 0.20), Vector3(0.0, 0.0, -0.05), metal_mid)
	_box(Vector3(0.105, 0.25, 0.10), Vector3(0.0, -0.16, -0.10), wood_dark, Vector3(deg_to_rad(18.0), 0.0, 0.0))
	_box(Vector3(0.13, 0.11, 0.39), Vector3(0.0, -0.015, 0.25), wood_dark)
	_cylinder(0.13, 0.075, Vector3(0.0, -0.105, -0.33), metal_dark, Vector3(0.0, 0.0, deg_to_rad(90.0)))
	_cylinder(0.105, 0.082, Vector3(0.0, -0.105, -0.33), metal_mid, Vector3(0.0, 0.0, deg_to_rad(90.0)))
	_box(Vector3(0.018, 0.055, 0.045), Vector3(0.0, 0.14, -0.77), metal_light)
	_box(Vector3(0.05, 0.025, 0.035), Vector3(0.0, 0.135, -0.05), metal_light)

func _build_olympia() -> void:
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

func _build_ballistic_knife() -> void:
	_box(Vector3(0.075, 0.070, 0.20), Vector3(0.0, 0.005, 0.03), metal_mid)
	_cylinder(0.028, 0.20, Vector3(0.0, 0.025, -0.05), metal_dark, Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_box(Vector3(0.040, 0.018, 0.31), Vector3(0.0, 0.025, -0.28), metal_light)
	_box(Vector3(0.082, 0.025, 0.05), Vector3(0.0, 0.025, -0.11), metal_light)
	_box(Vector3(0.080, 0.20, 0.09), Vector3(0.0, -0.115, 0.06), polymer_dark, Vector3(deg_to_rad(15.0), 0.0, 0.0))
	_box(Vector3(0.018, 0.042, 0.030), Vector3(0.0, 0.080, -0.30), metal_light)

func _build_ray_gun() -> void:
	super._build_ray_gun()
	_add_ray_sights(false)

func _build_ray_gun_mk2() -> void:
	super._build_ray_gun_mk2()
	_add_ray_sights(true)

func _add_ray_sights(mark_two: bool) -> void:
	var rear_z: float = -0.08 if mark_two else -0.06
	var front_z: float = -0.67 if mark_two else -0.54
	var sight_material: Material = ray_blue if mark_two else ray_green
	_box(Vector3(0.065, 0.018, 0.022), Vector3(0.0, 0.225, rear_z), metal_dark)
	_box(Vector3(0.015, 0.045, 0.020), Vector3(-0.030, 0.245, rear_z), sight_material)
	_box(Vector3(0.015, 0.045, 0.020), Vector3(0.030, 0.245, rear_z), sight_material)
	_box(Vector3(0.018, 0.050, 0.022), Vector3(0.0, 0.240, front_z), sight_material)

func muzzle_position_for(data: WeaponData) -> Vector3:
	if data == null:
		return super.muzzle_position_for(data)
	var imported_variant: Variant = imported_muzzle_positions.get(data.id)
	if imported_variant is Vector3:
		return imported_variant
	match data.id:
		&"mp5":
			return Vector3(0.0, 0.045, -0.90)
		&"olympia":
			return Vector3(0.0, 0.055, -1.06)
		&"bknife":
			return Vector3(0.0, 0.025, -0.46)
		_:
			return super.muzzle_position_for(data)
