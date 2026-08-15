extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var visual_capture := "--visual-capture" in OS.get_cmdline_user_args()
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	_check(player_scene != null, "Player scene loads")
	if player_scene == null:
		_finish()
		return
	var player := player_scene.instantiate() as ZombieTownSurvivalPlayer
	root.add_child(player)
	await process_frame
	await process_frame

	_check(player.weapon != null and player.weapon.id == &"m1911", "Authentic production M1911 equips")
	_check(player.active_viewmodel_profile != null, "M1911 resolves a viewmodel profile")
	_check(player.active_viewmodel_profile_path == "res://resources/weapons/viewmodels/candidates/m1911_production_candidate_viewmodel.tres", "M1911 approved profile path is stable")
	_check(_has_visible_mesh(player.first_person_viewmodel), "Authentic M1911 production mesh is instantiated")
	_check(player.viewmodel_tuner != null, "Tuner exists in editor/debug execution")

	if player.viewmodel_tuner != null:
		var tuner := player.viewmodel_tuner
		tuner.call(&"_input", _pressed_key(KEY_QUOTELEFT))
		_check(tuner.is_active(), "Backtick opens the developer tuner")
		_check(player.is_gameplay_input_blocked(), "Open tuner blocks gameplay polling")
		if visual_capture:
			for _frame in 12:
				await process_frame
		var profile := player.active_viewmodel_profile
		var original_x := profile.hip_position.x
		var adjustment_event := InputEventKey.new()
		tuner.selected_field = 0
		tuner.call(&"_adjust_selected", 1.0, adjustment_event)
		_check(is_equal_approx(profile.hip_position.x, original_x + 0.01), "Live position adjustment uses normal increment")
		_check(is_equal_approx(player.weapon_root.position.x, profile.hip_position.x), "Live adjustment updates WeaponRoot immediately")
		tuner.call(&"_reset_current_state")
		_check(is_equal_approx(profile.hip_position.x, original_x), "Current state reset restores saved/default value")
		tuner.increment_index = 0
		tuner.call(&"_adjust_selected", 1.0, adjustment_event)
		_check(is_equal_approx(profile.hip_position.x, original_x + 0.001), "Fine position increment is available")
		tuner.call(&"_reset_current_state")
		tuner.increment_index = 2
		tuner.call(&"_adjust_selected", 1.0, adjustment_event)
		_check(is_equal_approx(profile.hip_position.x, original_x + 0.10), "Coarse position increment is available")
		tuner.call(&"_reset_current_state")
		tuner.increment_index = 1
		tuner.call(&"_input", _pressed_key(KEY_3))
		_check(tuner.tuning_state == &"sprint", "Number 3 selects Sprint tuning")
		tuner.selected_field = 6
		var original_sprint_fov := profile.sprint_viewmodel_fov
		tuner.call(&"_adjust_selected", 1.0, adjustment_event)
		_check(is_equal_approx(profile.sprint_viewmodel_fov, original_sprint_fov + 1.0), "Sprint has an independently tunable FOV")
		_check(is_equal_approx(player.viewmodel_camera.fov, profile.sprint_viewmodel_fov), "Sprint preview updates viewmodel FOV immediately")
		tuner.call(&"_reset_current_state")
		_check(profile.reusable_configuration_text().contains("sprint_viewmodel_fov"), "Reusable output contains all presentation states")
		tuner.close()
		_check(not player.is_gameplay_input_blocked(), "Closing tuner restores gameplay polling")

	var ak_data := ZombieTownWeaponCatalog.load_weapon(&"ak74u")
	_check(ak_data != null and player.equip_weapon(ak_data), "AK equips through normal inventory path")
	await process_frame
	await process_frame
	_check(player.weapon != null and player.weapon.id == &"ak74u", "AK is the active weapon")
	_check(player.active_viewmodel_profile != null and player.active_viewmodel_profile.use_advanced_motion, "AK retains advanced presentation profile")
	_check(player.active_viewmodel_profile_path.ends_with("ak47_viewmodel.tres"), "AK saves to its explicitly linked approved profile")
	_check(_has_visible_mesh(player.first_person_viewmodel), "AK production mesh is instantiated")
	_check(player.first_person_viewmodel.current_weapon_id == &"ak74u", "Production viewmodel reports AK")
	if visual_capture:
		for _frame in 12:
			await process_frame

	if player.viewmodel_tuner != null:
		var tuner := player.viewmodel_tuner
		tuner.call(&"_input", _pressed_key(KEY_QUOTELEFT))
		tuner.call(&"_input", _pressed_key(KEY_2))
		_check(tuner.tuning_state == &"ads", "Number 2 selects ADS tuning")
		if visual_capture:
			for _frame in 12:
				await process_frame
		var profile := player.active_viewmodel_profile
		var aligned_position := profile.resolved_ads_position()
		var adjustment_event := InputEventKey.new()
		tuner.selected_field = 4
		tuner.call(&"_adjust_selected", 1.0, adjustment_event)
		_check(not profile.align_ads_to_sight, "Editing ADS transform converts auto alignment to an editable manual pose")
		_check(profile.ads_position.is_equal_approx(aligned_position), "ADS conversion preserves the approved screen position")
		tuner.close()

	var temporary_save_path := "user://viewmodel_tuner_smoke_profile.tres"
	var save_result := player.save_active_viewmodel_profile(temporary_save_path)
	_check(save_result == OK, "Profile Save function serializes a reusable resource")
	var saved_profile := ResourceLoader.load(temporary_save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as WeaponViewmodelProfile
	_check(saved_profile != null and saved_profile.model_scene != null, "Saved profile preserves model configuration")
	var absolute_temporary_save_path := ProjectSettings.globalize_path(temporary_save_path)
	if FileAccess.file_exists(absolute_temporary_save_path):
		DirAccess.remove_absolute(absolute_temporary_save_path)

	player.queue_free()
	await process_frame
	_finish()


func _has_visible_mesh(viewmodel: ZombieTownWeaponViewmodel) -> bool:
	if viewmodel == null:
		return false
	return _node_has_visible_mesh(viewmodel.model_root)


func _pressed_key(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _node_has_visible_mesh(node: Node) -> bool:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.visible and mesh_instance.mesh != null:
			return true
	for child: Node in node.get_children():
		if _node_has_visible_mesh(child):
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
		print("VIEWMODEL_TUNER_SMOKE_TEST: PASS")
		quit(0)
		return
	print("VIEWMODEL_TUNER_SMOKE_TEST: FAIL (%d)" % failures.size())
	quit(1)
