extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _validate_preview_reuse(ZombieTownMysteryBox.new(), ZombieTownMysteryBox.CYCLE_POOL, "base")
	await _validate_preview_reuse(ZombieTownGameplayMysteryBox.new(), ZombieTownGameplayMysteryBox.GAMEPLAY_CYCLE_POOL, "gameplay")
	if failures.is_empty():
		print("MYSTERY_BOX_PREVIEW_PERFORMANCE_TEST: PASS")
		quit(0)
		return
	print("MYSTERY_BOX_PREVIEW_PERFORMANCE_TEST: FAIL (%d)" % failures.size())
	quit(1)


func _validate_preview_reuse(box: ZombieTownMysteryBox, cycle_pool: Array[StringName], label: String) -> void:
	root.add_child(box)
	await process_frame
	var original_mesh := box.weapon_preview.mesh
	var allowed_material_ids: Array[int] = [
		box.standard_preview_material.get_instance_id(),
		box.wonder_preview_material.get_instance_id(),
	]
	var warmed_cache_size := box.preview_weapon_data_cache.size()
	for cycle_number: int in 20:
		for weapon_id: StringName in cycle_pool:
			box.call(&"_show_weapon", weapon_id)
			_check(box.weapon_preview.mesh == original_mesh, "%s Box reuses one preview mesh" % label)
			var material := (box.weapon_preview.mesh as BoxMesh).material
			_check(material != null and material.get_instance_id() in allowed_material_ids, "%s Box reuses cached preview materials" % label)
	_check(box.preview_weapon_data_cache.size() == warmed_cache_size, "%s Box performs no new WeaponData loads after warmup" % label)
	box.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		return
	failures.append(description)
	push_error("FAIL: %s" % description)
