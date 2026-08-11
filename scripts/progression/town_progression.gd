class_name ZombieTownTownProgression
extends Node3D

signal power_changed(enabled: bool)

const NAV_SOURCE_GROUP: StringName = &"town_navigation_source"

var town: ZombieTownTown
var power_on := false
var gates: Dictionary = {}
var power_switch: ZombieTownPowerSwitch
var built := false

func _ready() -> void:
	call_deferred("_initialize_from_parent")

func _initialize_from_parent() -> void:
	if built:
		return
	var parent_node := get_parent()
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

	_add_gate(&"bar_front", "Open Bar", 750, Vector3(-20.0, 0.0, -6.0), Vector3(3.15, 3.0, 0.42), 0.0, false)
	_add_gate(&"bank_front", "Open Bank", 1000, Vector3(24.0, 0.0, -6.0), Vector3(3.15, 3.0, 0.42), 0.0, false)
	_add_gate(&"diner_front", "Open Diner", 750, Vector3(-17.0, 0.0, 14.0), Vector3(3.15, 3.0, 0.42), PI * 0.5, false)
	_add_gate(&"store_front", "Open General Store", 750, Vector3(17.0, 0.0, 14.0), Vector3(3.15, 3.0, 0.42), PI * 0.5, false)
	_add_gate(&"church_front", "Open Church", 750, Vector3(0.0, 0.0, 20.0), Vector3(3.35, 3.0, 0.42), 0.0, false)

	# These secondary entrances become shortcuts after the player restores power.
	_add_gate(&"bar_shortcut", "Open Powered Bar Shortcut", 1000, Vector3(-14.0, 0.0, -16.0), Vector3(3.15, 3.0, 0.42), PI * 0.5, true)
	_add_gate(&"bank_shortcut", "Open Powered Bank Shortcut", 1000, Vector3(14.0, 0.0, -16.0), Vector3(3.15, 3.0, 0.42), PI * 0.5, true)

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
	if town == null or not is_instance_valid(town):
		return
	if town.navigation_region == null or town.navigation_mesh == null:
		return
	town.navigation_region.call_deferred("bake_navigation_mesh", true)

func _add_gate(
	gate_id: StringName,
	label: String,
	cost: int,
	position: Vector3,
	size: Vector3,
	yaw: float,
	requires_power: bool
) -> void:
	var gate := ZombieTownMapGate.new()
	add_child(gate)
	gate.configure_gate(self, gate_id, label, cost, position, size, yaw, requires_power)
	gates[gate_id] = gate
