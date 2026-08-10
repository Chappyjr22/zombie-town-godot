class_name ZombieTownInteractable
extends Area3D

@export var interaction_kind: StringName = &"generic"
@export var item_id: StringName = &""
@export var display_name := "Interact"
@export var cost := 0
@export var ammo_cost := 0
@export var interaction_range := 3.2

func configure(kind: StringName, id: StringName, label: String, price: int, ammo_price: int = 0) -> void:
	interaction_kind = kind
	item_id = id
	display_name = label
	cost = price
	ammo_cost = ammo_price
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
