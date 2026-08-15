extends SceneTree

const PRODUCTION_WEAPON_IDS: Array[StringName] = [
	&"m1911",
	&"ak74u",
	&"mp7",
	&"ump",
	&"hk416",
	&"m16",
	&"rem870",
	&"benelli_m4",
	&"aa12",
	&"rpd",
	&"m200",
	&"rpg7",
	&"flaregun",
]
const PROCEDURAL_WEAPON_IDS: Array[StringName] = [
	&"bknife",
	&"raygun",
	&"raygun2",
	&"thunder",
	&"waffe",
]
const PRODUCTION_MODEL_PATHS := {
	&"m1911": "res://assets/weapons/runtime/production/m1911.glb",
	&"ak74u": "res://assets/weapons/runtime/ak47.glb",
	&"mp7": "res://assets/weapons/runtime/production/diamo/mp7.glb",
	&"ump": "res://assets/weapons/runtime/production/diamo/ump.glb",
	&"hk416": "res://assets/weapons/runtime/production/diamo/hk416.glb",
	&"m16": "res://assets/weapons/runtime/production/diamo/m16.glb",
	&"rem870": "res://assets/weapons/runtime/shotgun.glb",
	&"benelli_m4": "res://assets/weapons/runtime/production/diamo/benelli_m4.glb",
	&"aa12": "res://assets/weapons/runtime/production/diamo/aa12.glb",
	&"rpd": "res://assets/weapons/runtime/production/diamo/rpd.glb",
	&"m200": "res://assets/weapons/runtime/production/diamo/cheytac_m200.glb",
	&"rpg7": "res://assets/weapons/runtime/production/diamo/rpg7.glb",
	&"flaregun": "res://assets/weapons/runtime/flare_gun.glb",
}
const STANDARD_GAMEPLAY_WEAPON_IDS: Array[StringName] = [
	&"m1911",
	&"ak74u",
	&"mp7",
	&"ump",
	&"hk416",
	&"m16",
	&"rem870",
	&"benelli_m4",
	&"aa12",
	&"rpd",
	&"m200",
	&"rpg7",
	&"flaregun",
	&"bknife",
	&"raygun",
	&"raygun2",
	&"thunder",
	&"waffe",
]
const RESERVE_WEAPON_IDS: Array[StringName] = [
	&"makarov", &"mp5", &"skorpion", &"m4a1", &"rpk", &"m1216",
	&"dsr50", &"luger", &"galil",
]
const DEPRECATED_WEAPON_IDS: Array[StringName] = [&"m14", &"olympia", &"warmachine", &"hamr"]
const DIAMO_WEAPON_IDS: Array[StringName] = [
	&"mp7", &"ump", &"hk416", &"m16", &"benelli_m4", &"aa12", &"rpd", &"m200", &"rpg7",
]
const EXPECTED_BASE_BOX_WEIGHTS := {
	&"mp7": 12.0, &"ak74u": 12.0, &"rem870": 12.0,
	&"ump": 7.0, &"hk416": 7.0, &"m16": 7.0,
	&"benelli_m4": 6.0, &"aa12": 6.0, &"rpd": 6.0,
	&"m200": 5.0, &"flaregun": 3.0, &"rpg7": 1.89,
	&"raygun": 2.08, &"raygun2": 2.08, &"thunder": 1.6793, &"waffe": 1.6793,
}

var failures: Array[String] = []
var capture_directory := ""


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var visual_capture := "--visual-capture" in OS.get_cmdline_user_args()
	if visual_capture:
		capture_directory = "user://production_weapon_captures_%d" % Time.get_ticks_msec()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_directory))
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	_check(player_scene != null, "Player scene loads")
	if player_scene == null:
		_finish()
		return
	var world := Node3D.new()
	world.name = "ProductionWeaponTestWorld"
	root.add_child(world)
	current_scene = world
	var player := player_scene.instantiate() as ZombieTownSurvivalPlayer
	world.add_child(player)
	await process_frame
	await process_frame
	_check(ZombieTownWeaponCatalog.all_weapon_ids().size() == 31, "Weapon catalog exposes all 31 core, reserve, and preserved legacy WeaponData resources")
	_validate_starting_weapon(player)
	_validate_roster_policy(player)
	_validate_attachment_catalog()

	var previous_id: StringName = player.weapon.id if player.weapon != null else &""
	for weapon_id: StringName in PRODUCTION_WEAPON_IDS:
		var data := ZombieTownWeaponCatalog.load_weapon(weapon_id)
		_check(data != null, "%s WeaponData loads" % weapon_id)
		if data == null:
			continue
		_check(data.viewmodel_profile != null, "%s has a linked viewmodel profile" % weapon_id)
		_check(data.viewmodel_profile.model_scene != null, "%s profile has a production model" % weapon_id)
		_check(data.viewmodel_profile.model_scene.resource_path == str(PRODUCTION_MODEL_PATHS[weapon_id]), "%s uses the approved production model" % weapon_id)
		_check(player.equip_weapon(data), "%s equips" % weapon_id)
		await process_frame
		await process_frame
		_check(player.weapon != null and player.weapon.id == weapon_id, "%s becomes active after switching from %s" % [weapon_id, previous_id])
		previous_id = weapon_id
		_check(player.first_person_viewmodel.current_weapon_id == weapon_id, "%s reaches the production viewmodel" % weapon_id)
		var production_anchor := _production_anchor(player.first_person_viewmodel.model_root)
		_check(production_anchor != null, "%s instantiates a production asset anchor" % weapon_id)
		_check(_has_visible_mesh(production_anchor), "%s production mesh renders" % weapon_id)
		if weapon_id in DIAMO_WEAPON_IDS:
			_check(_has_pbr_material(production_anchor), "%s uses its optimized production PBR material" % weapon_id)
			_validate_attachment_sockets(production_anchor, weapon_id)
		else:
			_check(_has_pbr_material(production_anchor), "%s production mesh has textured PBR material" % weapon_id)

		var profile := player.active_viewmodel_profile
		_check(profile != null, "%s uses the data-driven presentation pipeline" % weapon_id)
		if profile != null:
			if weapon_id in DIAMO_WEAPON_IDS:
				_check(profile.attachment_layout != null, "%s links a reusable attachment layout" % weapon_id)
				if profile.attachment_layout != null:
					_check(not profile.attachment_layout.supported_slots.is_empty(), "%s retains its reusable attachment slot definitions" % weapon_id)
					_check(profile.attachment_layout.get("pack_a_punch_attachment_ids") is Array, "%s retains the Pack-a-Punch visual variant data home" % weapon_id)
					_check(profile.attachment_layout.get("named_variant_attachment_ids") is Dictionary, "%s retains named progression variant data homes" % weapon_id)
			_validate_tuner_states(player, profile, weapon_id)
			if visual_capture:
				await _capture_tuning_states(player, weapon_id)

		var ammo_before := player.ammo
		player.call(&"_fire")
		_check(player.ammo < ammo_before, "%s firing consumes ammunition" % weapon_id)
		player.call(&"_begin_reload")
		_check(player.reloading, "%s reload starts after firing" % weapon_id)

	_validate_projectile_and_splash(player)
	_validate_developer_weapon_selector(player)
	await _validate_procedural_fallbacks(player)
	_validate_save_compatibility(player)
	await _validate_town_wall_buy_roster(world)

	world.queue_free()
	await process_frame
	if visual_capture:
		print("PRODUCTION_WEAPON_CAPTURE_DIR: %s" % ProjectSettings.globalize_path(capture_directory))
	_finish()


func _validate_roster_policy(player: ZombieTownSurvivalPlayer) -> void:
	var catalog_ids := ZombieTownWeaponCatalog.all_weapon_ids()
	var standard_ids := ZombieTownWeaponCatalog.standard_gameplay_weapon_ids()
	_check(standard_ids.size() == STANDARD_GAMEPLAY_WEAPON_IDS.size(), "Standard gameplay roster exposes exactly 18 approved weapons")
	for weapon_id: StringName in catalog_ids:
		var data := ZombieTownWeaponCatalog.load_weapon(weapon_id)
		_check(data != null, "%s remains preserved in the developer catalog" % weapon_id)
		if data == null:
			continue
		var should_be_standard := weapon_id in STANDARD_GAMEPLAY_WEAPON_IDS
		_check(data.standard_gameplay_enabled == should_be_standard, "%s standard-gameplay status matches the approved roster" % weapon_id)
		_check(ZombieTownWeaponCatalog.is_standard_gameplay_weapon(weapon_id) == should_be_standard, "%s catalog eligibility matches its resource" % weapon_id)
		_check((weapon_id in standard_ids) == should_be_standard, "%s appears in the correct catalog roster" % weapon_id)
		_check(data.deprecated == (weapon_id in DEPRECATED_WEAPON_IDS), "%s deprecation status is explicit" % weapon_id)

	for weapon_id: StringName in RESERVE_WEAPON_IDS + DEPRECATED_WEAPON_IDS:
		var data := ZombieTownWeaponCatalog.load_weapon(weapon_id)
		_check(data != null and player.equip_weapon(data), "%s remains equippable through developer access" % weapon_id)
		_check(not ZombieTownMysteryBox.WEAPON_WEIGHTS.has(weapon_id), "%s is absent from base Mystery Box weights" % weapon_id)
		_check(weapon_id not in ZombieTownMysteryBox.CYCLE_POOL, "%s is absent from base Mystery Box display cycling" % weapon_id)
		_check(not ZombieTownGameplayMysteryBox.GAMEPLAY_WEAPON_WEIGHTS.has(weapon_id), "%s is absent from gameplay Mystery Box weights" % weapon_id)
		_check(weapon_id not in ZombieTownGameplayMysteryBox.GAMEPLAY_CYCLE_POOL, "%s is absent from gameplay Mystery Box display cycling" % weapon_id)

	_check(ZombieTownMysteryBox.WEAPON_WEIGHTS.size() == EXPECTED_BASE_BOX_WEIGHTS.size(), "Base Mystery Box has the approved weighted roster")
	for weapon_variant: Variant in EXPECTED_BASE_BOX_WEIGHTS.keys():
		var weapon_id := StringName(str(weapon_variant))
		var expected_weight := float(EXPECTED_BASE_BOX_WEIGHTS[weapon_id])
		_check(is_equal_approx(float(ZombieTownMysteryBox.WEAPON_WEIGHTS.get(weapon_id, -1.0)), expected_weight), "%s has the approved base Mystery Box weight" % weapon_id)
		_check(weapon_id in ZombieTownMysteryBox.CYCLE_POOL, "%s appears in base Mystery Box display cycling" % weapon_id)
		_check(is_equal_approx(float(ZombieTownGameplayMysteryBox.GAMEPLAY_WEAPON_WEIGHTS.get(weapon_id, -1.0)), expected_weight), "%s has the approved gameplay Mystery Box weight" % weapon_id)
		_check(weapon_id in ZombieTownGameplayMysteryBox.GAMEPLAY_CYCLE_POOL, "%s appears in gameplay Mystery Box display cycling" % weapon_id)
	_check(is_equal_approx(float(ZombieTownGameplayMysteryBox.GAMEPLAY_WEAPON_WEIGHTS.get(&"bknife", -1.0)), 5.0), "Gameplay Mystery Box retains Ballistic Knife at weight 5")

	for weapon_variant: Variant in ZombieTownMysteryBox.WEAPON_WEIGHTS.keys():
		var weapon_id := StringName(str(weapon_variant))
		_check(ZombieTownWeaponCatalog.is_standard_gameplay_weapon(weapon_id), "%s base Mystery Box entry is standard-gameplay eligible" % weapon_id)
	for weapon_variant: Variant in ZombieTownGameplayMysteryBox.GAMEPLAY_WEAPON_WEIGHTS.keys():
		var weapon_id := StringName(str(weapon_variant))
		_check(ZombieTownWeaponCatalog.is_standard_gameplay_weapon(weapon_id), "%s gameplay Mystery Box entry is standard-gameplay eligible" % weapon_id)


func _validate_starting_weapon(player: ZombieTownSurvivalPlayer) -> void:
	_check(player.weapon != null and player.weapon.id == &"m1911", "Starting weapon remains M1911")
	var m1911 := ZombieTownWeaponCatalog.load_weapon(&"m1911")
	var makarov := ZombieTownWeaponCatalog.load_weapon(&"makarov")
	_check(m1911 != null and m1911.display_name == "M1911", "M1911 retains its authentic identity")
	_check(m1911 != null and m1911.viewmodel_profile != null and m1911.viewmodel_profile.model_scene.resource_path == "res://assets/weapons/runtime/production/m1911.glb", "M1911 uses the authentic DavidFalke production model")
	_check(makarov != null and makarov.id == &"makarov" and makarov.display_name == "Makarov", "Makarov is independently loadable")
	_check(makarov != null and not makarov.standard_gameplay_enabled, "Makarov remains reserve-only")
	_check(makarov != null and makarov.viewmodel_profile != null and makarov.viewmodel_profile.model_scene.resource_path == "res://assets/weapons/runtime/makarov.glb", "Makarov preserves its approved model and presentation")
	for identity_pair: Array in [
		[&"hk416", "HK416", "M4A1"],
		[&"rpd", "RPD", "RPK"],
		[&"aa12", "AA-12", "M1216"],
	]:
		var data := ZombieTownWeaponCatalog.load_weapon(identity_pair[0])
		_check(data != null and data.display_name == identity_pair[1], "%s uses its canonical display identity" % identity_pair[0])
		_check(data != null and data.display_name.find(identity_pair[2]) == -1, "%s is never presented as %s" % [identity_pair[0], identity_pair[2]])


func _validate_save_compatibility(player: ZombieTownSurvivalPlayer) -> void:
	var migrated_state := {
		"version": 1,
		"weapon_slots": [
			{"weapon_id": "m4a1", "ammo": 7, "reserve": 111, "pack_level": 2},
			{"weapon_id": "rpk", "ammo": 22, "reserve": 222, "pack_level": 1},
			{"weapon_id": "m1216", "ammo": 4, "reserve": 44, "pack_level": 3},
		],
		"active_weapon_slot": 1,
		"max_weapon_slots": 3,
	}
	_check(player.restore_inventory_state(migrated_state), "Replacement-ID inventory save restores")
	_check(player.max_weapon_slots == 3 and player.weapon_slots.size() == 3, "Mule Kick third-slot state survives migration")
	_check(_slot_weapon_id(player, 0) == &"hk416", "Old M4A1 save ownership migrates to HK416")
	_check(_slot_weapon_id(player, 1) == &"rpd", "Old RPK save ownership migrates to RPD")
	_check(_slot_weapon_id(player, 2) == &"aa12", "Old M1216 save ownership migrates to AA-12")
	_check(player.active_weapon_slot == 1 and player.weapon.id == &"rpd", "Equipped slot and weapon order survive migration")
	_check(int(player.weapon_slots[0].get("ammo", -1)) == 7 and int(player.weapon_slots[0].get("reserve", -1)) == 111, "Magazine and reserve ammunition survive ID migration")
	_check(int(player.weapon_slots[0].get("pack_level", -1)) == 2 and int(player.weapon_slots[2].get("pack_level", -1)) == 3, "Pack-a-Punch tiers survive ID migration")

	var legacy_state := {
		"weapon_slots": [
			{"weapon_id": "dsr50", "ammo": 3, "reserve": 30, "pack_level": 1},
			{"weapon_id": "m14", "ammo": 5, "reserve": 50, "pack_level": 2},
			{"weapon_id": "warmachine", "ammo": 2, "reserve": 12, "pack_level": 0},
		],
		"active_weapon_slot": 2,
		"max_weapon_slots": 3,
	}
	_check(player.restore_inventory_state(legacy_state), "Sniper and retired-ID inventory save restores")
	_check(_slot_weapon_id(player, 0) == &"m200", "Old standard sniper save ownership migrates to M200")
	_check(_slot_weapon_id(player, 1) == &"m14" and _slot_weapon_id(player, 2) == &"warmachine", "Retired M14 and War Machine ownership remains non-destructively loadable")
	_check(player.weapon.id == &"warmachine" and player.ammo == 2 and player.reserve_ammo == 12, "Retired equipped weapon and ammunition remain intact")

	var reserve_state := {
		"weapon_slots": [
			{"weapon_id": "m1911", "ammo": 6, "reserve": 70, "pack_level": 0},
			{"weapon_id": "mp5", "ammo": 31, "reserve": 155, "pack_level": 0},
			{"weapon_id": "skorpion", "ammo": 18, "reserve": 90, "pack_level": 0},
		],
		"active_weapon_slot": 0,
		"max_weapon_slots": 3,
	}
	_check(player.restore_inventory_state(reserve_state), "M1911 and reserve-SMG inventory save restores")
	_check(_slot_weapon_id(player, 0) == &"m1911", "Old m1911 ownership remains M1911 ownership")
	_check(_slot_weapon_id(player, 1) == &"mp5" and _slot_weapon_id(player, 2) == &"skorpion", "Suomi and Grease Gun keep their legacy IDs")
	var serialized := player.serialize_inventory_state()
	_check(int(serialized.get("active_weapon_slot", -1)) == 0 and int(serialized.get("max_weapon_slots", -1)) == 3, "Migrated inventory serializes slot and Mule Kick state")


func _slot_weapon_id(player: ZombieTownSurvivalPlayer, slot_index: int) -> StringName:
	if slot_index < 0 or slot_index >= player.weapon_slots.size():
		return &""
	var weapon_variant: Variant = player.weapon_slots[slot_index].get("weapon")
	if not weapon_variant is WeaponData:
		return &""
	return (weapon_variant as WeaponData).id


func _validate_tuner_states(player: ZombieTownSurvivalPlayer, profile: WeaponViewmodelProfile, weapon_id: StringName) -> void:
	var tuner := player.viewmodel_tuner
	_check(tuner != null, "%s has Viewmodel Tuner access" % weapon_id)
	if tuner == null:
		return
	tuner.call(&"_input", _pressed_key(KEY_QUOTELEFT))
	_check(tuner.is_active(), "%s opens in the Viewmodel Tuner" % weapon_id)
	for state_key: int in [KEY_1, KEY_2, KEY_3]:
		tuner.call(&"_input", _pressed_key(state_key))
		var state: StringName = tuner.tuning_state
		_check(player.weapon_root.position.is_equal_approx(profile.state_position(state)), "%s %s preview applies its position" % [weapon_id, state])
		_check(is_equal_approx(player.viewmodel_camera.fov, profile.state_viewmodel_fov(state)), "%s %s preview applies its FOV" % [weapon_id, state])
	var save_path := "user://%s_viewmodel_migration_test.tres" % weapon_id
	_check(player.save_active_viewmodel_profile(save_path) == OK, "%s tuner profile can be saved" % weapon_id)
	var saved := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as WeaponViewmodelProfile
	_check(saved != null and saved.model_scene != null, "%s saved tuner profile reloads with its model" % weapon_id)
	var absolute_save_path := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(absolute_save_path):
		DirAccess.remove_absolute(absolute_save_path)
	tuner.close()


func _validate_developer_weapon_selector(player: ZombieTownSurvivalPlayer) -> void:
	var tuner := player.viewmodel_tuner
	if tuner == null or player.weapon == null:
		return
	var starting_id := player.weapon.id
	var weapon_ids := ZombieTownWeaponCatalog.all_weapon_ids()
	var starting_index := weapon_ids.find(starting_id)
	var expected_next := weapon_ids[(starting_index + 1) % weapon_ids.size()]
	tuner.call(&"_input", _pressed_key(KEY_QUOTELEFT))
	tuner.call(&"_input", _pressed_key(KEY_PAGEDOWN))
	_check(player.weapon != null and player.weapon.id == expected_next, "Page Down selects the next developer weapon")
	_check(tuner.tuning_state == &"hip", "Developer weapon switching returns to HIP tuning")
	tuner.call(&"_input", _pressed_key(KEY_PAGEUP))
	_check(player.weapon != null and player.weapon.id == starting_id, "Page Up selects the previous developer weapon")
	tuner.close()


func _validate_procedural_fallbacks(player: ZombieTownSurvivalPlayer) -> void:
	for weapon_id: StringName in PROCEDURAL_WEAPON_IDS:
		var data := ZombieTownWeaponCatalog.load_weapon(weapon_id)
		_check(data != null, "%s unmatched WeaponData loads" % weapon_id)
		if data == null:
			continue
		_check(data.viewmodel_profile == null, "%s remains intentionally procedural" % weapon_id)
		_check(player.equip_weapon(data), "%s procedural fallback equips" % weapon_id)
		await process_frame
		await process_frame
		_check(_production_anchor(player.first_person_viewmodel.model_root) == null, "%s does not substitute an unrelated production model" % weapon_id)
		_check(_has_visible_mesh(player.first_person_viewmodel.model_root), "%s procedural fallback renders" % weapon_id)
		var ammo_before := player.ammo
		player.next_fire_time = 0.0
		player.reloading = false
		player.call(&"_fire")
		_check(player.ammo < ammo_before, "%s firing consumes ammunition" % weapon_id)
		player.call(&"_begin_reload")
		_check(player.reloading, "%s reload starts after firing" % weapon_id)


func _validate_projectile_and_splash(player: ZombieTownSurvivalPlayer) -> void:
	var rpg7 := ZombieTownWeaponCatalog.load_weapon(&"rpg7")
	_check(rpg7 != null and player.equip_weapon(rpg7), "RPG-7 equips for projectile regression")
	if rpg7 == null:
		return
	player.call(&"_spawn_projectile", player.camera.global_position, -player.camera.global_basis.z)
	var projectile: ZombieTownWeaponProjectile = null
	for child: Node in current_scene.get_children():
		if child is ZombieTownWeaponProjectile:
			projectile = child as ZombieTownWeaponProjectile
	_check(projectile != null, "RPG-7 uses the shared projectile runtime")
	if projectile == null:
		return
	_check(projectile.projectile_type == &"rocket", "RPG-7 projectile keeps rocket identity")
	_check(is_equal_approx(projectile.speed, rpg7.projectile_speed), "RPG-7 projectile inherits configured speed")
	_check(is_equal_approx(projectile.gravity, rpg7.projectile_gravity), "RPG-7 projectile inherits configured gravity")
	_check(is_equal_approx(projectile.splash_damage, rpg7.splash_damage) and projectile.splash_damage > 0.0, "RPG-7 preserves shared splash damage")
	_check(is_equal_approx(projectile.splash_radius, rpg7.splash_radius) and projectile.splash_radius > 0.0, "RPG-7 preserves shared explosion radius")
	_check(projectile.allow_self_damage == rpg7.self_damage, "RPG-7 preserves shared self-damage behavior")
	projectile.queue_free()


func _validate_town_wall_buy_roster(world: Node3D) -> void:
	var town_scene := load("res://scenes/maps/town.tscn") as PackedScene
	_check(town_scene != null, "Town scene loads for roster placement validation")
	if town_scene == null:
		return
	var town := town_scene.instantiate() as ZombieTownTown
	_check(town != null, "Town scene instantiates for roster placement validation")
	if town == null:
		return
	town.runtime_bake_navigation = false
	world.add_child(town)
	for _frame in 4:
		await process_frame

	var wall_buy_ids: Array[StringName] = []
	var ammo_buy_ids: Array[StringName] = []
	for child: Node in town.get_children():
		if child is ZombieTownInteractable:
			var interactable := child as ZombieTownInteractable
			if interactable.interaction_kind == &"weapon":
				wall_buy_ids.append(interactable.item_id)
			elif interactable.interaction_kind == &"ammo":
				ammo_buy_ids.append(interactable.item_id)
	var expected_wall_buy_ids: Array[StringName] = [&"mp7", &"ak74u", &"rem870"]
	_check(wall_buy_ids.size() == expected_wall_buy_ids.size(), "Town spawns exactly three active conventional weapon wall buys")
	for weapon_id: StringName in expected_wall_buy_ids:
		_check(weapon_id in wall_buy_ids, "Town activates the %s wall buy" % weapon_id)
	for weapon_id: StringName in RESERVE_WEAPON_IDS + DEPRECATED_WEAPON_IDS:
		_check(weapon_id not in wall_buy_ids, "Town does not spawn the inactive %s wall buy" % weapon_id)
	_check(ammo_buy_ids.has(&"m1911") and ammo_buy_ids.has(&"hk416"), "Town spawns M1911 and HK416 ammo walls")
	_check(not ammo_buy_ids.has(&"m4a1"), "Town no longer spawns the M4A1 ammo wall")
	var inactive_ids: Array[StringName] = []
	for marker_node: Node in get_nodes_in_group(&"inactive_wall_buy"):
		if town.is_ancestor_of(marker_node):
			inactive_ids.append(StringName(str(marker_node.get_meta(&"former_item_id", ""))))
	_check(inactive_ids.has(&"m14") and inactive_ids.has(&"olympia"), "Retired M14 and Olympia wall locations remain as inactive marker infrastructure")
	town.queue_free()
	await process_frame


func _capture_tuning_states(player: ZombieTownSurvivalPlayer, weapon_id: StringName) -> void:
	var tuner := player.viewmodel_tuner
	if tuner == null:
		return
	tuner.call(&"_input", _pressed_key(KEY_QUOTELEFT))
	for state: StringName in [&"hip", &"ads", &"sprint"]:
		tuner.call(&"_set_state", state)
		for _frame in 4:
			await process_frame
		var image := player.viewmodel_viewport.get_texture().get_image()
		if image == null:
			_check(false, "%s %s visual capture has a rendering image" % [weapon_id, state])
			continue
		var save_path := "%s/%s_%s.png" % [capture_directory, weapon_id, state]
		_check(image.save_png(save_path) == OK, "%s %s visual capture saves" % [weapon_id, state])
	tuner.close()


func _has_visible_mesh(node: Node) -> bool:
	if node == null:
		return false
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.visible and mesh_instance.mesh != null:
			return true
	for child: Node in node.get_children():
		if _has_visible_mesh(child):
			return true
	return false


func _production_anchor(model_root: Node) -> Node:
	for child: Node in model_root.get_children():
		if bool(child.get_meta(&"production_weapon_asset", false)):
			return child
	return null


func _has_pbr_material(node: Node) -> bool:
	if node == null:
		return false
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index: int in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.get_active_material(surface_index)
				if material is BaseMaterial3D and (material as BaseMaterial3D).albedo_texture != null:
					return true
	for child: Node in node.get_children():
		if _has_pbr_material(child):
			return true
	return false


func _has_flat_source_material(node: Node) -> bool:
	if node == null:
		return false
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index: int in mesh_instance.mesh.get_surface_count():
				if mesh_instance.get_active_material(surface_index) is BaseMaterial3D:
					return true
	for child: Node in node.get_children():
		if _has_flat_source_material(child):
			return true
	return false


func _validate_attachment_sockets(production_anchor: Node, weapon_id: StringName) -> void:
	for socket_name: String in [
		"Socket_Optic",
		"Socket_Muzzle",
		"Socket_Underbarrel",
		"Socket_Side",
		"Socket_Stock",
		"Socket_Bayonet",
		"Socket_Magazine",
		"Socket_PrimaryGrip",
		"Socket_SupportGrip",
	]:
		_check(production_anchor.find_child(socket_name, true, false) != null, "%s exposes %s" % [weapon_id, socket_name])


func _validate_attachment_catalog() -> void:
	var attachment_ids := ZombieTownWeaponAttachmentCatalog.all_attachment_ids()
	_check(attachment_ids.size() == 15, "Quaternius catalog preserves all 15 modular attachments")
	for attachment_id: StringName in attachment_ids:
		var attachment := ZombieTownWeaponAttachmentCatalog.load_attachment(attachment_id)
		_check(attachment != null, "%s attachment data loads" % attachment_id)
		if attachment == null:
			continue
		_check(attachment.model_scene != null, "%s attachment preserves its modular provisional model" % attachment_id)
		if attachment.model_scene == null:
			continue
		var instance := attachment.model_scene.instantiate()
		_check(_has_visible_mesh(instance), "%s attachment mesh renders" % attachment_id)
		_check(instance.find_child("MountPoint", true, false) != null, "%s attachment exposes a normalized mount point" % attachment_id)
		instance.free()


func _pressed_key(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("PRODUCTION_WEAPON_MIGRATION_TEST: PASS")
		quit(0)
		return
	print("PRODUCTION_WEAPON_MIGRATION_TEST: FAIL (%d)" % failures.size())
	quit(1)
