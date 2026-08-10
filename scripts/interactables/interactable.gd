class_name ZombieTownInteractable
extends Area3D

@export var interaction_kind: StringName = &"generic"
@export var item_id: StringName = &""
@export var display_name := "Interact"
@export var cost := 0
@export var interaction_range := 3.0

func configure(kind: StringName, id: StringName, label: String, price: int) -> void:
	interaction_kind = kind
	item_id = id
	display_name = label
	cost = price
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true

func get_prompt(player: ZombieTownPlayer) -> String:
	if player == null:
		return ""
	if interaction_kind == &"perk" and player.has_perk(item_id):
		return "%s  [OWNED]" % display_name
	if interaction_kind == &"ammo" and player.weapon != null and player.weapon.id != item_id:
		return "%s AMMO  [NOT EQUIPPED]" % display_name
	if cost <= 0:
		return "[E] %s" % display_name
	return "[E] %s  %d PTS" % [display_name, cost]

func is_affordable(player: ZombieTownPlayer) -> bool:
	if player == null:
		return false
	if interaction_kind == &"perk" and player.has_perk(item_id):
		return true
	return player.points >= cost

func interact(player: ZombieTownPlayer) -> bool:
	if player == null:
		return false
	match interaction_kind:
		&"perk":
			return player.purchase_perk(item_id, cost)
		&"ammo":
			return player.purchase_ammo(item_id, cost)
		&"pack_a_punch":
			return player.purchase_pack_a_punch(cost)
		_:
			return false
