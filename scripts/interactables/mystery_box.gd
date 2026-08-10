class_name ZombieTownMysteryBox
extends ZombieTownInteractable

const BOX_COST := 950
const ROLL_DURATION := 2.35
const CYCLE_INTERVAL := 0.085
const TAKE_TIMEOUT := 8.0
const WEAPON_POOL: Array[StringName] = [
	&"m14", &"olympia", &"mp5", &"ak74u", &"galil", &"rem870"
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

func prompt_for(player: ZombieTownPlayer) -> String:
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
	state = BoxState.ROLLING
	result_weapon_id = &""
	roll_elapsed = 0.0
	cycle_elapsed = 0.0
	ready_elapsed = 0.0
	cycle_index = randi_range(0, WEAPON_POOL.size() - 1)
	weapon_label.visible = true
	weapon_preview.visible = true
	box_light.light_energy = 3.2

func _update_roll(delta: float) -> void:
	roll_elapsed += delta
	cycle_elapsed += delta
	if lid_pivot != null:
		var lid_target := deg_to_rad(-78.0)
		lid_pivot.rotation.x = lerpf(lid_pivot.rotation.x, lid_target, 1.0 - exp(-delta * 10.0))
	if weapon_preview != null:
		weapon_preview.position.y = 1.75 + sin(roll_elapsed * 5.5) * 0.09
		weapon_preview.rotation.y += delta * 2.6
	if cycle_elapsed >= CYCLE_INTERVAL:
		cycle_elapsed = 0.0
		cycle_index = (cycle_index + 1) % WEAPON_POOL.size()
		_show_weapon(WEAPON_POOL[cycle_index])
	if roll_elapsed >= ROLL_DURATION:
		_finish_roll()

func _finish_roll() -> void:
	state = BoxState.READY
	ready_elapsed = 0.0
	result_weapon_id = WEAPON_POOL[randi_range(0, WEAPON_POOL.size() - 1)]
	_show_weapon(result_weapon_id)
	box_light.light_energy = 5.0

func _update_ready(delta: float) -> void:
	ready_elapsed += delta
	if weapon_preview != null:
		weapon_preview.position.y = 1.78 + sin(ready_elapsed * 3.0) * 0.06
		weapon_preview.rotation.y += delta * 1.35
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
		box_light.light_energy = 1.1

func _show_weapon(weapon_id: StringName) -> void:
	var weapon_data: WeaponData = ZombieTownWeaponCatalog.load_weapon(weapon_id)
	if weapon_data == null:
		return
	weapon_label.text = weapon_data.display_name.to_upper()
	var preview_mesh := BoxMesh.new()
	preview_mesh.size = _preview_size_for(weapon_data.weapon_class)
	preview_mesh.material = _preview_material()
	weapon_preview.mesh = preview_mesh

func _preview_size_for(weapon_class: StringName) -> Vector3:
	match weapon_class:
		&"shotgun":
			return Vector3(0.12, 0.12, 1.35)
		&"rifle":
			return Vector3(0.15, 0.16, 1.18)
		&"smg":
			return Vector3(0.15, 0.17, 0.84)
		_:
			return Vector3(0.12, 0.15, 0.55)

func _preview_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.82, 1.0, 1.0)
	material.metallic = 0.35
	material.roughness = 0.28
	material.emission_enabled = true
	material.emission = Color(0.22, 0.58, 1.0, 1.0)
	material.emission_energy_multiplier = 2.1
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

	for x_position: float in [-0.83, 0.83]:
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
	weapon_preview.position = Vector3(0.0, 1.75, 0.0)
	weapon_preview.visible = false
	weapon_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(weapon_preview)

	weapon_label = Label3D.new()
	weapon_label.name = "WeaponLabel"
	weapon_label.position = Vector3(0.0, 2.34, 0.0)
	weapon_label.font_size = 30
	weapon_label.outline_size = 7
	weapon_label.modulate = Color(0.78, 0.90, 1.0, 1.0)
	weapon_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	weapon_label.visible = false
	add_child(weapon_label)

	box_light = OmniLight3D.new()
	box_light.name = "BoxLight"
	box_light.position = Vector3(0.0, 1.55, 0.0)
	box_light.light_color = Color(0.28, 0.62, 1.0, 1.0)
	box_light.light_energy = 1.1
	box_light.omni_range = 4.8
	add_child(box_light)
