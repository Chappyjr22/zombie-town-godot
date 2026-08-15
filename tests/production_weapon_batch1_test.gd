extends SceneTree

const BATCH_1_IDS: Array[StringName] = [&"m1911", &"mp7", &"ump"]
const EXPECTED_MODELS := {
	&"m1911": "res://assets/weapons/runtime/production/m1911.glb",
	&"mp7": "res://assets/weapons/runtime/production/diamo/mp7.glb",
	&"ump": "res://assets/weapons/runtime/production/diamo/ump.glb",
}
const REQUIRED_SOCKETS: Array[String] = [
	"Socket_Optic", "Socket_Muzzle", "Socket_Underbarrel", "Socket_Side",
	"Socket_Stock", "Socket_Bayonet", "Socket_Magazine",
	"Socket_PrimaryGrip", "Socket_SupportGrip",
]

var failures: Array[String] = []
var visual_capture := false
var capture_directory := ""


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	visual_capture = "--visual-capture" in OS.get_cmdline_user_args()
	if visual_capture:
		capture_directory = "user://production_weapon_batch1_captures_%d" % Time.get_ticks_msec()
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
	var canonical_m1911 := ZombieTownWeaponCatalog.load_weapon(&"m1911")
	_check(canonical_m1911 != null, "Canonical M1911 WeaponData remains present")
	if canonical_m1911 != null and canonical_m1911.viewmodel_profile != null:
		_check(canonical_m1911.viewmodel_profile.resource_path == "res://resources/weapons/viewmodels/candidates/m1911_production_candidate_viewmodel.tres", "Canonical M1911 uses the approved authentic M1911 ViewmodelConfig")
		_check(canonical_m1911.viewmodel_profile.model_scene.resource_path == "res://assets/weapons/runtime/production/m1911.glb", "Canonical M1911 renders the authentic DavidFalke production model")
	var makarov := ZombieTownWeaponCatalog.load_weapon(&"makarov")
	_check(makarov != null and not makarov.standard_gameplay_enabled, "Standalone Makarov remains a non-standard reserve weapon")
	if makarov != null and makarov.viewmodel_profile != null:
		_check(makarov.viewmodel_profile.resource_path == "res://resources/weapons/viewmodels/m1911_viewmodel.tres", "Standalone Makarov preserves the approved Makarov ViewmodelConfig")
		_check(makarov.viewmodel_profile.model_scene.resource_path == "res://assets/weapons/runtime/makarov.glb", "Standalone Makarov preserves the approved Makarov model")

	for weapon_id: StringName in BATCH_1_IDS:
		await _validate_weapon(player, weapon_id)

	await _validate_m1911_mechanism(player)
	world.queue_free()
	await process_frame
	if visual_capture:
		print("PRODUCTION_WEAPON_BATCH_1_CAPTURE_DIR: %s" % ProjectSettings.globalize_path(capture_directory))
	_finish()


func _validate_live_roster_is_migrated() -> void:
	var developer_ids := ZombieTownWeaponCatalog.developer_weapon_ids()
	for weapon_id: StringName in BATCH_1_IDS:
		_check(weapon_id in developer_ids, "%s is developer-selectable" % weapon_id)
		_check(ZombieTownWeaponCatalog.is_standard_gameplay_weapon(weapon_id), "%s is active in standard gameplay" % weapon_id)
	for weapon_id: StringName in [&"mp7", &"ump"]:
		_check(ZombieTownMysteryBox.WEAPON_WEIGHTS.has(weapon_id), "%s appears in the base Mystery Box" % weapon_id)
		_check(ZombieTownGameplayMysteryBox.GAMEPLAY_WEAPON_WEIGHTS.has(weapon_id), "%s appears in the gameplay Mystery Box" % weapon_id)
	_check(not ZombieTownMysteryBox.WEAPON_WEIGHTS.has(&"m1911"), "Starting M1911 remains outside the Mystery Box")


func _validate_weapon(player: ZombieTownSurvivalPlayer, weapon_id: StringName) -> void:
	var data := ZombieTownWeaponCatalog.load_developer_weapon(weapon_id)
	_check(data != null, "%s developer WeaponData loads" % weapon_id)
	if data == null:
		return
	_check(data.viewmodel_profile != null, "%s has a production ViewmodelConfig" % weapon_id)
	if data.viewmodel_profile == null:
		return
	_check(data.viewmodel_profile.model_scene != null, "%s profile links a production model" % weapon_id)
	if data.viewmodel_profile.model_scene != null:
		_check(data.viewmodel_profile.model_scene.resource_path == str(EXPECTED_MODELS[weapon_id]), "%s uses the Batch 1 production derivative" % weapon_id)
	_check(data.viewmodel_profile.attachment_layout != null, "%s retains an attachment layout" % weapon_id)
	_check(player.equip_weapon(data), "%s equips through developer access" % weapon_id)
	await process_frame
	await process_frame
	_check(player.weapon != null and player.weapon.id == weapon_id, "%s becomes active" % weapon_id)
	var anchor := _production_anchor(player.first_person_viewmodel.model_root)
	_check(anchor != null, "%s instantiates through the production viewmodel path" % weapon_id)
	var muzzle_socket := anchor.find_child("Socket_Muzzle", true, false) as Node3D if anchor != null else null
	var stock_socket := anchor.find_child("Socket_Stock", true, false) as Node3D if anchor != null else null
	_check(
		muzzle_socket != null and stock_socket != null and muzzle_socket.position.z < stock_socket.position.z,
		"%s production sockets use camera-forward -Z" % weapon_id,
	)
	_check(_has_visible_mesh(anchor), "%s production mesh renders" % weapon_id)
	_check(_has_pbr_material(anchor), "%s has textured PBR material" % weapon_id)
	for socket_name: String in REQUIRED_SOCKETS:
		_check(anchor != null and anchor.find_child(socket_name, true, false) != null, "%s exposes %s" % [weapon_id, socket_name])
	for component_name: String in ["Base", "Bolt", "Magazine", "Trigger"]:
		if weapon_id != &"m1911":
			_check(anchor != null and anchor.find_child(component_name, true, false) != null, "%s preserves %s component" % [weapon_id, component_name])

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
				for _frame in 4:
					await process_frame
				var image := player.viewmodel_viewport.get_texture().get_image()
				_check(image != null, "%s %s visual capture has a rendering image" % [weapon_id, state])
				if image != null:
					var save_path := "%s/%s_%s.png" % [capture_directory, weapon_id, state]
					_check(image.save_png(save_path) == OK, "%s %s visual capture saves" % [weapon_id, state])
		var save_path := "user://batch1_%s_tuner_test.tres" % weapon_id
		_check(player.save_active_viewmodel_profile(save_path) == OK, "%s tuner profile saves" % weapon_id)
		var reloaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as WeaponViewmodelProfile
		_check(reloaded != null and reloaded.model_scene != null, "%s tuner save reloads with model link" % weapon_id)
		var absolute_path := ProjectSettings.globalize_path(save_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
		tuner.close()

	var ammo_before := player.ammo
	player.call(&"_fire")
	_check(player.ammo < ammo_before, "%s firing consumes ammunition" % weapon_id)
	player.call(&"_begin_reload")
	_check(player.reloading, "%s reload starts" % weapon_id)


func _validate_m1911_mechanism(player: ZombieTownSurvivalPlayer) -> void:
	var data := ZombieTownWeaponCatalog.load_weapon(&"m1911")
	if data == null or not player.equip_weapon(data):
		_check(false, "M1911 candidate equips for mechanism validation")
		return
	await process_frame
	await process_frame
	var anchor := _production_anchor(player.first_person_viewmodel.model_root)
	for node_name: String in [
		"Frame", "Slide", "ShortRecoil", "FrameBody", "SlideBody",
		"Barrel", "TriggerPivot", "HammerPivot",
		"SlideStopPivot", "ThumbSafetyPivot", "MagazineRelease",
		"FrontSight", "RearSight", "GripSafety",
		"Marker_SlideForward", "Marker_SlideRearward", "Marker_SlideLocked",
		"Marker_MagazineSeated", "Marker_MagazineRemoved", "Marker_HammerCocked",
	]:
		_check(anchor != null and anchor.find_child(node_name, true, false) != null, "M1911 hierarchy exposes %s" % node_name)
	var slide := anchor.find_child("Slide", true, false) if anchor != null else null
	_check(slide != null and slide.find_child("FrontSight", true, false) != null, "M1911 front sight is parented to Slide")
	_check(slide != null and slide.find_child("RearSight", true, false) != null, "M1911 rear sight is parented to Slide")
	var anchor_3d := anchor as Node3D
	var front_sight := anchor.find_child("FrontSight", true, false) as MeshInstance3D if anchor != null else null
	var rear_sight := anchor.find_child("RearSight", true, false) as MeshInstance3D if anchor != null else null
	var slide_body := anchor.find_child("SlideBody", true, false) as MeshInstance3D if anchor != null else null
	if anchor_3d != null and front_sight != null and rear_sight != null and slide_body != null:
		var front_position := _mesh_center_in_anchor(anchor_3d, front_sight)
		var rear_position := _mesh_center_in_anchor(anchor_3d, rear_sight)
		var slide_position := _mesh_center_in_anchor(anchor_3d, slide_body)
		_check(minf(front_position.y, rear_position.y) > slide_position.y, "M1911 sights remain upright above the slide")
	else:
		_check(false, "M1911 semantic components are available for orientation validation")
	_check(anchor == null or anchor.find_child("Magazine", true, false) == null, "Known loose M1911 showcase magazine is suppressed at runtime")
	for pivot_mapping: Array in [
		["TriggerPivot", "Trigger"],
		["HammerPivot", "Hammer"],
		["SlideStopPivot", "SlideStop"],
		["ThumbSafetyPivot", "ThumbSafety"],
	]:
		var pivot := anchor.find_child(pivot_mapping[0], true, false) as Node3D if anchor != null else null
		var component := anchor.find_child(pivot_mapping[1], true, false) as MeshInstance3D if anchor != null else null
		var aligned := false
		if anchor_3d != null and pivot != null and component != null:
			var pivot_position := anchor_3d.to_local(pivot.global_position)
			var component_center := _mesh_center_in_anchor(anchor_3d, component)
			aligned = pivot_position.distance_to(component_center) < 0.0005
		_check(aligned, "M1911 %s marker stays centered on %s" % pivot_mapping)


func _mesh_center_in_anchor(anchor: Node3D, instance: MeshInstance3D) -> Vector3:
	return anchor.to_local(instance.to_global(instance.mesh.get_aabb().get_center()))


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
				if material is BaseMaterial3D and (material as BaseMaterial3D).albedo_texture != null:
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
		print("PRODUCTION_WEAPON_BATCH_1_TEST: PASS")
		quit(0)
		return
	print("PRODUCTION_WEAPON_BATCH_1_TEST: FAIL (%d)" % failures.size())
	quit(1)
