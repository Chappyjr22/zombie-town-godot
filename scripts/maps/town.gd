class_name ZombieTownTown
extends Node3D

signal navigation_ready

const MAP_HALF_SIZE := 42.0
const NAV_SOURCE_GROUP := &"town_navigation_source"

@export var runtime_bake_navigation := true

var navigation_region: NavigationRegion3D
var navigation_mesh: NavigationMesh
var geometry_root: Node3D
var markers_root: Node3D

var asphalt_material: StandardMaterial3D
var sidewalk_material: StandardMaterial3D
var brick_material: StandardMaterial3D
var stucco_material: StandardMaterial3D
var siding_material: StandardMaterial3D
var church_material: StandardMaterial3D
var roof_material: StandardMaterial3D
var fountain_material: StandardMaterial3D
var bus_material: StandardMaterial3D

func _ready() -> void:
	_build_materials()
	_build_lighting()
	_build_navigation_region()
	_build_geometry()
	_build_gameplay_markers()
	if runtime_bake_navigation:
		call_deferred("_bake_navigation")

func _build_materials() -> void:
	asphalt_material = _material(Color(0.075, 0.078, 0.085, 1.0), 0.98)
	sidewalk_material = _material(Color(0.20, 0.205, 0.21, 1.0), 0.94)
	brick_material = _material(Color(0.29, 0.12, 0.085, 1.0), 0.90)
	stucco_material = _material(Color(0.34, 0.335, 0.30, 1.0), 0.94)
	siding_material = _material(Color(0.24, 0.27, 0.25, 1.0), 0.92)
	church_material = _material(Color(0.44, 0.43, 0.38, 1.0), 0.92)
	roof_material = _material(Color(0.075, 0.07, 0.065, 1.0), 0.96)
	fountain_material = _material(Color(0.30, 0.31, 0.32, 1.0), 0.98)
	bus_material = _material(Color(0.17, 0.21, 0.18, 1.0), 0.86)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.023, 0.035, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.22, 0.26, 0.36, 1.0)
	environment.ambient_light_energy = 0.48
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.055, 0.065, 0.09, 1.0)
	environment.fog_density = 0.012
	environment.fog_height = 0.0
	environment.fog_height_density = 0.08

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	moon.light_color = Color(0.56, 0.66, 0.88, 1.0)
	moon.light_energy = 1.05
	moon.shadow_enabled = true
	add_child(moon)

func _build_navigation_region() -> void:
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "NavigationRegion3D"
	navigation_mesh = NavigationMesh.new()
	navigation_mesh.agent_radius = 0.45
	navigation_mesh.agent_height = 1.8
	navigation_mesh.agent_max_climb = 0.35
	navigation_mesh.agent_max_slope = 45.0
	navigation_mesh.cell_size = 0.22
	navigation_mesh.cell_height = 0.18
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navigation_mesh.geometry_source_group_name = NAV_SOURCE_GROUP
	navigation_mesh.filter_baking_aabb = AABB(Vector3(-44.0, -2.0, -44.0), Vector3(88.0, 14.0, 88.0))
	navigation_region.navigation_mesh = navigation_mesh
	navigation_region.bake_finished.connect(_on_navigation_bake_finished)
	add_child(navigation_region)

func _build_geometry() -> void:
	geometry_root = Node3D.new()
	geometry_root.name = "Geometry"
	geometry_root.add_to_group(NAV_SOURCE_GROUP)
	add_child(geometry_root)

	_add_static_box(geometry_root, "Ground", Vector3(0.0, -0.30, 0.0), Vector3(84.0, 0.60, 84.0), sidewalk_material)
	_add_visual_box(geometry_root, "RoadEastWest", Vector3(0.0, 0.015, 0.0), Vector3(84.0, 0.03, 13.5), asphalt_material)
	_add_visual_box(geometry_root, "RoadNorthSouth", Vector3(0.0, 0.02, 0.0), Vector3(13.5, 0.04, 84.0), asphalt_material)

	_build_bar()
	_build_bank()
	_build_church()
	_build_diner()
	_build_store()
	_build_fountain()
	_build_bus()

func _build_bar() -> void:
	var building := _building_root("Bar")
	var x1 := -30.0
	var x2 := -14.0
	var z1 := -26.0
	var z2 := -6.0
	var height := 8.6
	_add_floor(building, x1, x2, z1, z2, sidewalk_material)
	_add_visual_roof(building, x1, x2, z1, z2, height)
	_add_horizontal_wall(building, z1, x1, x2, height, brick_material)
	_add_horizontal_wall_with_gap(building, z2, x1, x2, height, -20.0, 3.4, brick_material)
	_add_vertical_wall(building, x1, z1, z2, height, brick_material)
	_add_vertical_wall_with_gap(building, x2, z1, z2, height, -16.0, 3.4, brick_material)
	_add_visual_box(building, "UpperFloor", Vector3(-22.0, 4.0, -11.0), Vector3(15.2, 0.18, 9.0), roof_material)
	_add_visual_box(building, "Balcony", Vector3(-12.9, 4.15, -11.5), Vector3(2.1, 0.18, 8.5), roof_material)

func _build_bank() -> void:
	var building := _building_root("Bank")
	var x1 := 14.0
	var x2 := 31.0
	var z1 := -22.0
	var z2 := -6.0
	var height := 9.2
	_add_floor(building, x1, x2, z1, z2, sidewalk_material)
	_add_visual_roof(building, x1, x2, z1, z2, height)
	_add_horizontal_wall(building, z1, x1, x2, height, stucco_material)
	_add_horizontal_wall_with_gap(building, z2, x1, x2, height, 24.0, 3.4, stucco_material)
	_add_vertical_wall_with_gap(building, x1, z1, z2, height, -16.0, 3.4, stucco_material)
	_add_vertical_wall(building, x2, z1, z2, height, stucco_material)
	_add_static_box(building, "Vault", Vector3(27.0, 1.6, -18.0), Vector3(5.2, 3.2, 5.2), _material(Color(0.16, 0.17, 0.18, 1.0), 0.72))

func _build_church() -> void:
	var building := _building_root("Church")
	var x1 := -9.0
	var x2 := 9.0
	var z1 := 20.0
	var z2 := 36.0
	var height := 10.5
	_add_floor(building, x1, x2, z1, z2, sidewalk_material)
	_add_visual_roof(building, x1, x2, z1, z2, height)
	_add_horizontal_wall_with_gap(building, z1, x1, x2, height, 0.0, 3.6, church_material)
	_add_horizontal_wall(building, z2, x1, x2, height, church_material)
	_add_vertical_wall(building, x1, z1, z2, height, church_material)
	_add_vertical_wall(building, x2, z1, z2, height, church_material)
	_add_visual_box(building, "Tower", Vector3(0.0, 14.0, 30.0), Vector3(4.2, 7.0, 4.2), church_material)

func _build_diner() -> void:
	var building := _building_root("Diner")
	var x1 := -31.0
	var x2 := -17.0
	var z1 := 8.0
	var z2 := 20.0
	var height := 6.4
	_add_floor(building, x1, x2, z1, z2, sidewalk_material)
	_add_visual_roof(building, x1, x2, z1, z2, height)
	_add_horizontal_wall(building, z1, x1, x2, height, siding_material)
	_add_horizontal_wall(building, z2, x1, x2, height, siding_material)
	_add_vertical_wall(building, x1, z1, z2, height, siding_material)
	_add_vertical_wall_with_gap(building, x2, z1, z2, height, 14.0, 3.4, siding_material)

func _build_store() -> void:
	var building := _building_root("GeneralStore")
	var x1 := 17.0
	var x2 := 31.0
	var z1 := 8.0
	var z2 := 20.0
	var height := 6.4
	_add_floor(building, x1, x2, z1, z2, sidewalk_material)
	_add_visual_roof(building, x1, x2, z1, z2, height)
	_add_horizontal_wall(building, z1, x1, x2, height, brick_material)
	_add_horizontal_wall(building, z2, x1, x2, height, brick_material)
	_add_vertical_wall_with_gap(building, x1, z1, z2, height, 14.0, 3.4, brick_material)
	_add_vertical_wall(building, x2, z1, z2, height, brick_material)

func _build_fountain() -> void:
	var body := StaticBody3D.new()
	body.name = "Fountain"
	body.position = Vector3(0.0, 0.5, 0.0)
	geometry_root.add_child(body)

	var shape := CylinderShape3D.new()
	shape.radius = 3.5
	shape.height = 1.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var mesh := CylinderMesh.new()
	mesh.top_radius = 3.3
	mesh.bottom_radius = 3.5
	mesh.height = 1.0
	mesh.radial_segments = 40
	mesh.material = fountain_material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	var fire_light := OmniLight3D.new()
	fire_light.name = "FireLight"
	fire_light.position = Vector3(0.0, 2.7, 0.0)
	fire_light.light_color = Color(1.0, 0.28, 0.06, 1.0)
	fire_light.light_energy = 5.0
	fire_light.omni_range = 13.0
	body.add_child(fire_light)

	for i in 3:
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.55 + float(i) * 0.18
		flame_mesh.height = 1.2 + float(i) * 0.45
		var flame_material := StandardMaterial3D.new()
		flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame_material.albedo_color = Color(1.0, 0.16 + float(i) * 0.09, 0.02, 0.62)
		flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flame_mesh.material = flame_material
		var flame := MeshInstance3D.new()
		flame.mesh = flame_mesh
		flame.position = Vector3(float(i - 1) * 0.55, 1.35 + float(i) * 0.28, 0.0)
		body.add_child(flame)

func _build_bus() -> void:
	var bus := _add_static_box(geometry_root, "WreckedBus", Vector3(8.5, 1.35, -1.8), Vector3(3.0, 2.7, 9.5), bus_material)
	bus.rotation.y = deg_to_rad(-12.0)

func _building_root(node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	geometry_root.add_child(node)
	return node

func _add_floor(parent: Node3D, x1: float, x2: float, z1: float, z2: float, material: Material) -> void:
	var center := Vector3((x1 + x2) * 0.5, 0.035, (z1 + z2) * 0.5)
	var size := Vector3(x2 - x1, 0.07, z2 - z1)
	_add_visual_box(parent, "Floor", center, size, material)

func _add_visual_roof(parent: Node3D, x1: float, x2: float, z1: float, z2: float, height: float) -> void:
	var center := Vector3((x1 + x2) * 0.5, height, (z1 + z2) * 0.5)
	var size := Vector3(x2 - x1 + 0.5, 0.22, z2 - z1 + 0.5)
	_add_visual_box(parent, "Roof", center, size, roof_material)

func _add_horizontal_wall(parent: Node3D, z: float, x1: float, x2: float, height: float, material: Material) -> void:
	_add_static_box(parent, "Wall", Vector3((x1 + x2) * 0.5, height * 0.5, z), Vector3(x2 - x1, height, 0.36), material)

func _add_horizontal_wall_with_gap(parent: Node3D, z: float, x1: float, x2: float, height: float, gap_center: float, gap_width: float, material: Material) -> void:
	var gap_left := gap_center - gap_width * 0.5
	var gap_right := gap_center + gap_width * 0.5
	if gap_left > x1:
		_add_static_box(parent, "Wall", Vector3((x1 + gap_left) * 0.5, height * 0.5, z), Vector3(gap_left - x1, height, 0.36), material)
	if gap_right < x2:
		_add_static_box(parent, "Wall", Vector3((gap_right + x2) * 0.5, height * 0.5, z), Vector3(x2 - gap_right, height, 0.36), material)

func _add_vertical_wall(parent: Node3D, x: float, z1: float, z2: float, height: float, material: Material) -> void:
	_add_static_box(parent, "Wall", Vector3(x, height * 0.5, (z1 + z2) * 0.5), Vector3(0.36, height, z2 - z1), material)

func _add_vertical_wall_with_gap(parent: Node3D, x: float, z1: float, z2: float, height: float, gap_center: float, gap_width: float, material: Material) -> void:
	var gap_near := gap_center - gap_width * 0.5
	var gap_far := gap_center + gap_width * 0.5
	if gap_near > z1:
		_add_static_box(parent, "Wall", Vector3(x, height * 0.5, (z1 + gap_near) * 0.5), Vector3(0.36, height, gap_near - z1), material)
	if gap_far < z2:
		_add_static_box(parent, "Wall", Vector3(x, height * 0.5, (gap_far + z2) * 0.5), Vector3(0.36, height, z2 - gap_far), material)

func _add_static_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 3
	parent.add_child(body)

	var box_shape := BoxShape3D.new()
	box_shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = box_shape
	body.add_child(collision)

	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = box_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(mesh_instance)
	return body

func _add_visual_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.mesh = box_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance)
	return mesh_instance

func _build_gameplay_markers() -> void:
	markers_root = Node3D.new()
	markers_root.name = "GameplayMarkers"
	add_child(markers_root)

	_add_marker("PlayerSpawn", Vector3(0.0, 0.06, 14.0), &"player_spawn", {"yaw": PI})

	var zombie_spawns: Array[Vector3] = [
		Vector3(-38.0, 0.05, -38.0), Vector3(38.0, 0.05, -38.0),
		Vector3(-38.0, 0.05, 38.0), Vector3(38.0, 0.05, 38.0),
		Vector3(0.0, 0.05, -40.0), Vector3(0.0, 0.05, 40.0),
		Vector3(-40.0, 0.05, 0.0), Vector3(40.0, 0.05, 0.0),
		Vector3(-26.0, 0.05, -38.0), Vector3(26.0, 0.05, 38.0),
		Vector3(-38.0, 0.05, 22.0), Vector3(38.0, 0.05, -22.0)
	]
	for i in zombie_spawns.size():
		_add_marker("ZombieSpawn%02d" % i, zombie_spawns[i], &"zombie_spawn")

	var box_spots: Array[Vector3] = [
		Vector3(-20.54, 0.05, -17.05), Vector3(22.0, 0.05, -15.0),
		Vector3(0.29, 0.05, 4.08), Vector3(-24.0, 0.05, 15.0),
		Vector3(6.0, 0.05, -30.0)
	]
	for i in box_spots.size():
		_add_marker("MysteryBox%02d" % i, box_spots[i], &"mystery_box_spot")

	_add_inactive_buy_marker("M14", Vector3(13.7, 2.3, -12.5), "m14", -PI * 0.5)
	_add_inactive_buy_marker("Olympia", Vector3(-26.0, 2.2, -6.2), "olympia", PI)
	_add_buy_marker("MP7", Vector3(-16.7, 2.2, 10.5), &"wall_buy", "mp7", PI * 0.5)
	_add_buy_marker("AK74U", Vector3(5.5, 2.4, 19.7), &"wall_buy", "ak74u", PI)
	_add_buy_marker("Remington870", Vector3(-13.7, 2.2, -19.5), &"wall_buy", "rem870", PI * 0.5)
	_add_buy_marker("M1911Ammo", Vector3(-20.0, 2.2, 20.3), &"ammo_buy", "m1911", 0.0)
	_add_buy_marker("HK416Ammo", Vector3(30.7, 2.2, -9.0), &"ammo_buy", "hk416", -PI * 0.5)

	_add_buy_marker("Juggernog", Vector3(-28.6, 0.05, -9.0), &"perk_spot", "jugg", -PI * 0.5)
	_add_buy_marker("SpeedCola", Vector3(18.0, 0.05, -20.8), &"perk_spot", "speed", PI)
	_add_buy_marker("QuickRevive", Vector3(-6.0, 0.05, 18.9), &"perk_spot", "revive", 0.0)
	_add_buy_marker("DoubleTap", Vector3(-7.9, 0.05, 28.0), &"perk_spot", "dtap", -PI * 0.5)
	_add_buy_marker("StaminUp", Vector3(29.9, 0.05, 12.0), &"perk_spot", "stamin", PI * 0.5)
	_add_buy_marker("MuleKick", Vector3(-27.0, 0.05, 8.9), &"perk_spot", "mule", PI)
	_add_buy_marker("PackAPunch", Vector3(-0.36, 0.08, -4.18), &"pack_a_punch_spot", "pap", 0.0)
	_add_buy_marker("Grenades", Vector3(-3.0, 0.05, 19.23), &"equipment_buy", "grenade", TAU)
	_add_buy_marker("Claymores", Vector3(2.96, 0.05, 19.05), &"equipment_buy", "claymore", TAU)

func _add_buy_marker(node_name: String, position: Vector3, group_name: StringName, item_id: String, yaw: float) -> void:
	_add_marker(node_name, position, group_name, {"item_id": item_id, "yaw": yaw})

func _add_inactive_buy_marker(node_name: String, position: Vector3, former_item_id: String, yaw: float) -> void:
	_add_marker(
		node_name,
		position,
		&"inactive_wall_buy",
		{"former_item_id": former_item_id, "yaw": yaw, "inactive": true}
	)

func _add_marker(node_name: String, position: Vector3, group_name: StringName, metadata: Dictionary = {}) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = node_name
	marker.position = position
	marker.add_to_group(group_name)
	for key_variant: Variant in metadata.keys():
		marker.set_meta(StringName(str(key_variant)), metadata[key_variant])
	markers_root.add_child(marker)
	return marker

func _bake_navigation() -> void:
	if navigation_region == null or navigation_mesh == null:
		return
	navigation_region.bake_navigation_mesh(true)

func _on_navigation_bake_finished() -> void:
	navigation_ready.emit()
