class_name ZombieTownPlayerInteraction
extends Node

signal prompt_changed(text: String, affordable: bool)

const PACK_COSTS: Array[int] = [5000, 15000, 150000]

var player: ZombieTownPlayer
var camera: Camera3D
var current_interactable: ZombieTownInteractable
var perks: Dictionary = {}
var speed_applied: Dictionary = {}
var double_tap_applied: Dictionary = {}
var pack_level := 0

func _ready() -> void:
	player = get_parent() as ZombieTownPlayer
	if player == null:
		set_physics_process(false)
		return
	camera = player.get_node("Head/Camera3D") as Camera3D
	player.weapon_changed.connect(_on_weapon_changed)
	_ensure_input_map()

func _physics_process(_delta: float) -> void:
	if player == null or not player.alive or camera == null:
		_set_current(null)
		return
	if player.is_gameplay_input_blocked():
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
	prompt_changed.emit(_prompt_for(current_interactable), _is_affordable(current_interactable))

func _prompt_for(interactable: ZombieTownInteractable) -> String:
	if interactable is ZombieTownMysteryBox:
		var mystery_box := interactable as ZombieTownMysteryBox
		return mystery_box.prompt_for(player)
	if interactable.interaction_kind == &"perk" and has_perk(interactable.item_id):
		return "%s  [OWNED]" % interactable.display_name
	if interactable.interaction_kind == &"weapon":
		if _owns_weapon(interactable.item_id):
			if _weapon_reserve_full(interactable.item_id):
				return "%s AMMO  [FULL]" % interactable.display_name
			return "[E] Buy %s Ammo  %d PTS" % [interactable.display_name, interactable.ammo_cost]
		return "[E] Buy %s  %d PTS" % [interactable.display_name, interactable.cost]
	if interactable.interaction_kind == &"ammo":
		if not _owns_weapon(interactable.item_id):
			return "%s  [NOT OWNED]" % interactable.display_name
		if _weapon_reserve_full(interactable.item_id):
			return "%s  [FULL]" % interactable.display_name
	if interactable.interaction_kind == &"pack_a_punch":
		if pack_level >= PACK_COSTS.size():
			return "Pack-a-Punch  [MAX TIER]"
		return "[E] Pack-a-Punch  %d PTS" % PACK_COSTS[pack_level]
	return "[E] %s  %d PTS" % [interactable.display_name, interactable.cost]

func _is_affordable(interactable: ZombieTownInteractable) -> bool:
	if interactable is ZombieTownMysteryBox:
		var mystery_box := interactable as ZombieTownMysteryBox
		return mystery_box.affordable_for(player)
	if interactable.interaction_kind == &"perk" and has_perk(interactable.item_id):
		return true
	if interactable.interaction_kind == &"weapon" and _owns_weapon(interactable.item_id):
		return _weapon_reserve_full(interactable.item_id) or player.points >= interactable.ammo_cost
	if interactable.interaction_kind == &"pack_a_punch":
		if pack_level >= PACK_COSTS.size():
			return true
		return player.points >= PACK_COSTS[pack_level]
	return player.points >= interactable.cost

func _activate(interactable: ZombieTownInteractable) -> void:
	if interactable is ZombieTownMysteryBox:
		var mystery_box := interactable as ZombieTownMysteryBox
		mystery_box.activate_for(player)
		return
	match interactable.interaction_kind:
		&"perk":
			_purchase_perk(interactable.item_id, interactable.cost)
		&"weapon":
			_purchase_wall_weapon(interactable)
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
			_apply_perk_to_all_weapons(&"speed")
		&"dtap":
			_apply_perk_to_all_weapons(&"dtap")
		&"stamin":
			player.walk_speed *= 1.10
			player.sprint_speed *= 1.25
		&"mule":
			if player is ZombieTownInventoryPlayer:
				var inventory_player := player as ZombieTownInventoryPlayer
				inventory_player.unlock_third_weapon_slot()
		&"revive":
			pass

func _purchase_wall_weapon(interactable: ZombieTownInteractable) -> void:
	if _owns_weapon(interactable.item_id):
		_purchase_ammo(interactable.item_id, interactable.ammo_cost)
		return
	if not _spend_points(interactable.cost):
		return
	var new_weapon := ZombieTownWeaponCatalog.load_weapon(interactable.item_id)
	if new_weapon == null:
		player.points += interactable.cost
		player.stats_changed.emit(player.points, player.kills, player.headshots)
		return
	if not player.equip_weapon(new_weapon):
		player.points += interactable.cost
		player.stats_changed.emit(player.points, player.kills, player.headshots)

func _purchase_ammo(item_id: StringName, cost: int) -> void:
	if not _owns_weapon(item_id) or _weapon_reserve_full(item_id):
		return
	if not _spend_points(cost):
		return
	if player is ZombieTownInventoryPlayer:
		var inventory_player := player as ZombieTownInventoryPlayer
		if not inventory_player.refill_weapon_reserve(item_id):
			player.points += cost
			player.stats_changed.emit(player.points, player.kills, player.headshots)
		return
	if player.weapon == null or player.weapon.id != item_id:
		player.points += cost
		player.stats_changed.emit(player.points, player.kills, player.headshots)
		return
	player.reserve_ammo = player.weapon.reserve_ammo
	player.ammo_changed.emit(player.ammo, player.reserve_ammo, player.reloading)

func _purchase_pack_a_punch() -> void:
	if player.weapon == null or pack_level >= PACK_COSTS.size():
		return
	var cost := PACK_COSTS[pack_level]
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
	if player is ZombieTownInventoryPlayer:
		var inventory_player := player as ZombieTownInventoryPlayer
		inventory_player.set_active_pack_level(pack_level)

func _on_weapon_changed(_display_name: String, _weapon_id: StringName) -> void:
	if player.weapon == null:
		return
	if player is ZombieTownInventoryPlayer:
		var inventory_player := player as ZombieTownInventoryPlayer
		pack_level = inventory_player.get_active_pack_level()
	else:
		pack_level = 0
	_apply_current_weapon_perks()

func _apply_current_weapon_perks() -> void:
	if player.weapon == null:
		return
	_apply_perks_to_weapon(player.weapon)

func _apply_perk_to_all_weapons(perk_id: StringName) -> void:
	if player is ZombieTownInventoryPlayer:
		var inventory_player := player as ZombieTownInventoryPlayer
		for slot_weapon: WeaponData in inventory_player.get_weapon_resources():
			_apply_single_weapon_perk(slot_weapon, perk_id)
		return
	if player.weapon != null:
		_apply_single_weapon_perk(player.weapon, perk_id)

func _apply_perks_to_weapon(slot_weapon: WeaponData) -> void:
	if has_perk(&"speed"):
		_apply_single_weapon_perk(slot_weapon, &"speed")
	if has_perk(&"dtap"):
		_apply_single_weapon_perk(slot_weapon, &"dtap")

func _apply_single_weapon_perk(slot_weapon: WeaponData, perk_id: StringName) -> void:
	var instance_id := slot_weapon.get_instance_id()
	match perk_id:
		&"speed":
			if speed_applied.has(instance_id):
				return
			slot_weapon.reload_time *= 0.5
			speed_applied[instance_id] = true
		&"dtap":
			if double_tap_applied.has(instance_id):
				return
			slot_weapon.damage *= 1.35
			slot_weapon.fire_interval *= 0.8
			double_tap_applied[instance_id] = true

func _owns_weapon(item_id: StringName) -> bool:
	if player is ZombieTownInventoryPlayer:
		var inventory_player := player as ZombieTownInventoryPlayer
		return inventory_player.owns_weapon(item_id)
	return player.weapon != null and player.weapon.id == item_id

func _weapon_reserve_full(item_id: StringName) -> bool:
	if player is ZombieTownInventoryPlayer:
		var inventory_player := player as ZombieTownInventoryPlayer
		return inventory_player.is_weapon_reserve_full(item_id)
	if player.weapon == null or player.weapon.id != item_id:
		return false
	return player.reserve_ammo >= player.weapon.reserve_ammo

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
