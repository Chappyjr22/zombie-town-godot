class_name ZombieTownTownGameplaySpawner
extends ZombieTownTownInteractableSpawner

func _spawn_interactables() -> void:
	super._spawn_interactables()
	for marker_node: Node in get_tree().get_nodes_in_group(&"equipment_buy"):
		if marker_node is Marker3D and _belongs_to_town(marker_node):
			_spawn_equipment(marker_node as Marker3D)

func _spawn_equipment(marker: Marker3D) -> void:
	var item_id: StringName = _marker_item_id(marker)
	var label: String = "Equipment"
	var price := 0
	var color := Color(0.72, 0.76, 0.65, 1.0)
	match item_id:
		&"grenade":
			label = "Frag Grenades"
			price = 250
			color = Color(0.40, 0.62, 0.28, 1.0)
		&"claymore":
			label = "Claymores"
			price = 1000
			color = Color(0.72, 0.42, 0.18, 1.0)
		_:
			return
	var interactable := ZombieTownInteractable.new()
	interactable.name = "%sEquipmentBuy" % label.replace(" ", "")
	get_parent().add_child(interactable)
	interactable.global_position = marker.global_position + Vector3(0.0, 1.45, 0.0)
	interactable.rotation.y = _marker_yaw(marker)
	interactable.configure(&"equipment", item_id, label, price)
	_add_wall_plate_visual(interactable, color, label.to_upper(), 1.7)
