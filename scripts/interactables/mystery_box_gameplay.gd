class_name ZombieTownGameplayMysteryBox
extends ZombieTownMysteryBox

const TEDDY_CHANCE := 0.10
const TEDDY_DISPLAY_TIME := 1.75
const RELOCATION_HIDDEN_TIME := 0.85
const LOCATOR_BEAM_TIME := 10.0

const GAMEPLAY_WEAPON_WEIGHTS := {
	&"mp7": 12.0,
	&"ak74u": 12.0,
	&"rem870": 12.0,
	&"ump": 7.0,
	&"hk416": 7.0,
	&"m16": 7.0,
	&"benelli_m4": 6.0,
	&"aa12": 6.0,
	&"rpd": 6.0,
	&"m200": 5.0,
	&"flaregun": 3.0,
	&"bknife": 5.0,
	&"rpg7": 1.89,
	&"raygun": 2.08,
	&"raygun2": 2.08,
	&"thunder": 1.6793,
	&"waffe": 1.6793
}

const GAMEPLAY_CYCLE_POOL: Array[StringName] = [
	&"mp7", &"ak74u", &"rem870", &"ump", &"hk416", &"m16",
	&"benelli_m4", &"aa12", &"rpd", &"m200", &"flaregun", &"bknife",
	&"rpg7", &"raygun", &"raygun2", &"thunder", &"waffe"
]

var teddy_active := false
var relocating := false
var relocation_elapsed := 0.0
var teddy_root: Node3D

func prompt_for(player: ZombieTownPlayer) -> String:
	if relocating:
		return "MYSTERY BOX  [MOVING]"
	if teddy_active:
		return "MYSTERY BOX  [TEDDY]"
	return super.prompt_for(player)

func affordable_for(player: ZombieTownPlayer) -> bool:
	if teddy_active or relocating:
		return true
	return super.affordable_for(player)

func activate_for(player: ZombieTownPlayer) -> void:
	if teddy_active or relocating:
		return
	super.activate_for(player)

func _update_roll(delta: float) -> void:
	roll_elapsed += delta
	cycle_elapsed += delta
	if lid_pivot != null:
		var lid_target: float = deg_to_rad(-82.0)
		lid_pivot.rotation.x = lerpf(lid_pivot.rotation.x, lid_target, 1.0 - exp(-delta * 11.0))
	if weapon_preview != null:
		weapon_preview.position.y = 1.88 + sin(roll_elapsed * 5.5) * 0.10
		weapon_preview.rotation.y += delta * 2.8
	if cycle_elapsed >= _current_cycle_interval():
		cycle_elapsed = 0.0
		cycle_index = (cycle_index + 1) % GAMEPLAY_CYCLE_POOL.size()
		_show_weapon(GAMEPLAY_CYCLE_POOL[cycle_index])
	if roll_elapsed >= ROLL_DURATION:
		_finish_roll()

func _finish_roll() -> void:
	if randf() <= TEDDY_CHANCE:
		_begin_teddy_result()
		return
	teddy_active = false
	relocating = false
	if teddy_root != null:
		teddy_root.visible = false
	super._finish_roll()

func _update_ready(delta: float) -> void:
	if not teddy_active:
		super._update_ready(delta)
		return

	if relocating:
		relocation_elapsed += delta
		if relocation_elapsed >= RELOCATION_HIDDEN_TIME:
			_finish_relocation()
		return

	ready_elapsed += delta
	if teddy_root != null:
		teddy_root.rotation.y += delta * 2.4
		teddy_root.position.y = 1.82 + ready_elapsed * 0.38 + sin(ready_elapsed * 5.0) * 0.05
	if ready_elapsed >= TEDDY_DISPLAY_TIME:
		_begin_relocation()

func _begin_teddy_result() -> void:
	state = BoxState.READY
	ready_elapsed = 0.0
	result_weapon_id = &""
	teddy_active = true
	relocating = false
	relocation_elapsed = 0.0
	_show_teddy()

func _show_teddy() -> void:
	if teddy_root == null:
		_build_teddy()
	if teddy_root != null:
		teddy_root.visible = true
		teddy_root.position = Vector3(0.0, 1.82, 0.0)
		teddy_root.rotation = Vector3.ZERO
	if weapon_preview != null:
		weapon_preview.visible = false
	if weapon_label != null:
		weapon_label.visible = true
		weapon_label.text = "TEDDY BEAR"
		weapon_label.modulate = Color(1.0, 0.62, 0.22, 1.0)
	if box_light != null:
		box_light.light_color = Color(1.0, 0.25, 0.08, 1.0)
		box_light.light_energy = 6.0

func _begin_relocation() -> void:
	if relocating:
		return
	relocating = true
	relocation_elapsed = 0.0
	collision_layer = 0
	monitorable = false
	visible = false

func _finish_relocation() -> void:
	var destination: Marker3D = _choose_relocation_marker()
	if destination != null:
		global_position = destination.global_position
		rotation.y = PI

	teddy_active = false
	relocating = false
	relocation_elapsed = 0.0
	if teddy_root != null:
		teddy_root.visible = false
	visible = true
	collision_layer = 4
	monitorable = true
	super._reset_box()
	_spawn_locator_beam()

func _choose_relocation_marker() -> Marker3D:
	var candidates: Array[Marker3D] = []
	var town_root: Node = get_parent()
	for marker_node: Node in get_tree().get_nodes_in_group(&"mystery_box_spot"):
		if not marker_node is Marker3D:
			continue
		var marker: Marker3D = marker_node as Marker3D
		if town_root != marker and not town_root.is_ancestor_of(marker):
			continue
		if marker.global_position.distance_squared_to(global_position) <= 1.0:
			continue
		candidates.append(marker)
	if candidates.is_empty():
		return null
	var chosen_index: int = randi_range(0, candidates.size() - 1)
	return candidates[chosen_index]

func _spawn_locator_beam() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.20, 0.62, 1.0, 0.48)
	material.emission_enabled = true
	material.emission = Color(0.15, 0.55, 1.0, 1.0)
	material.emission_energy_multiplier = 5.0

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.13
	mesh.bottom_radius = 0.20
	mesh.height = 22.0
	mesh.radial_segments = 12
	mesh.material = material

	var beam := MeshInstance3D.new()
	beam.name = "MysteryBoxLocatorBeam"
	beam.mesh = mesh
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(beam)
	beam.global_position = global_position + Vector3(0.0, 11.0, 0.0)

	var tween: Tween = beam.create_tween()
	tween.tween_interval(LOCATOR_BEAM_TIME - 1.0)
	tween.tween_property(beam, "modulate:a", 0.0, 1.0)
	tween.tween_callback(beam.queue_free)

func _build_teddy() -> void:
	teddy_root = Node3D.new()
	teddy_root.name = "TeddyPreview"
	teddy_root.visible = false
	add_child(teddy_root)

	var fur_material := StandardMaterial3D.new()
	fur_material.albedo_color = Color(0.36, 0.18, 0.075, 1.0)
	fur_material.roughness = 0.95
	var muzzle_material := StandardMaterial3D.new()
	muzzle_material.albedo_color = Color(0.66, 0.43, 0.22, 1.0)
	muzzle_material.roughness = 0.95
	var dark_material := StandardMaterial3D.new()
	dark_material.albedo_color = Color(0.025, 0.018, 0.012, 1.0)
	dark_material.roughness = 0.90

	_add_teddy_sphere(Vector3(0.0, 0.16, 0.0), Vector3(0.34, 0.40, 0.28), fur_material)
	_add_teddy_sphere(Vector3(0.0, 0.52, -0.01), Vector3(0.28, 0.28, 0.25), fur_material)
	_add_teddy_sphere(Vector3(-0.19, 0.68, 0.0), Vector3(0.10, 0.10, 0.08), fur_material)
	_add_teddy_sphere(Vector3(0.19, 0.68, 0.0), Vector3(0.10, 0.10, 0.08), fur_material)
	_add_teddy_sphere(Vector3(0.0, 0.47, -0.22), Vector3(0.14, 0.10, 0.07), muzzle_material)
	_add_teddy_sphere(Vector3(-0.09, 0.58, -0.22), Vector3(0.030, 0.030, 0.024), dark_material)
	_add_teddy_sphere(Vector3(0.09, 0.58, -0.22), Vector3(0.030, 0.030, 0.024), dark_material)
	_add_teddy_sphere(Vector3(0.0, 0.49, -0.285), Vector3(0.035, 0.028, 0.025), dark_material)
	_add_teddy_sphere(Vector3(-0.29, 0.22, 0.0), Vector3(0.11, 0.26, 0.10), fur_material, Vector3(0.0, 0.0, deg_to_rad(-26.0)))
	_add_teddy_sphere(Vector3(0.29, 0.22, 0.0), Vector3(0.11, 0.26, 0.10), fur_material, Vector3(0.0, 0.0, deg_to_rad(26.0)))
	_add_teddy_sphere(Vector3(-0.15, -0.16, 0.0), Vector3(0.13, 0.24, 0.12), fur_material, Vector3(0.0, 0.0, deg_to_rad(-8.0)))
	_add_teddy_sphere(Vector3(0.15, -0.16, 0.0), Vector3(0.13, 0.24, 0.12), fur_material, Vector3(0.0, 0.0, deg_to_rad(8.0)))

func _add_teddy_sphere(position: Vector3, scale_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = material
	var part := MeshInstance3D.new()
	part.position = position
	part.rotation = rotation_value
	part.scale = scale_value
	part.mesh = mesh
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	teddy_root.add_child(part)

func _choose_result() -> StringName:
	var total_weight := 0.0
	var weighted_ids: Array[StringName] = []
	var weighted_values: Array[float] = []
	var held_ids: Array[StringName] = []
	if rolling_player is ZombieTownInventoryPlayer:
		var inventory_player := rolling_player as ZombieTownInventoryPlayer
		held_ids = inventory_player.get_held_weapon_ids()
	elif rolling_player != null and rolling_player.weapon != null:
		held_ids.append(rolling_player.weapon.id)

	var pity_multiplier := minf(4.0, 1.0 + float(dry_streak) * 0.13)
	for weapon_variant: Variant in GAMEPLAY_WEAPON_WEIGHTS.keys():
		var weapon_id := StringName(str(weapon_variant))
		if weapon_id in held_ids or not ZombieTownWeaponCatalog.is_standard_gameplay_weapon(weapon_id):
			continue
		var weight_variant: Variant = GAMEPLAY_WEAPON_WEIGHTS.get(weapon_id, 0.0)
		var weight := float(weight_variant)
		if weapon_id in WONDER_WEAPONS:
			weight *= pity_multiplier
		weighted_ids.append(weapon_id)
		weighted_values.append(weight)
		total_weight += weight

	if weighted_ids.is_empty() or total_weight <= 0.0:
		return &"ak74u"
	var roll := randf() * total_weight
	for index in weighted_ids.size():
		roll -= weighted_values[index]
		if roll <= 0.0:
			return weighted_ids[index]
	return weighted_ids[weighted_ids.size() - 1]
