class_name ZombieTownPlayerInteraction
extends Node

signal prompt_changed(text: String, affordable: bool)

const PACK_COSTS := [5000, 15000, 150000]

var player: ZombieTownPlayer
var camera: Camera3D
var current_interactable: ZombieTownInteractable
var perks: Dictionary = {}
var pack_level := 0

func _ready() -> void:
	player = get_parent() as ZombieTownPlayer
	if player == null:
		set_physics_process(false)
		return
	if player.weapon != null:
		player.weapon = player.weapon.duplicate(true) as WeaponData
	camera = player.get_node("Head/Camera3D") as Camera3D
	_ensure_input_map()

func _physics_process(_delta: float) -> void:
	if player == null or not player.alive or camera == null:
		_set_current(null)
		return
	_scan_interactable()
	if Input.is_action_just_pressed(&"interact") and current_interactable != null:
		_activate(current_interactable)
		_refresh_prompt()

func has_perk(perk_id: StringName) -> bool:
	return bool(perks.get(perk_id, false))

func _scan_interactable() -> void:
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 3.2)
	query.exclude = [player.get_rid()]
	query.collision_mask = 5
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		_set_current(null)
		return
	var collider_variant: Variant = result.get("collider")
	if collider_variant is ZombieTownInteractable:
		_set_current(collider_variant as ZombieTownInteractable)
	else:
		_set_current(null)

func _set_current(interactable: ZombieTownInteractable) -> void:
	if current_interactable == interactable:
		_refresh_prompt()
		return
	current_interactable = interactable
	_refresh_prompt()

func _refresh_prompt() -> void:
	if current_interactable == null:
		prompt_changed.emit("", true)
		return
	var text := _prompt_for(current_interactable)
	var affordable := _is_affordable(current_interactable)
	prompt_changed.emit(text, affordable)

func _prompt_for(interactable: ZombieTownInteractable) -> String:
	if interactable.interaction_kind == &"perk" and has_perk(interactable.item_id):
		return "%s  [OWNED]" % interactable.display_name
	if interactable.interaction_kind == &"ammo":
		if player.weapon != null and player.weapon.id != interactable.item_id:
			return "%s  [NOT EQUIPPED]" % interactable.display_name
		if player.weapon != null and player.reserve_ammo >= player.weapon.reserve_ammo:
			return "%s  [FULL]" % interactable.display_name
	if interactable.interaction_kind == &"pack_a_punch":
		if pack_level >= PACK_COSTS.size():
			return "Pack-a-Punch  [MAX TIER]"
		return "[E] Pack-a-Punch  %d PTS" % int(PACK_COSTS[pack_level])
	return "[E] %s  %d PTS" % [interactable.display_name, interactable.cost]

func _is_affordable(interactable: ZombieTownInteractable) -> bool:
	if interactable.interaction_kind == &"perk" and has_perk(interactable.item_id):
		return true
	if interactable.interaction_kind == &"pack_a_punch":
		if pack_level >= PACK_COSTS.size():
			return true
		return player.points >= int(PACK_COSTS[pack_level])
	return player.points >= interactable.cost

func _activate(interactable: ZombieTownInteractable) -> void:
	match interactable.interaction_kind:
		&"perk":
			_purchase_perk(interactable.item_id, interactable.cost)
		&"ammo":
			_purchase_ammo(interactable.item_id, interactable.cost)
		&"pack_a_punch":
			_purchase_pack_a_punch()

func _purchase_perk(perk_id: StringName, cost: int) -> void:
	if has_perk(perk_id) or not _spend_points(cost):
		return
	perks[perk_id] = true
	match perk_id:
		&"jugg":
			player.max_health = 250.0
			player.health = player.max_health
			player.health_changed.emit(player.health, player.max_health)
		&"speed":
			if player.weapon != null:
				player.weapon.reload_time *= 0.5
		&"dtap":
			if player.weapon != null:
				player.weapon.damage *= 1.35
				player.weapon.fire_interval *= 0.8
		&"stamin":
			player.walk_speed *= 1.10
			player.sprint_speed *= 1.25
		&"revive", &"mule":
			pass

func _purchase_ammo(item_id: StringName, cost: int) -> void:
	if player.weapon == null or player.weapon.id != item_id:
		return
	if player.reserve_ammo >= player.weapon.reserve_ammo:
		return
	if not _spend_points(cost):
		return
	player.reserve_ammo = player.weapon.reserve_ammo
	player.ammo_changed.emit(player.ammo, player.reserve_ammo, player.reloading)

func _purchase_pack_a_punch() -> void:
	if player.weapon == null or pack_level >= PACK_COSTS.size():
		return
	var cost: int = int(PACK_COSTS[pack_level])
	if not _spend_points(cost):
		return
	pack_level += 1
	match pack_level:
		1:
			player.weapon.damage *= 2.0
		2:
			player.weapon.damage *= 1.7
			player.weapon.magazine_size = roundi(float(player.weapon.magazine_size) * 1.5)
			player.weapon.reserve_ammo = roundi(float(player.weapon.reserve_ammo) * 1.5)
		3:
			player.weapon.damage *= 3.0
			player.weapon.magazine_size = roundi(float(player.weapon.magazine_size) * (4.0 / 3.0))
			player.weapon.reserve_ammo = roundi(float(player.weapon.reserve_ammo) * (4.0 / 3.0))
	player.ammo = player.weapon.magazine_size
	player.reserve_ammo = player.weapon.reserve_ammo
	player.ammo_changed.emit(player.ammo, player.reserve_ammo, player.reloading)

func _spend_points(cost: int) -> bool:
	if cost < 0 or player.points < cost:
		return false
	player.points -= cost
	player.stats_changed.emit(player.points, player.kills, player.headshots)
	return true

func _ensure_input_map() -> void:
	if InputMap.has_action(&"interact"):
		return
	InputMap.add_action(&"interact", 0.18)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = KEY_E
	InputMap.action_add_event(&"interact", key_event)
	var joy_event := InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_Y
	InputMap.action_add_event(&"interact", joy_event)
