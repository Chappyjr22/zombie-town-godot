class_name ZombieTownPowerupDrop
extends Area3D

const LIFETIME := 18.0

var powerup_id: StringName = &"max_ammo"
var manager: Node
var lifetime_remaining := LIFETIME
var base_y := 0.0
var elapsed := 0.0
var label: Label3D
var glow: OmniLight3D

func configure(powerup_manager: Node, id: StringName, world_position: Vector3) -> void:
	manager = powerup_manager
	powerup_id = id
	global_position = world_position + Vector3(0.0, 0.65, 0.0)
	base_y = global_position.y
	collision_layer = 8
	collision_mask = 1
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	_build_visual()

func _process(delta: float) -> void:
	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0:
		queue_free()
		return
	elapsed += delta
	rotation.y += delta * 1.7
	global_position.y = base_y + sin(elapsed * 3.2) * 0.16
	if glow != null and lifetime_remaining < 4.0:
		glow.light_energy = 2.5 if fmod(lifetime_remaining, 0.45) < 0.22 else 0.45

func _on_body_entered(body: Node3D) -> void:
	if manager == null or not manager.has_method("activate_powerup"):
		return
	if not body is ZombieTownPlayer:
		return
	manager.call("activate_powerup", powerup_id)
	queue_free()

func _build_visual() -> void:
	var color := _color_for(powerup_id)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color.lightened(0.18)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.8
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.62, 0.62, 0.62)
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	var shape := SphereShape3D.new()
	shape.radius = 0.82
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	label = Label3D.new()
	label.position = Vector3(0.0, 0.72, 0.0)
	label.text = _label_for(powerup_id)
	label.font_size = 26
	label.outline_size = 7
	label.modulate = color.lightened(0.28)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	glow = OmniLight3D.new()
	glow.light_color = color
	glow.light_energy = 1.8
	glow.omni_range = 4.0
	add_child(glow)

func _label_for(id: StringName) -> String:
	match id:
		&"max_ammo":
			return "MAX AMMO"
		&"double_points":
			return "DOUBLE POINTS"
		&"insta_kill":
			return "INSTA-KILL"
		&"nuke":
			return "NUKE"
		_:
			return "POWER-UP"

func _color_for(id: StringName) -> Color:
	match id:
		&"max_ammo":
			return Color(0.18, 0.68, 1.0, 1.0)
		&"double_points":
			return Color(1.0, 0.72, 0.12, 1.0)
		&"insta_kill":
			return Color(0.92, 0.16, 0.10, 1.0)
		&"nuke":
			return Color(0.36, 1.0, 0.22, 1.0)
		_:
			return Color.WHITE
