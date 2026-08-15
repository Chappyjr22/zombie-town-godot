extends SceneTree

const BATCH_3_IDS: Array[StringName] = [
	&"benelli_m4", &"aa12", &"m200", &"rpg7",
]
const EXPECTED_MODELS := {
	&"benelli_m4": "res://assets/weapons/runtime/production/diamo/benelli_m4.glb",
	&"aa12": "res://assets/weapons/runtime/production/diamo/aa12.glb",
	&"m200": "res://assets/weapons/runtime/production/diamo/cheytac_m200.glb",
	&"rpg7": "res://assets/weapons/runtime/production/diamo/rpg7.glb",
}
const REQUIRED_SOCKETS: Array[String] = [
	"Socket_Optic", "Socket_Muzzle", "Socket_Underbarrel", "Socket_Side",
	"Socket_Stock", "Socket_Bayonet", "Socket_Magazine",
	"Socket_PrimaryGrip", "Socket_SupportGrip",
]
const MECHANISMS := {
	&"benelli_m4": [
		"Receiver", "ReceiverBody", "BoltAction", "BoltBody", "BoltPivot",
		"Trigger", "TriggerPivot", "MagazineTubePreparation",
		"Marker_BoltForward", "Marker_BoltRearward", "Marker_LoadingGatePivot",
		"Marker_ShellInsertStart", "Marker_ShellInserted",
		"Marker_ShellEjectionPort", "Marker_ShellEjected",
		"Socket_ShellLoad", "Socket_ShellEject",
	],
	&"aa12": [
		"Receiver", "ReceiverBody", "BoltAction", "BoltBody", "BoltPivot",
		"Trigger", "TriggerPivot", "SideShellCarrier", "MagazinePreparation",
		"Marker_BoltForward", "Marker_BoltRearward",
		"Marker_MagazineSeated", "Marker_MagazineRemoved",
	],
	&"m200": [
		"Receiver", "ReceiverBody", "BoltAction", "BoltHandleBody", "BoltPivot",
		"Magazine", "MagazineBody", "MagazinePivot", "Trigger", "TriggerPivot",
		"Scope", "ScopeBody", "Bipod", "BipodBody", "BipodPivot",
		"Marker_BoltLocked", "Marker_BoltUnlocked", "Marker_BoltRearward",
		"Marker_MagazineSeated", "Marker_MagazineRemoved",
	],
	&"rpg7": [
		"Launcher", "LauncherBody", "Rocket", "RocketBody", "RocketPivot",
		"Marker_RocketSeated", "Marker_RocketRemoved", "Socket_Projectile",
	],
}

var failures: Array[String] = []
var visual_capture := false
var capture_directory := ""


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	visual_capture = "--visual-capture" in OS.get_cmdline_user_args()
	if visual_capture:
		capture_directory = "user://production_weapon_batch3_captures_%d" % Time.get_ticks_msec()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_directory))
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	_check(player_scene != null, "Player scene loads")
	if player_scene == null:
		_finish()
		return
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := player_scene.instantiate() as ZombieTownSurvivalPlayer
	world.add_child(player)
	await process_frame
	await process_frame
	_validate_live_roster_is_migrated()
	for weapon_id: StringName in BATCH_3_IDS:
		await _validate_weapon(player, weapon_id)
	await _validate_developer_selector(player)
	_validate_conversion_reports()
	world.queue_free()
	await process_frame
	if visual_capture:
		print("PRODUCTION_WEAPON_BATCH_3_CAPTURE_DIR: %s" % ProjectSettings.globalize_path(capture_directory))
	_finish()


func _validate_live_roster_is_migrated() -> void:
	_check(ZombieTownWeaponCatalog.all_weapon_ids().size() == 31, "Catalog exposes all core, reserve, and preserved legacy resources")
	var developer_ids := ZombieTownWeaponCatalog.developer_weapon_ids()
	for weapon_id: StringName in BATCH_3_IDS:
		_check(weapon_id in developer_ids, "%s is developer-selectable" % weapon_id)
		_check(ZombieTownWeaponCatalog.standard_gameplay_weapon_ids().has(weapon_id), "%s is active in standard gameplay" % weapon_id)
		_check(ZombieTownMysteryBox.WEAPON_WEIGHTS.has(weapon_id), "%s appears in the base Mystery Box" % weapon_id)
		_check(weapon_id in ZombieTownMysteryBox.CYCLE_POOL, "%s appears in the base Mystery Box cycle" % weapon_id)
		_check(ZombieTownGameplayMysteryBox.GAMEPLAY_WEAPON_WEIGHTS.has(weapon_id), "%s appears in the gameplay Mystery Box" % weapon_id)
		_check(weapon_id in ZombieTownGameplayMysteryBox.GAMEPLAY_CYCLE_POOL, "%s appears in the gameplay Mystery Box cycle" % weapon_id)
	var m1216 := ZombieTownWeaponCatalog.load_weapon(&"m1216")
	var sniper := ZombieTownWeaponCatalog.load_weapon(&"dsr50")
	var war_machine := ZombieTownWeaponCatalog.load_weapon(&"warmachine")
	_check(m1216 != null and m1216.id == &"m1216" and m1216.display_name == "M1216" and not m1216.standard_gameplay_enabled, "Old M1216 identity remains intact as legacy")
	_check(sniper != null and sniper.id == &"dsr50" and sniper.display_name == "Sniper Rifle" and not sniper.standard_gameplay_enabled, "Old sniper identity remains intact as legacy")
	_check(war_machine != null and war_machine.id == &"warmachine" and war_machine.display_name == "War Machine" and not war_machine.standard_gameplay_enabled, "Old War Machine identity remains intact as retired legacy")


func _validate_weapon(player: ZombieTownSurvivalPlayer, weapon_id: StringName) -> void:
	var data := ZombieTownWeaponCatalog.load_developer_weapon(weapon_id)
	_check(data != null, "%s developer WeaponData loads" % weapon_id)
	if data == null:
		return
	_check(data.standard_gameplay_enabled, "%s is explicitly live" % weapon_id)
	_check(data.viewmodel_profile != null and data.viewmodel_profile.model_scene != null, "%s has a production profile and model" % weapon_id)
	if data.viewmodel_profile == null or data.viewmodel_profile.model_scene == null:
		return
	_check(data.viewmodel_profile.model_scene.resource_path == str(EXPECTED_MODELS[weapon_id]), "%s uses the correct production derivative" % weapon_id)
	_check(data.viewmodel_profile.attachment_layout != null, "%s has an attachment layout" % weapon_id)
	_validate_identity(data)
	_check(player.equip_weapon(data), "%s equips through developer access" % weapon_id)
	await process_frame
	await process_frame
	_check(player.weapon != null and player.weapon.id == weapon_id, "%s becomes active" % weapon_id)
	var anchor := _production_anchor(player.first_person_viewmodel.model_root)
	_check(anchor != null, "%s uses the production viewmodel path" % weapon_id)
	_check(_has_visible_mesh(anchor), "%s production model renders" % weapon_id)
	_check(_has_pbr_material(anchor), "%s retains Base Color and Normal PBR maps" % weapon_id)
	for socket_name: String in REQUIRED_SOCKETS:
		_check(anchor != null and anchor.find_child(socket_name, true, false) != null, "%s exposes %s" % [weapon_id, socket_name])
	for node_name: String in MECHANISMS[weapon_id]:
		_check(anchor != null and anchor.find_child(node_name, true, false) != null, "%s hierarchy exposes %s" % [weapon_id, node_name])
	if weapon_id == &"aa12":
		_check(anchor.find_child("MagazineBody", true, false) == null, "AA-12 does not mislabel the side carrier as its magazine")
		_check(_markers_are_distinct(anchor, "Marker_MagazineSeated", "Marker_MagazineRemoved"), "AA-12 magazine preparation references are distinct")
	if weapon_id == &"benelli_m4":
		_check(_is_parented_to(anchor, "BoltBody", "BoltAction"), "Benelli bolt/charging-handle mesh is parented to its action group")
		_check(_markers_are_distinct(anchor, "Marker_ShellInsertStart", "Marker_ShellInserted"), "Benelli shell insertion references are distinct")
	if weapon_id == &"m200":
		_check(_is_parented_to(anchor, "BoltHandleBody", "BoltAction"), "M200 bolt handle is parented to its action group")
		_check(_is_parented_to(anchor, "MagazineBody", "Magazine"), "M200 magazine mesh is parented to its magazine group")
		_check(_is_parented_to(anchor, "ScopeBody", "Scope"), "M200 scope remains a separate scoped group")
		_check(_is_parented_to(anchor, "BipodBody", "Bipod"), "M200 bipod remains a separate pivotable group")
	if weapon_id == &"rpg7":
		var layout := data.viewmodel_profile.attachment_layout
		_check(layout.socket_path(&"projectile") == NodePath("Socket_Projectile"), "RPG-7 layout exposes a truthful projectile slot")
		_check(_is_parented_to(anchor, "RocketBody", "Rocket"), "RPG-7 rocket mesh is parented to its removable rocket group")
		_check(_markers_are_distinct(anchor, "Marker_RocketSeated", "Marker_RocketRemoved"), "RPG-7 seated and removed rocket references are distinct")
	_validate_socket_orientation(anchor, weapon_id)
	await _validate_tuner(player, data, weapon_id)
	var ammo_before := player.ammo
	player.call(&"_fire")
	_check(player.ammo < ammo_before, "%s firing consumes ammunition" % weapon_id)
	player.call(&"_begin_reload")
	_check(player.reloading, "%s reload starts" % weapon_id)
	player.reloading = false
	player.next_fire_time = 0.0
	var fallback_data := data.duplicate(true) as WeaponData
	var fallback_profile := data.viewmodel_profile.duplicate(true) as WeaponViewmodelProfile
	fallback_data.id = StringName("%s_fallback_test" % weapon_id)
	fallback_profile.model_scene = null
	fallback_data.viewmodel_profile = fallback_profile
	_check(player.equip_weapon(fallback_data), "%s equips if its production model is unavailable" % weapon_id)
	await process_frame
	await process_frame
	var stale_anchor := _production_anchor(player.first_person_viewmodel.model_root)
	_check(stale_anchor == null or stale_anchor.is_queued_for_deletion(), "%s clears stale production geometry during fallback" % weapon_id)
	_check(_has_visible_mesh(player.first_person_viewmodel.model_root), "%s retains procedural fallback" % weapon_id)


func _validate_identity(data: WeaponData) -> void:
	match data.id:
		&"benelli_m4":
			_check(data.display_name.begins_with("Benelli M4") and data.fire_mode == &"semi" and data.shell_reload, "Benelli keeps its identity and shell-loading role")
		&"aa12":
			_check(data.display_name.begins_with("AA-12") and data.fire_mode == &"auto", "AA-12 keeps its automatic-shotgun identity")
		&"m200":
			_check(data.display_name.begins_with("CheyTac M200") and data.weapon_class == &"sniper", "M200 keeps its sniper identity")
		&"rpg7":
			_check(data.display_name.begins_with("RPG-7") and data.projectile_type == &"rocket", "RPG-7 keeps its rocket-launcher identity")


func _validate_tuner(player: ZombieTownSurvivalPlayer, data: WeaponData, weapon_id: StringName) -> void:
	var tuner := player.viewmodel_tuner
	_check(tuner != null, "%s has Viewmodel Tuner access" % weapon_id)
	if tuner == null:
		return
	tuner.call(&"_toggle")
	_check(tuner.is_active(), "%s opens in the Viewmodel Tuner" % weapon_id)
	for state: StringName in [&"hip", &"ads", &"sprint"]:
		tuner.call(&"_set_state", state)
		_check(player.weapon_root.position.is_equal_approx(data.viewmodel_profile.state_position(state)), "%s %s position previews" % [weapon_id, state])
		_check(is_equal_approx(player.viewmodel_camera.fov, data.viewmodel_profile.state_viewmodel_fov(state)), "%s %s FOV previews" % [weapon_id, state])
		if visual_capture:
			for _frame: int in 4:
				await process_frame
			var image := player.viewmodel_viewport.get_texture().get_image()
			_check(image != null, "%s %s capture renders" % [weapon_id, state])
			if image != null:
				_check(image.save_png("%s/%s_%s.png" % [capture_directory, weapon_id, state]) == OK, "%s %s capture saves" % [weapon_id, state])
	var save_path := "user://batch3_%s_tuner_test.tres" % weapon_id
	_check(player.save_active_viewmodel_profile(save_path) == OK, "%s tuner profile saves" % weapon_id)
	var reloaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as WeaponViewmodelProfile
	_check(reloaded != null and reloaded.model_scene != null and reloaded.attachment_layout != null, "%s tuner save reloads its model and layout" % weapon_id)
	var absolute_path := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	tuner.close()


func _validate_developer_selector(player: ZombieTownSurvivalPlayer) -> void:
	var benelli := ZombieTownWeaponCatalog.load_developer_weapon(&"benelli_m4")
	_check(benelli != null and player.equip_weapon(benelli), "Benelli equips for selector traversal")
	if benelli == null:
		return
	var tuner := player.viewmodel_tuner
	tuner.call(&"_toggle")
	for expected: StringName in [&"aa12", &"rpd", &"m200", &"rpg7"]:
		tuner.call(&"_input", _pressed_key(KEY_PAGEDOWN))
		_check(player.weapon != null and player.weapon.id == expected, "Page Down selects %s" % expected)
	tuner.call(&"_input", _pressed_key(KEY_PAGEUP))
	_check(player.weapon != null and player.weapon.id == &"m200", "Page Up returns from RPG-7 to M200")
	tuner.close()


func _validate_conversion_reports() -> void:
	for asset_id: String in ["benelli_m4", "aa12", "cheytac_m200", "rpg7"]:
		var path := "res://assets/weapons/runtime/production/reports/%s.json" % asset_id
		var report = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(report is Dictionary and bool(report.get("production_candidate", false)), "%s has machine-readable production provenance" % asset_id)
	if FileAccess.file_exists("res://assets/weapons/runtime/production/reports/cheytac_m200.json"):
		var m200 = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/runtime/production/reports/cheytac_m200.json"))
		_check(int(m200.get("topology_cleanup", {}).get("zero_area_faces_removed", 0)) == 5, "M200 derivative records removal of five zero-area faces")
		_check(is_equal_approx(float(m200.get("normalization", {}).get("canonical_yaw_degrees", 0.0)), 180.0), "M200 retains its required 180-degree asset-level muzzle correction")
		_check(not bool(m200.get("orientation_validation", {}).get("source_evaluation_orientation_preserved", true)), "M200 report records that the backwards evaluation orientation was corrected")


func _validate_socket_orientation(anchor: Node, weapon_id: StringName) -> void:
	var anchor_3d := anchor as Node3D
	var muzzle := anchor.find_child("Socket_Muzzle", true, false) as Node3D if anchor != null else null
	var stock := anchor.find_child("Socket_Stock", true, false) as Node3D if anchor != null else null
	var valid := false
	if anchor_3d != null and muzzle != null and stock != null:
		valid = anchor_3d.to_local(muzzle.global_position).z < anchor_3d.to_local(stock.global_position).z
	_check(valid, "%s sockets point camera-forward -Z" % weapon_id)


func _pressed_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _is_parented_to(anchor: Node, child_name: String, ancestor_name: String) -> bool:
	var child := anchor.find_child(child_name, true, false) if anchor != null else null
	while child != null and child != anchor:
		child = child.get_parent()
		if child != null and child.name == ancestor_name:
			return true
	return false


func _markers_are_distinct(anchor: Node, first_name: String, second_name: String) -> bool:
	var first := anchor.find_child(first_name, true, false) as Node3D if anchor != null else null
	var second := anchor.find_child(second_name, true, false) as Node3D if anchor != null else null
	return first != null and second != null and first.global_position.distance_to(second.global_position) > 0.001


func _production_anchor(node: Node) -> Node:
	for child: Node in node.get_children():
		if bool(child.get_meta(&"production_weapon_asset", false)):
			return child
	return null


func _has_visible_mesh(node: Node) -> bool:
	if node == null:
		return false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return true
	for child: Node in node.get_children():
		if _has_visible_mesh(child):
			return true
	return false


func _has_pbr_material(node: Node) -> bool:
	if node == null:
		return false
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			for surface_index: int in instance.mesh.get_surface_count():
				var material := instance.get_active_material(surface_index)
				if material is BaseMaterial3D:
					var pbr := material as BaseMaterial3D
					if pbr.albedo_texture != null and pbr.normal_texture != null:
						return true
	for child: Node in node.get_children():
		if _has_pbr_material(child):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("PRODUCTION_WEAPON_BATCH_3_TEST: PASS")
		quit(0)
		return
	print("PRODUCTION_WEAPON_BATCH_3_TEST: FAIL (%d)" % failures.size())
	quit(1)
