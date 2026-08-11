class_name ZombieTownGameplayInteraction
extends ZombieTownProgressionInteraction

func _prompt_for(interactable: ZombieTownInteractable) -> String:
	if interactable.interaction_kind == &"equipment":
		var equipment := _equipment_component()
		if equipment == null:
			return "%s  [UNAVAILABLE]" % interactable.display_name
		if not equipment.can_buy(interactable.item_id):
			return "%s  [FULL]" % interactable.display_name
		return "[E] Buy %s  %d PTS" % [interactable.display_name, interactable.cost]
	return super._prompt_for(interactable)

func _is_affordable(interactable: ZombieTownInteractable) -> bool:
	if interactable.interaction_kind == &"equipment":
		var equipment := _equipment_component()
		if equipment == null or not equipment.can_buy(interactable.item_id):
			return true
		return player.points >= interactable.cost
	return super._is_affordable(interactable)

func _activate(interactable: ZombieTownInteractable) -> void:
	if interactable.interaction_kind == &"equipment":
		_purchase_equipment(interactable)
		return
	super._activate(interactable)

func _purchase_equipment(interactable: ZombieTownInteractable) -> void:
	var equipment := _equipment_component()
	if equipment == null or not equipment.can_buy(interactable.item_id):
		return
	if not _spend_points(interactable.cost):
		return
	if not equipment.purchase_refill(interactable.item_id):
		player.points += interactable.cost
		player.stats_changed.emit(player.points, player.kills, player.headshots)

func _equipment_component() -> ZombieTownPlayerEquipment:
	return player.get_node_or_null("Equipment") as ZombieTownPlayerEquipment
