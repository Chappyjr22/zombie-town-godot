class_name ZombieTownTownInteractableSpawner
extends Node

func _ready() -> void:
	call_deferred("_spawn_interactables")

func _spawn_interactables() -> void:
	for marker_node: Node in get_tree().get_nodes_in_group(&"perk_spot"):
		if marker_node is Marker3D and _belongs_to_town(marker_node):
			_spawn_perk(marker_node as Marker3D)
	for marker_node: Node in get_tree().get_nodes_in_group(&"wall_buy"):
		if marker_node is Marker3D and _belongs_to_town(marker_node):
			_spawn_wall_weapon(marker_node as Marker3D)
	for marker_node: Node in get_tree().get_nodes_in_group(&"ammo_buy"):
		if marker_node is Marker3D and _belongs_to_town(marker_node):
			_spawn_ammo(marker_node as Marker3D)
	for marker_node: Node in get_tree().get_nodes_in_group(&"pack_a_punch_spot"):
		if marker_node is Marker3D and _belongs_to_town(marker_node):
			_spawn_pack_a_punch(marker_node as Marker3D)
	_spawn_active_mystery_box()

func _belongs_to_town(node: Node) -> bool:
	var town_root: Node = get_parent()
	return town_root == node or town_root.is_ancestor_of(node)

func _spawn_active_mystery_box() -> void:
	var chosen_marker: Marker3D = null
	var best_distance: float = INF
	for marker_node: Node in get_tree().get_nodes_in_group(&"mystery_box_spot"):
		if not marker_node is Marker3D or not _belongs_to_town(marker_node):
			continue
		var marker := marker_node as Marker3D
		var marker_position: Vector3 = marker.global_position
		var planar_distance := Vector2(marker_position.x, marker_position.z).length_squared()
		if planar_distance < best_distance:
			best_distance = planar_distance
			chosen_marker = marker
	if chosen_marker == null:
		return
	var mystery_box := ZombieTownMysteryBox.new()
	mystery_box.name = "MysteryBox"
	get_parent().add_child(mystery_box)
	mystery_box.global_position = chosen_marker.global_position
	mystery_box.rotation.y = PI

func _spawn_perk(marker: Marker3D) -> void:
	var item_id: StringName = _marker_item_id(marker)
	var data: Dictionary = _perk_data(item_id)
	if data.is_empty():
		return
	var name_variant: Variant = data.get("name", "Perk")
	var cost_variant: Variant = data.get("cost", 0)
	var color_variant: Variant = data.get("color", Color.WHITE)
	var letter_variant: Variant = data.get("letter", "?")
	if not color_variant is Color:
		return
	var machine_color: Color = color_variant
	var display_name := str(name_variant)
	var price := int(cost_variant)
	var interactable := ZombieTownInteractable.new()
	interactable.name = "%sInteractable" % display_name.replace(" ", "")
	get_parent().add_child(interactable)
	interactable.global_position = marker.global_position
	interactable.rotation.y = _marker_yaw(marker)
	interactable.configure(&"perk", item_id, "Buy %s" % display_name, price)
	_add_machine_visual(interactable, machine_color, str(letter_variant))

func _spawn_wall_weapon(marker: Marker3D) -> void:
	var item_id: StringName = _marker_item_id(marker)
	var weapon_data := ZombieTownWeaponCatalog.load_weapon(item_id)
	if weapon_data == null:
		return
	var interactable := ZombieTownInteractable.new()
	interactable.name = "%sWallBuy" % weapon_data.display_name.replace(" ", "")
	get_parent().add_child(interactable)
	interactable.global_position = marker.global_position
	interactable.rotation.y = _marker_yaw(marker)
	interactable.configure(&"weapon", item_id, weapon_data.display_name, weapon_data.wall_cost, weapon_data.ammo_cost)
	_add_wall_plate_visual(interactable, Color(0.76, 0.82, 0.92, 1.0), weapon_data.display_name.to_upper(), 1.8)

func _spawn_ammo(marker: Marker3D) -> void:
	var item_id: StringName = _marker_item_id(marker)
	var price: int = 250 if item_id == &"m1911" else 400
	var label: String = "M1911 Ammo" if item_id == &"m1911" else "M4A1 Ammo"
	var interactable := ZombieTownInteractable.new()
	interactable.name = "%sInteractable" % label.replace(" ", "")
	get_parent().add_child(interactable)
	interactable.global_position = marker.global_position
	interactable.rotation.y = _marker_yaw(marker)
	interactable.configure(&"ammo", item_id, "Buy %s" % label, price)
	_add_wall_plate_visual(interactable, Color(0.72, 0.78, 0.88, 1.0), "AMMO", 1.4)

func _spawn_pack_a_punch(marker: Marker3D) -> void:
	var interactable := ZombieTownInteractable.new()
	interactable.name = "PackAPunchInteractable"
	get_parent().add_child(interactable)
	interactable.global_position = marker.global_position
	interactable.rotation.y = _marker_yaw(marker)
	interactable.configure(&"pack_a_punch", &"pap", "Pack-a-Punch", 5000)
	_add_machine_visual(interactable, Color(0.55, 0.22, 0.75, 1.0), "PAP")

func _add_machine_visual(interactable: ZombieTownInteractable, color: Color, label_text: String) -> void:
	var collision_shape := BoxShape3D.new()
	collision_shape.size = Vector3(1.05, 2.15, 0.9)
	var collision := CollisionShape3D.new()
	collision.position = Vector3(0.0, 1.08, 0.0)
	collision.shape = collision_shape
	interactable.add_child(collision)

	var material := _glow_material(color)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.95, 2.0, 0.78)
	mesh.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position = Vector3(0.0, 1.0, 0.0)
	mesh_instance.mesh = mesh
	interactable.add_child(mesh_instance)

	var label := Label3D.new()
	label.position = Vector3(0.0, 1.3, -0.405)
	label.rotation.y = PI
	label.text = label_text
	label.font_size = 40
	label.modulate = Color(0.95, 0.94, 0.88, 1.0)
	label.outline_size = 8
	interactable.add_child(label)

	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.3, -0.45)
	light.light_color = color
	light.light_energy = 1.1
	light.omni_range = 3.0
	interactable.add_child(light)

func _add_wall_plate_visual(interactable: ZombieTownInteractable, color: Color, label_text: String, width: float) -> void:
	var collision_shape := BoxShape3D.new()
	collision_shape.size = Vector3(width + 0.1, 0.7, 0.35)
	var collision := CollisionShape3D.new()
	collision.shape = collision_shape
	interactable.add_child(collision)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.62, 0.18)
	mesh.material = _glow_material(color)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	interactable.add_child(mesh_instance)

	var label := Label3D.new()
	label.position = Vector3(0.0, 0.0, -0.105)
	label.rotation.y = PI
	label.text = label_text
	label.font_size = 22
	label.outline_size = 6
	interactable.add_child(label)

func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.45)
	material.roughness = 0.6
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.35
	return material

func _marker_item_id(marker: Marker3D) -> StringName:
	var value: Variant = marker.get_meta(&"item_id", "")
	return StringName(str(value))

func _marker_yaw(marker: Marker3D) -> float:
	var value: Variant = marker.get_meta(&"yaw", 0.0)
	return float(value)

func _perk_data(item_id: StringName) -> Dictionary:
	match item_id:
		&"jugg":
			return {"name": "Juggernog", "cost": 2500, "color": Color(0.64, 0.12, 0.09, 1.0), "letter": "J"}
		&"speed":
			return {"name": "Speed Cola", "cost": 3000, "color": Color(0.16, 0.62, 0.20, 1.0), "letter": "S"}
		&"revive":
			return {"name": "Quick Revive", "cost": 1500, "color": Color(0.20, 0.55, 0.78, 1.0), "letter": "Q"}
		&"dtap":
			return {"name": "Double Tap", "cost": 2000, "color": Color(0.82, 0.56, 0.14, 1.0), "letter": "D"}
		&"stamin":
			return {"name": "Stamin-Up", "cost": 2000, "color": Color(0.82, 0.82, 0.12, 1.0), "letter": "U"}
		&"mule":
			return {"name": "Mule Kick", "cost": 4000, "color": Color(0.82, 0.35, 0.10, 1.0), "letter": "M"}
		_:
			return {}
