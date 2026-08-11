class_name ZombieTownTownProgression
extends Node3D

signal power_changed(enabled: bool)

const NAV_SOURCE_GROUP: StringName = &"town_navigation_source"

var town: ZombieTownTown
var power_on := false
var gates: Dictionary = {}
var gate_groups: Dictionary = {}
var gate_to_group: Dictionary = {}
var power_switch: ZombieTownPowerSwitch
var built := false
var navigation_rebake_queued := false

func _ready() -> void:
	call_deferred("_initialize_from_parent")

func _initialize_from_parent() -> void:
	if built:
		return
	var parent_node: Node = get_parent()
	if not parent_node is ZombieTownTown:
		return
	build_for(parent_node as ZombieTownTown)

func build_for(town_node: ZombieTownTown) -> void:
	if built:
		return
	built = true
	town = town_node
	name = "TownProgression"
	add_to_group(&"map_progression")
	add_to_group(NAV_SOURCE_GROUP)

	# Bar and Bank each have two physical entrances. Either doorway can be purchased,
	# but the building is only paid for once and every door in that building opens together.
	_add_gate(&"bar_front", "Open Bar", 750, Vector3(-20.0, 0.0, -6.0), Vector3(3.15, 3.0, 0.42), 0.0, false, &"bar")
	_add_gate(&"bar_side", "Open Bar", 750, Vector3(-14.0, 0.0, -16.0), Vector3(3.15, 3.0, 0.42), PI * 0.5, false, &"bar")

	_add_gate(&"bank_front", "Open Bank", 1000, Vector3(24.0, 0.0, -6.0), Vector3(3.15, 3.0, 0.42), 0.0, false, &"bank")
	_add_gate(&"bank_side", "Open Bank", 1000, Vector3(14.0, 0.0, -16.0), Vector3(3.15, 3.0, 0.42), PI * 0.5, false, &"bank")

	_add_gate(&"diner_front", "Open Diner", 750, Vector3(-17.0, 0.0, 14.0), Vector3(3.15, 3.0, 0.42), PI * 0.5, false)
	_add_gate(&"store_front", "Open General Store", 750, Vector3(17.0, 0.0, 14.0), Vector3(3.15, 3.0, 0.42), PI * 0.5, false)
	_add_gate(&"church_front", "Open Church", 750, Vector3(0.0, 0.0, 20.0), Vector3(3.35, 3.0, 0.42), 0.0, false)

	power_switch = ZombieTownPowerSwitch.new()
	add_child(power_switch)
	power_switch.configure_switch(self, Vector3(30.55, 0.0, -14.0), -PI * 0.5)

func is_power_on() -> bool:
	return power_on

func activate_power() -> bool:
	if power_on:
		return false
	power_on = true
	power_changed.emit(true)
	return true

func request_navigation_rebake() -> void:
	if navigation_rebake_queued:
		return
	navigation_rebake_queued = true
	call_deferred("_perform_navigation_rebake")

func _perform_navigation_rebake() -> void:
	navigation_rebake_queued = false
	if town == null or not is_instance_valid(town):
		return
	if town.navigation_region == null or town.navigation_mesh == null:
		return
	town.navigation_region.bake_navigation_mesh(true)

func _on_gate_opened(gate_id: StringName) -> void:
	var group_variant: Variant = gate_to_group.get(gate_id, &"")
	var group_id: StringName = StringName(str(group_variant))
	if group_id.is_empty():
		return
	_open_gate_group(group_id)

func _open_gate_group(group_id: StringName) -> void:
	var members_variant: Variant = gate_groups.get(group_id)
	if not members_variant is Array:
		return
	var members: Array = members_variant
	for member_variant: Variant in members:
		var member_id: StringName = StringName(str(member_variant))
		var gate_variant: Variant = gates.get(member_id)
		if not gate_variant is ZombieTownMapGate:
			continue
		var gate: ZombieTownMapGate = gate_variant
		if not gate.opened:
			gate.open_gate()

func _register_gate_group(gate_id: StringName, group_id: StringName) -> void:
	if group_id.is_empty():
		return
	gate_to_group[gate_id] = group_id
	var members: Array = []
	var members_variant: Variant = gate_groups.get(group_id)
	if members_variant is Array:
		members = members_variant
	members.append(gate_id)
	gate_groups[group_id] = members

func _add_gate(
	gate_id: StringName,
	label: String,
	cost: int,
	position: Vector3,
	size: Vector3,
	yaw: float,
	requires_power: bool,
	group_id: StringName = &""
) -> void:
	var gate := ZombieTownMapGate.new()
	add_child(gate)
	gate.configure_gate(self, gate_id, label, cost, position, size, yaw, requires_power)
	gate.gate_opened.connect(_on_gate_opened)
	gates[gate_id] = gate
	_register_gate_group(gate_id, group_id)
