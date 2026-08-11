class_name ZombieTownMysteryBox
extends ZombieTownInteractable

const BOX_COST := 950
const ROLL_DURATION := 2.55
const TAKE_TIMEOUT := 8.0
const BASE_CYCLE_INTERVAL := 0.065
const FINAL_CYCLE_INTERVAL := 0.23

const WEAPON_WEIGHTS := {
	&"m14": 12.0,
	&"olympia": 12.0,
	&"mp5": 12.0,
	&"ak74u": 12.0,
	&"galil": 12.0,
	&"rem870": 12.0,
	&"an94": 7.0,
	&"skorpion": 7.0,
	&"luger": 8.0,
	&"flaregun": 3.0,
	&"rpk": 6.0,
	&"hamr": 6.0,
	&"m1216": 6.0,
	&"dsr50": 5.0,
	&"raygun": 2.08,
	&"raygun2": 2.08,
	&"warmachine": 1.89,
	&"thunder": 1.6793,
	&"waffe": 1.6793
}

const WONDER_WEAPONS: Array[StringName] = [
	&"raygun", &"raygun2", &"warmachine", &"thunder", &"waffe"
]

const CYCLE_POOL: Array[StringName] = [
	&"m14", &"olympia", &"mp5", &"ak74u", &"galil", &"rem870",
	&"an94", &"skorpion", &"luger", &"flaregun", &"rpk", &"hamr",
	&"m1216", &"dsr50", &"raygun", &"raygun2", &"warmachine", &"thunder", &"waffe"
]

enum BoxState {
	IDLE,
	ROLLING,
	READY
}

var state: BoxState = BoxState.IDLE
var result_weapon_id: StringName = &""
var roll_elapsed := 0.0
var cycle_elapsed := 0.0
var ready_elapsed := 0.0
var cycle_index := 0
var dry_streak := 0
var rolling_player: ZombieTownPlayer

var lid_pivot: Node3D
var weapon_label: Label3D
var weapon_preview: MeshInstance3D
var box_light: OmniLight3D

func _ready() -> void:
	interaction_kind = &"mystery_box"
	item_id = &"mystery_box"
	display_name = "Mystery Box"
	cost = BOX_COST
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	_build_visuals()
	_update_idle_visual()

func _process(delta: float) -> void:
	match state:
		BoxState.ROLLING:
			_update_roll(delta)
		BoxState.READY:
			_update_ready(delta)
		_:
			pass

func prompt_for(_player: ZombieTownPlayer) -> String:
	match state:
		BoxState.IDLE:
			return "[E] Mystery Box  %d PTS" % BOX_COST
		BoxState.ROLLING:
			return "MYSTERY BOX  [SPINNING]"
		BoxState.READY:
			var weapon_data: WeaponData = ZombieTownWeaponCatalog.load_weapon(result_weapon_id)
			if weapon_data == null:
				return "MYSTERY BOX  [EMPTY]"
			return "[E] Take %s" % weapon_data.display_name
	return ""

func affordable_for(player: ZombieTownPlayer) -> bool:
	if player == null:
		return false
	if state == BoxState.IDLE:
		return player.points >= BOX_COST
	return true

func activate_for(player: ZombieTownPlayer) -> void:
	if player == null or not player.alive:
		return
	match state:
		BoxState.IDLE:
			_start_roll(player)
		BoxState.READY:
			_take_weapon(player)
		_:
			pass

func _start_roll(player: ZombieTownPlayer) -> void:
	if player.points < BOX_COST:
		return
	player.points -= BOX_COST
	player.stats_changed.emit(player.points, player.kills, player.headshots)
	rolling_player = player
	state = BoxState.ROLLING
	result_weapon_id = &""
	roll_elapsed = 0.0
	cycle_elapsed = 0.0
	ready_elapsed = 0.0
	cycle_index = randi_range(0, CYCLE_POOL.size() - 1)
	weapon_label.visible = true
	weapon_preview.visible = true
	box_light.light_energy = 3.2

func _update_roll(delta: float) -> void:
	roll_elapsed += delta
	cycle_elapsed += delta
	if lid_pivot != null:
		var lid_target := deg_to_rad(-82.0)
		lid_pivot.rotation.x = lerpf(lid_pivot.rotation.x, lid_target, 1.0 - exp(-delta * 11.0))
	if weapon_preview != null:
		weapon_preview.position.y = 1.88 + sin(roll_elapsed * 5.5) * 0.10
		weapon_preview.rotation.y += delta * 2.8
	if cycle_elapsed >= _current_cycle_interval():
		cycle_elapsed = 0.0
		cycle_index = (cycle_index + 1) % CYCLE_POOL.size()
		_show_weapon(CYCLE_POOL[cycle_index])
	if roll_elapsed >= ROLL_DURATION:
		_finish_roll()

func _current_cycle_interval() -> float:
	var progress := clampf(roll_elapsed / ROLL_DURATION, 0.0, 1.0)
	var eased := progress * progress * progress
	return lerpf(BASE_CYCLE_INTERVAL, FINAL_CYCLE_INTERVAL, eased)

func _finish_roll() -> void:
	state = BoxState.READY
	ready_elapsed = 0.0
	result_weapon_id = _choose_result()
	_show_weapon(result_weapon_id)
	if result_weapon_id in WONDER_WEAPONS:
		dry_streak = 0
		box_light.light_energy = 7.0
	else:
		dry_streak += 1
		box_light.light_energy = 5.0

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
	for weapon_variant: Variant in WEAPON_WEIGHTS.keys():
		var weapon_id := StringName(str(weapon_variant))
		if weapon_id in held_ids:
			continue
		var weight_variant: Variant = WEAPON_WEIGHTS.get(weapon_id, 0.0)
		var weight := float(weight_variant)
		if weapon_id in WONDER_WEAPONS:
			weight *= pity_multiplier
		weighted_ids.append(weapon_id)
		weighted_values.append(weight)
		total_weight += weight

	if weighted_ids.is_empty() or total_weight <= 0.0:
		return &"m14"
	var roll := randf() * total_weight
	for index in weighted_ids.size():
		roll -= weighted_values[index]
		if roll <= 0.0:
			return weighted_ids[index]
	return weighted_ids[weighted_ids.size() - 1]

func _update_ready(delta: float) -> void:
	ready_elapsed += delta
	if weapon_preview != null:
		weapon_preview.position.y = 1.92 + sin(ready_elapsed * 3.0) * 0.065
		weapon_preview.rotation.y += delta * 1.3
	if ready_elapsed >= TAKE_TIMEOUT:
		_reset_box()

func _take_weapon(player: ZombieTownPlayer) -> void:
	if result_weapon_id.is_empty():
		_reset_box()
		return
	var weapon_data: WeaponData = ZombieTownWeaponCatalog.load_weapon(result_weapon_id)
	if weapon_data == null:
		_reset_box()
		return
	player.equip_weapon(weapon_data)
	_reset_box()

func _reset_box() -> void:
	state = BoxState.IDLE
	result_weapon_id = &""
	rolling_player = null
	roll_elapsed = 0.0
	cycle_elapsed = 0.0
	ready_elapsed = 0.0
	_update_idle_visual()

func _update_idle_visual() -> void:
	if weapon_label != null:
		weapon_label.visible = false
	if weapon_preview != null:
		weapon_preview.visible = false
	if lid_pivot != null:
		lid_pivot.rotation.x = 0.0
	if box_light != null:
		box_light.light_color = Color(0.28, 0.62, 1.0, 1.0)
		box_light.light_energy = 1.1

func _show_weapon(weapon_id: StringName) -> void:
	var weapon_data: WeaponData = ZombieTownWeaponCatalog.load_weapon(weapon_id)
	if weapon_data == null:
		return
	weapon_label.text = weapon_data.display_name.to_upper()
	var preview_mesh := BoxMesh.new()
	preview_mesh.size = _preview_size_for(weapon_data.weapon_class)
	preview_mesh.material = _preview_material(weapon_data)
	weapon_preview.mesh = preview_mesh
	if weapon_data.weapon_class == &"wonder":
		weapon_label.modulate = Color(0.58, 1.0, 0.72, 1.0)
		box_light.light_color = Color(0.22, 1.0, 0.46, 1.0)
	else:
		weapon_label.modulate = Color(0.78, 0.90, 1.0, 1.0)
		box_light.light_color = Color(0.28, 0.62, 1.0, 1.0)

func _preview_size_for(weapon_class: StringName) -> Vector3:
	match weapon_class:
		&"shotgun":
			return Vector3(0.12, 0.12, 1.35)
		&"rifle":
			return Vector3(0.15, 0.16, 1.18)
		&"smg":
			return Vector3(0.15, 0.17, 0.84)
		&"lmg":
			return Vector3(0.20, 0.22, 1.38)
		&"sniper":
			return Vector3(0.12, 0.14, 1.55)
		&"wonder":
			return Vector3(0.22, 0.24, 0.92)
		_:
			return Vector3(0.12, 0.15, 0.55)

func _preview_material(weapon_data: WeaponData) -> StandardMaterial3D:
	var color := Color(0.22, 0.58, 1.0, 1.0)
	if weapon_data.weapon_class == &"wonder":
		color = Color(0.18, 1.0, 0.42, 1.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color.lightened(0.34)
	material.metallic = 0.35
	material.roughness = 0.28
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.4 if weapon_data.weapon_class != &"wonder" else 4.2
	return material

func _build_visuals() -> void:
	var collision_shape := BoxShape3D.new()
	collision_shape.size = Vector3(2.1, 1.05, 1.25)
	var collision := CollisionShape3D.new()
	collision.position = Vector3(0.0, 0.52, 0.0)
	collision.shape = collision_shape
	add_child(collision)

	var crate_material := StandardMaterial3D.new()
	crate_material.albedo_color = Color(0.16, 0.095, 0.045, 1.0)
	crate_material.roughness = 0.86
	crate_material.metallic = 0.08

	var trim_material := StandardMaterial3D.new()
	trim_material.albedo_color = Color(0.055, 0.06, 0.07, 1.0)
	trim_material.roughness = 0.48
	trim_material.metallic = 0.7

	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(2.0, 0.82, 1.12)
	base_mesh.material = crate_material
	var base := MeshInstance3D.new()
	base.name = "Crate"
	base.position = Vector3(0.0, 0.41, 0.0)
	base.mesh = base_mesh
	add_child(base)

	var band_positions: Array[float] = [-0.83, 0.83]
	for x_position: float in band_positions:
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(0.12, 0.88, 1.18)
		band_mesh.material = trim_material
		var band := MeshInstance3D.new()
		band.position = Vector3(x_position, 0.43, 0.0)
		band.mesh = band_mesh
		add_child(band)

	lid_pivot = Node3D.new()
	lid_pivot.name = "LidPivot"
	lid_pivot.position = Vector3(0.0, 0.84, 0.56)
	add_child(lid_pivot)
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(2.06, 0.16, 1.16)
	lid_mesh.material = crate_material
	var lid := MeshInstance3D.new()
	lid.position = Vector3(0.0, 0.0, -0.56)
	lid.mesh = lid_mesh
	lid_pivot.add_child(lid)

	weapon_preview = MeshInstance3D.new()
	weapon_preview.name = "WeaponPreview"
	weapon_preview.position = Vector3(0.0, 1.88, 0.0)
	weapon_preview.visible = false
	weapon_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(weapon_preview)

	weapon_label = Label3D.new()
	weapon_label.name = "WeaponLabel"
	weapon_label.position = Vector3(0.0, 2.48, 0.0)
	weapon_label.font_size = 30
	weapon_label.outline_size = 7
	weapon_label.modulate = Color(0.78, 0.90, 1.0, 1.0)
	weapon_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	weapon_label.visible = false
	add_child(weapon_label)

	box_light = OmniLight3D.new()
	box_light.name = "BoxLight"
	box_light.position = Vector3(0.0, 1.62, 0.0)
	box_light.light_color = Color(0.28, 0.62, 1.0, 1.0)
	box_light.light_energy = 1.1
	box_light.omni_range = 5.2
	add_child(box_light)
