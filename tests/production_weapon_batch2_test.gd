extends SceneTree

const BATCH_2_IDS: Array[StringName] = [&"hk416", &"m16", &"rpd"]
const EXPECTED_MODELS := {
	&"hk416": "res://assets/weapons/runtime/production/diamo/hk416.glb",
	&"m16": "res://assets/weapons/runtime/production/diamo/m16.glb",
	&"rpd": "res://assets/weapons/runtime/production/diamo/rpd.glb",
}
const REQUIRED_SOCKETS: Array[String] = [
	"Socket_Optic", "Socket_Muzzle", "Socket_Underbarrel", "Socket_Side",
	"Socket_Stock", "Socket_Bayonet", "Socket_Magazine",
	"Socket_PrimaryGrip", "Socket_SupportGrip",
]
const REQUIRED_MECHANISM_NODES: Array[String] = [
	"Receiver", "ReceiverBody", "Action", "Magazine", "MagazineBody",
	"Trigger", "TriggerPivot", "Marker_MagazineSeated",
	"Marker_MagazineRemoved", "Marker_BoltForward", "Marker_BoltRearward",
	"Marker_ChargingHandleForward", "Marker_ChargingHandleRearward",
]

var failures: Array[String] = []
var visual_capture := false
var capture_directory := ""


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	visual_capture = "--visual-capture" in OS.get_cmdline_user_args()
	if visual_capture:
		capture_directory = "user://production_weapon_batch2_captures_%d" % Time.get_ticks_msec()
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
	for weapon_id: StringName in BATCH_2_IDS:
		await _validate_weapon(player, weapon_id)
	await _validate_developer_selector(player)

	world.queue_free()
	await process_frame
	if visual_capture:
		print("PRODUCTION_WEAPON_BATCH_2_CAPTURE_DIR: %s" % ProjectSettings.globalize_path(capture_directory))
	_finish()


func _validate_live_roster_is_migrated() -> void:
	_check(ZombieTownWeaponCatalog.all_weapon_ids().size() == 31, "Catalog exposes all core, reserve, and preserved legacy resources")
	var developer_ids := ZombieTownWeaponCatalog.developer_weapon_ids()
	for weapon_id: StringName in BATCH_2_IDS:
		_check(weapon_id in developer_ids, "%s is developer-selectable" % weapon_id)
		_check(ZombieTownWeaponCatalog.standard_gameplay_weapon_ids().has(weapon_id), "%s is active in standard gameplay" % weapon_id)
		_check(ZombieTownMysteryBox.WEAPON_WEIGHTS.has(weapon_id), "%s appears in the base Mystery Box" % weapon_id)
		_check(weapon_id in ZombieTownMysteryBox.CYCLE_POOL, "%s appears in the base Mystery Box display cycle" % weapon_id)
		_check(ZombieTownGameplayMysteryBox.GAMEPLAY_WEAPON_WEIGHTS.has(weapon_id), "%s appears in the gameplay Mystery Box" % weapon_id)
		_check(weapon_id in ZombieTownGameplayMysteryBox.GAMEPLAY_CYCLE_POOL, "%s appears in the gameplay Mystery Box display cycle" % weapon_id)
	var m4 := ZombieTownWeaponCatalog.load_weapon(&"m4a1")
	var rpk := ZombieTownWeaponCatalog.load_weapon(&"rpk")
	_check(m4 != null and m4.display_name == "M4A1" and not m4.standard_gameplay_enabled, "Existing M4A1 identity is preserved as a non-standard legacy weapon")
	_check(rpk != null and rpk.display_name == "RPK" and not rpk.standard_gameplay_enabled, "Existing RPK identity is preserved as a non-standard legacy weapon")


func _validate_weapon(player: ZombieTownSurvivalPlayer, weapon_id: StringName) -> void:
	var data := ZombieTownWeaponCatalog.load_developer_weapon(weapon_id)
	_check(data != null, "%s developer WeaponData loads" % weapon_id)
	if data == null:
		return
	_check(data.standard_gameplay_enabled, "%s is explicitly live" % weapon_id)
	_check(data.viewmodel_profile != null and data.viewmodel_profile.model_scene != null, "%s has a production ViewmodelConfig and model" % weapon_id)
	if data.viewmodel_profile == null or data.viewmodel_profile.model_scene == null:
		return
	_check(data.viewmodel_profile.model_scene.resource_path == str(EXPECTED_MODELS[weapon_id]), "%s uses its correct production derivative" % weapon_id)
	_check(data.viewmodel_profile.attachment_layout != null, "%s has a per-weapon attachment layout" % weapon_id)
	if weapon_id == &"hk416":
		_check(data.display_name.begins_with("HK416"), "HK416 keeps the correct identity")
	if weapon_id == &"m16":
		_check(data.display_name.begins_with("M16") and data.fire_mode == &"burst" and data.burst_count == 3, "M16 keeps a correct three-round burst identity")
	if weapon_id == &"rpd":
		_check(data.display_name.begins_with("RPD"), "RPD keeps the correct identity")

	_check(player.equip_weapon(data), "%s equips through developer access" % weapon_id)
	await process_frame
	await process_frame
	_check(player.weapon != null and player.weapon.id == weapon_id, "%s becomes active" % weapon_id)
	var anchor := _production_anchor(player.first_person_viewmodel.model_root)
	_check(anchor != null, "%s instantiates through the production viewmodel path" % weapon_id)
	_check(_has_visible_mesh(anchor), "%s production model renders" % weapon_id)
	_check(_has_pbr_material(anchor), "%s retains Base Color and Normal PBR maps" % weapon_id)
	for socket_name: String in REQUIRED_SOCKETS:
		_check(anchor != null and anchor.find_child(socket_name, true, false) != null, "%s exposes %s" % [weapon_id, socket_name])
	for node_name: String in REQUIRED_MECHANISM_NODES:
		_check(anchor != null and anchor.find_child(node_name, true, false) != null, "%s hierarchy exposes %s" % [weapon_id, node_name])
	if weapon_id == &"hk416":
		_check(anchor.find_child("Stock", true, false) != null and anchor.find_child("StockBody", true, false) != null, "HK416 preserves the separate stock assembly")
		_check(anchor.find_child("Scope", true, false) == null, "HK416 showcase optics are not merged into the base weapon")
	if weapon_id == &"rpd":
		_check(anchor.find_child("Marker_FeedCoverPivot", true, false) != null, "RPD exposes a feed-cover preparation marker")
		_check(anchor.find_child("Marker_BipodPivot", true, false) != null, "RPD exposes a bipod preparation marker")
	_validate_socket_orientation(anchor, weapon_id)

	var tuner := player.viewmodel_tuner
	_check(tuner != null, "%s has Viewmodel Tuner access" % weapon_id)
	if tuner != null:
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
		var save_path := "user://batch2_%s_tuner_test.tres" % weapon_id
		_check(player.save_active_viewmodel_profile(save_path) == OK, "%s tuner profile saves" % weapon_id)
		var reloaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as WeaponViewmodelProfile
		_check(reloaded != null and reloaded.model_scene != null and reloaded.attachment_layout != null, "%s tuner save reloads with model and attachment layout" % weapon_id)
		var absolute_path := ProjectSettings.globalize_path(save_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
		tuner.close()

	var ammo_before := player.ammo
	player.call(&"_fire")
	_check(player.ammo < ammo_before, "%s firing consumes ammunition" % weapon_id)
	if weapon_id == &"m16":
		_check(player.burst_remaining == 2, "M16 schedules the remaining two shots of its burst")
		player.burst_remaining = 0
	player.call(&"_begin_reload")
	_check(player.reloading, "%s reload starts" % weapon_id)
	player.reloading = false
	player.next_fire_time = 0.0

	var fallback_data := data.duplicate(true) as WeaponData
	var fallback_profile := data.viewmodel_profile.duplicate(true) as WeaponViewmodelProfile
	fallback_data.id = StringName("%s_fallback_test" % weapon_id)
	fallback_profile.model_scene = null
	fallback_data.viewmodel_profile = fallback_profile
	_check(player.equip_weapon(fallback_data), "%s equips when its production model is unavailable" % weapon_id)
	await process_frame
	await process_frame
	var stale_anchor := _production_anchor(player.first_person_viewmodel.model_root)
	_check(stale_anchor == null or stale_anchor.is_queued_for_deletion(), "%s does not retain a stale production model during fallback" % weapon_id)
	_check(_has_visible_mesh(player.first_person_viewmodel.model_root), "%s retains the procedural fallback path" % weapon_id)


func _validate_developer_selector(player: ZombieTownSurvivalPlayer) -> void:
	var hk416 := ZombieTownWeaponCatalog.load_developer_weapon(&"hk416")
	if hk416 == null or not player.equip_weapon(hk416):
		_check(false, "HK416 equips for selector traversal")
		return
	var tuner := player.viewmodel_tuner
	tuner.call(&"_toggle")
	tuner.call(&"_input", _pressed_key(KEY_PAGEDOWN))
	_check(player.weapon != null and player.weapon.id == &"m16", "Page Down selects M16 after HK416")
	tuner.call(&"_input", _pressed_key(KEY_PAGEUP))
	_check(player.weapon != null and player.weapon.id == &"hk416", "Page Up returns to HK416")
	_check(ZombieTownWeaponCatalog.developer_weapon_ids().has(&"rpd"), "RPD remains developer-selectable")
	tuner.close()


func _validate_socket_orientation(anchor: Node, weapon_id: StringName) -> void:
	var anchor_3d := anchor as Node3D
	var muzzle := anchor.find_child("Socket_Muzzle", true, false) as Node3D if anchor != null else null
	var stock := anchor.find_child("Socket_Stock", true, false) as Node3D if anchor != null else null
	var valid := false
	if anchor_3d != null and muzzle != null and stock != null:
		valid = anchor_3d.to_local(muzzle.global_position).z < anchor_3d.to_local(stock.global_position).z
	_check(valid, "%s production sockets point camera-forward -Z" % weapon_id)


func _pressed_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


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
		print("PRODUCTION_WEAPON_BATCH_2_TEST: PASS")
		quit(0)
		return
	print("PRODUCTION_WEAPON_BATCH_2_TEST: FAIL (%d)" % failures.size())
	quit(1)
