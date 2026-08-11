class_name ZombieTownMapGate
extends ZombieTownInteractable

var progression: Node
var gate_id: StringName = &"gate"
var requires_power := false
var opened := false
var gate_size := Vector3(3.0, 3.0, 0.4)

var blocker: StaticBody3D
var blocker_collision: CollisionShape3D
var interaction_collision: CollisionShape3D
var gate_mesh: MeshInstance3D
var status_label: Label3D

func configure_gate(
	progression_node: Node,
	id: StringName,
	label: String,
	price: int,
	world_position: Vector3,
	size: Vector3,
	yaw: float,
	needs_power: bool
) -> void:
	progression = progression_node
	gate_id = id
	requires_power = needs_power
	gate_size = size
	interaction_kind = &"map_gate"
	item_id = id
	display_name = label
	cost = price
	position = world_position
	rotation.y = yaw
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	_build_gate()

func prompt_for(_player: ZombieTownPlayer) -> String:
	if opened:
		return ""
	if requires_power and not _power_available():
		return "%s  [POWER REQUIRED]" % display_name
	return "[E] %s  %d PTS" % [display_name, cost]

func affordable_for(player: ZombieTownPlayer) -> bool:
	if opened or player == null:
		return true
	if requires_power and not _power_available():
		return false
	return player.points >= cost

func activate_for(player: ZombieTownPlayer) -> void:
	if opened or player == null or not player.alive:
		return
	if requires_power and not _power_available():
		return
	if player.points < cost:
		return
	player.points -= cost
	player.stats_changed.emit(player.points, player.kills, player.headshots)
	open_gate()

func open_gate() -> void:
	if opened:
		return
	opened = true
	collision_layer = 0
	monitorable = false
	if interaction_collision != null:
		interaction_collision.set_deferred("disabled", true)
	if blocker_collision != null:
		blocker_collision.set_deferred("disabled", true)
	if status_label != null:
		status_label.visible = false
	if blocker != null:
		var target_position: Vector3 = blocker.position + Vector3(0.0, gate_size.y + 0.55, 0.0)
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(blocker, "position", target_position, 0.48)
	if progression != null and progression.has_method("request_navigation_rebake"):
		progression.call("request_navigation_rebake")

func _power_available() -> bool:
	if progression == null or not progression.has_method("is_power_on"):
		return false
	return bool(progression.call("is_power_on"))

func _build_gate() -> void:
	blocker = StaticBody3D.new()
	blocker.name = "GateBlocker"
	blocker.position = Vector3(0.0, gate_size.y * 0.5, 0.0)
	blocker.collision_layer = 1
	blocker.collision_mask = 3
	add_child(blocker)

	var blocker_shape := BoxShape3D.new()
	blocker_shape.size = gate_size
	blocker_collision = CollisionShape3D.new()
	blocker_collision.shape = blocker_shape
	blocker.add_child(blocker_collision)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.115, 0.105, 1.0) if not requires_power else Color(0.15, 0.075, 0.055, 1.0)
	material.roughness = 0.78
	material.metallic = 0.42

	var mesh := BoxMesh.new()
	mesh.size = gate_size
	mesh.material = material
	gate_mesh = MeshInstance3D.new()
	gate_mesh.name = "GateMesh"
	gate_mesh.mesh = mesh
	gate_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	blocker.add_child(gate_mesh)

	# The interaction volume extends farther than the physical blocker so the Area
	# wins the interaction ray before the StaticBody surface does.
	var interaction_shape := BoxShape3D.new()
	interaction_shape.size = Vector3(gate_size.x + 0.25, gate_size.y + 0.30, 1.35)
	interaction_collision = CollisionShape3D.new()
	interaction_collision.position = Vector3(0.0, gate_size.y * 0.5, 0.0)
	interaction_collision.shape = interaction_shape
	add_child(interaction_collision)

	status_label = Label3D.new()
	status_label.name = "GateLabel"
	status_label.position = Vector3(0.0, gate_size.y + 0.32, 0.0)
	status_label.text = "POWER" if requires_power else "%d" % cost
	status_label.font_size = 24
	status_label.outline_size = 6
	status_label.modulate = Color(0.85, 0.25, 0.16, 1.0) if requires_power else Color(0.92, 0.72, 0.26, 1.0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(status_label)
