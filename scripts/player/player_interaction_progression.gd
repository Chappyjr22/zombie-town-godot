class_name ZombieTownProgressionInteraction
extends ZombieTownPlayerInteraction

func _prompt_for(interactable: ZombieTownInteractable) -> String:
	if interactable is ZombieTownMapGate:
		var gate := interactable as ZombieTownMapGate
		return gate.prompt_for(player)
	if interactable is ZombieTownPowerSwitch:
		var power_switch := interactable as ZombieTownPowerSwitch
		return power_switch.prompt_for(player)
	if interactable.interaction_kind == &"pack_a_punch" and not _map_power_on():
		return "Pack-a-Punch  [POWER REQUIRED]"
	return super._prompt_for(interactable)

func _is_affordable(interactable: ZombieTownInteractable) -> bool:
	if interactable is ZombieTownMapGate:
		var gate := interactable as ZombieTownMapGate
		return gate.affordable_for(player)
	if interactable is ZombieTownPowerSwitch:
		var power_switch := interactable as ZombieTownPowerSwitch
		return power_switch.affordable_for(player)
	if interactable.interaction_kind == &"pack_a_punch" and not _map_power_on():
		return false
	return super._is_affordable(interactable)

func _activate(interactable: ZombieTownInteractable) -> void:
	if interactable is ZombieTownMapGate:
		var gate := interactable as ZombieTownMapGate
		gate.activate_for(player)
		return
	if interactable is ZombieTownPowerSwitch:
		var power_switch := interactable as ZombieTownPowerSwitch
		power_switch.activate_for(player)
		return
	if interactable.interaction_kind == &"pack_a_punch" and not _map_power_on():
		return
	super._activate(interactable)

func _purchase_pack_a_punch() -> void:
	if not _map_power_on():
		return
	super._purchase_pack_a_punch()

func _map_power_on() -> bool:
	var progression_node := get_tree().get_first_node_in_group(&"map_progression")
	if progression_node == null:
		return true
	if progression_node is ZombieTownTownProgression:
		var progression := progression_node as ZombieTownTownProgression
		return progression.is_power_on()
	return true
