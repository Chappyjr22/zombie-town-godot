class_name ZombieTownPowerSwitch
extends ZombieTownInteractable

var progression: ZombieTownTownProgression
var screen_material: StandardMaterial3D
var screen_mesh: MeshInstance3D
var lever: MeshInstance3D
var interaction_collision: CollisionShape3D

func configure_switch(progression_node: ZombieTownTownProgression, world_position: Vector3, yaw: float) -> void:
	progression = progression_node
	interaction_kind = &"power_switch"
	item_id = &"town_power"
	display_name = "Power"
	cost = 0
	position = world_position
	rotation.y = yaw
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	_build_switch()

func prompt_for(_player: ZombieTownPlayer) -> String:
	if progression != null and progression.is_power_on():
		return "POWER  [ON]"
	return "[E] Turn On Power"

func affordable_for(_player: ZombieTownPlayer) -> bool:
	return true

func activate_for(_player: ZombieTownPlayer) -> void:
	if progression == null or not progression.activate_power():
		return
	_update_powered_visual()

func _build_switch() -> void:
	var panel_material := StandardMaterial3D.new()
	panel_material.albedo_color = Color(0.10, 0.11, 0.12, 1.0)
	panel_material.roughness = 0.62
	panel_material.metallic = 0.72

	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(0.85, 1.35, 0.22)
	panel_mesh.material = panel_material
	var panel := MeshInstance3D.new()
	panel.name = "Panel"
	panel.position = Vector3(0.0, 1.40, 0.0)
	panel.mesh = panel_mesh
	add_child(panel)

	screen_material = StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.albedo_color = Color(0.34, 0.05, 0.035, 1.0)
	screen_material.emission_enabled = true
	screen_material.emission = Color(0.70, 0.06, 0.04, 1.0)
	screen_material.emission_energy_multiplier = 1.8
	var indicator_mesh := BoxMesh.new()
	indicator_mesh.size = Vector3(0.46, 0.20, 0.06)
	indicator_mesh.material = screen_material
	screen_mesh = MeshInstance3D.new()
	screen_mesh.name = "PowerIndicator"
	screen_mesh.position = Vector3(0.0, 1.72, -0.14)
	screen_mesh.mesh = indicator_mesh
	add_child(screen_mesh)

	var lever_material := StandardMaterial3D.new()
	lever_material.albedo_color = Color(0.31, 0.33, 0.34, 1.0)
	lever_material.roughness = 0.46
	lever_material.metallic = 0.82
	var lever_mesh := BoxMesh.new()
	lever_mesh.size = Vector3(0.12, 0.48, 0.12)
	lever_mesh.material = lever_material
	lever = MeshInstance3D.new()
	lever.name = "Lever"
	lever.position = Vector3(0.0, 1.24, -0.18)
	lever.rotation.x = deg_to_rad(-24.0)
	lever.mesh = lever_mesh
	add_child(lever)

	var interaction_shape := BoxShape3D.new()
	interaction_shape.size = Vector3(1.15, 1.75, 0.80)
	interaction_collision = CollisionShape3D.new()
	interaction_collision.position = Vector3(0.0, 1.40, -0.14)
	interaction_collision.shape = interaction_shape
	add_child(interaction_collision)

	var label := Label3D.new()
	label.name = "PowerLabel"
	label.position = Vector3(0.0, 2.25, 0.0)
	label.text = "POWER"
	label.font_size = 24
	label.outline_size = 6
	label.modulate = Color(0.88, 0.28, 0.18, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _update_powered_visual() -> void:
	if screen_material != null:
		screen_material.albedo_color = Color(0.05, 0.32, 0.13, 1.0)
		screen_material.emission = Color(0.14, 0.95, 0.36, 1.0)
		screen_material.emission_energy_multiplier = 2.6
	if lever != null:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(lever, "rotation:x", deg_to_rad(28.0), 0.28)
