class_name ZombieTownTownGameplaySpawner
extends ZombieTownTownInteractableSpawner

func _spawn_interactables() -> void:
	super._spawn_interactables()
	for marker_node: Node in get_tree().get_nodes_in_group(&"equipment_buy"):
		if marker_node is Marker3D and _belongs_to_town(marker_node):
			_spawn_equipment(marker_node as Marker3D)

func _spawn_active_mystery_box() -> void:
	var chosen_marker: Marker3D = null
	var best_distance: float = INF
	for marker_node: Node in get_tree().get_nodes_in_group(&"mystery_box_spot"):
		if not marker_node is Marker3D or not _belongs_to_town(marker_node):
			continue
		var marker := marker_node as Marker3D
		var marker_position: Vector3 = marker.global_position
		var planar_distance: float = Vector2(marker_position.x, marker_position.z).length_squared()
		if planar_distance < best_distance:
			best_distance = planar_distance
			chosen_marker = marker
	if chosen_marker == null:
		return
	var mystery_box := ZombieTownGameplayMysteryBox.new()
	mystery_box.name = "MysteryBox"
	get_parent().add_child(mystery_box)
	mystery_box.global_position = chosen_marker.global_position
	mystery_box.rotation.y = PI

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
