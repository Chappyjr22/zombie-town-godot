class_name ZombieTownPlayerEquipment
extends Node

signal equipment_changed(text: String)

const MAX_FRAGS := 4
const MAX_CLAYMORES := 2

var player: ZombieTownInventoryPlayer
var camera: Camera3D
var frag_count := MAX_FRAGS
var claymore_count := 0

func _ready() -> void:
	player = get_parent() as ZombieTownInventoryPlayer
	if player == null:
		set_process(false)
		return
	camera = player.get_node("Head/Camera3D") as Camera3D
	_ensure_input_map()
	_emit_equipment_changed()

func _process(_delta: float) -> void:
	if player == null or not player.alive or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if Input.is_action_just_pressed(&"throw_grenade"):
		_throw_frag()
	if Input.is_action_just_pressed(&"place_claymore"):
		_place_claymore()

func can_buy(item_id: StringName) -> bool:
	match item_id:
		&"grenade":
			return frag_count < MAX_FRAGS
		&"claymore":
			return claymore_count < MAX_CLAYMORES
		_:
			return false

func purchase_refill(item_id: StringName) -> bool:
	if not can_buy(item_id):
		return false
	match item_id:
		&"grenade":
			frag_count = MAX_FRAGS
		&"claymore":
			claymore_count = MAX_CLAYMORES
		_:
			return false
	_emit_equipment_changed()
	return true

func refill_from_max_ammo() -> void:
	frag_count = MAX_FRAGS
	if claymore_count > 0:
		claymore_count = MAX_CLAYMORES
	_emit_equipment_changed()

func equipment_summary() -> String:
	return "G FRAG x%d   Q CLAYMORE x%d" % [frag_count, claymore_count]

func _throw_frag() -> void:
	if frag_count <= 0 or camera == null:
		return
	frag_count -= 1
	var direction := -camera.global_transform.basis.z.normalized()
	var origin := camera.global_position + direction * 0.58 - camera.global_transform.basis.y * 0.12
	var launch_velocity := direction * 12.8 + Vector3.UP * 2.0 + player.velocity * 0.22
	var grenade := ZombieTownFragGrenade.new()
	get_tree().current_scene.add_child(grenade)
	grenade.configure(player, origin, launch_velocity)
	_emit_equipment_changed()

func _place_claymore() -> void:
	if claymore_count <= 0 or camera == null:
		return
	var forward := -player.global_transform.basis.z.normalized()
	var probe_origin := player.global_position + forward * 1.15 + Vector3(0.0, 1.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(probe_origin, probe_origin + Vector3.DOWN * 2.4)
	query.exclude = [player.get_rid()]
	var result: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var position_variant: Variant = result.get("position")
	if not position_variant is Vector3:
		return
	var placement: Vector3 = position_variant
	claymore_count -= 1
	var claymore := ZombieTownClaymore.new()
	get_tree().current_scene.add_child(claymore)
	claymore.configure(player, placement + Vector3(0.0, 0.02, 0.0), player.rotation.y)
	_emit_equipment_changed()

func _emit_equipment_changed() -> void:
	equipment_changed.emit(equipment_summary())

func _ensure_input_map() -> void:
	if not InputMap.has_action(&"throw_grenade"):
		InputMap.add_action(&"throw_grenade", 0.18)
		var grenade_key := InputEventKey.new()
		grenade_key.physical_keycode = KEY_G
		InputMap.action_add_event(&"throw_grenade", grenade_key)
		var grenade_joy := InputEventJoypadButton.new()
		grenade_joy.button_index = JOY_BUTTON_LEFT_SHOULDER
		InputMap.action_add_event(&"throw_grenade", grenade_joy)
	if not InputMap.has_action(&"place_claymore"):
		InputMap.add_action(&"place_claymore", 0.18)
		var claymore_key := InputEventKey.new()
		claymore_key.physical_keycode = KEY_Q
		InputMap.action_add_event(&"place_claymore", claymore_key)
		var claymore_joy := InputEventJoypadButton.new()
		claymore_joy.button_index = JOY_BUTTON_RIGHT_SHOULDER
		InputMap.action_add_event(&"place_claymore", claymore_joy)
