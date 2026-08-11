class_name ZombieTownInventoryPlayer
extends ZombieTownPresentationTunedPlayer

signal weapon_slots_changed(summary: String)

var weapon_slots: Array[Dictionary] = []
var active_weapon_slot := 0
var max_weapon_slots := 2
var inventory_ready := false
var double_points_active := false
var insta_kill_active := false

func _ready() -> void:
	super._ready()
	if weapon != null:
		weapon_slots.append(_make_slot(weapon, ammo, reserve_ammo, 0))
	inventory_ready = true
	_emit_weapon_slots_changed()

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if not alive or not inventory_ready:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				switch_weapon_slot(0)
			KEY_2:
				switch_weapon_slot(1)
			KEY_3:
				switch_weapon_slot(2)
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_weapon(1)
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_LEFT:
			cycle_weapon(-1)
		elif event.button_index == JOY_BUTTON_DPAD_RIGHT:
			cycle_weapon(1)

func equip_weapon(new_weapon: WeaponData) -> bool:
	if new_weapon == null:
		return false
	if not inventory_ready:
		return super.equip_weapon(new_weapon)

	var existing_index: int = get_weapon_slot_index(new_weapon.id)
	if existing_index >= 0:
		return switch_weapon_slot(existing_index)

	_save_active_slot()
	var runtime_weapon: WeaponData = new_weapon.duplicate(true) as WeaponData
	if runtime_weapon == null:
		return false

	var target_slot: int = active_weapon_slot
	if weapon_slots.size() < max_weapon_slots:
		target_slot = weapon_slots.size()
		weapon_slots.append(_make_slot(runtime_weapon, runtime_weapon.magazine_size, runtime_weapon.reserve_ammo, 0))
	else:
		weapon_slots[target_slot] = _make_slot(runtime_weapon, runtime_weapon.magazine_size, runtime_weapon.reserve_ammo, 0)

	active_weapon_slot = target_slot
	_load_active_slot()
	return true

func switch_weapon_slot(slot_index: int) -> bool:
	if not inventory_ready or slot_index < 0 or slot_index >= weapon_slots.size():
		return false
	if slot_index == active_weapon_slot:
		return true
	_save_active_slot()
	active_weapon_slot = slot_index
	_load_active_slot()
	return true

func cycle_weapon(direction: int) -> void:
	if weapon_slots.size() <= 1:
		return
	var step: int = 1 if direction >= 0 else -1
	var next_slot: int = (active_weapon_slot + step + weapon_slots.size()) % weapon_slots.size()
	switch_weapon_slot(next_slot)

func unlock_third_weapon_slot() -> void:
	if max_weapon_slots >= 3:
		return
	max_weapon_slots = 3
	_emit_weapon_slots_changed()

func set_double_points_active(enabled: bool) -> void:
	double_points_active = enabled

func set_insta_kill_active(enabled: bool) -> void:
	insta_kill_active = enabled

func get_point_multiplier() -> int:
	return 2 if double_points_active else 1

func is_insta_kill_active() -> bool:
	return insta_kill_active

func award_points(base_amount: int) -> void:
	if base_amount <= 0:
		return
	points += base_amount * get_point_multiplier()
	stats_changed.emit(points, kills, headshots)

func refill_all_weapon_ammo() -> void:
	if weapon_slots.is_empty():
		return
	_save_active_slot()
	for index in weapon_slots.size():
		var slot: Dictionary = weapon_slots[index]
		var weapon_variant: Variant = slot.get("weapon")
		if not weapon_variant is WeaponData:
			continue
		var slot_weapon: WeaponData = weapon_variant
		slot["reserve"] = slot_weapon.reserve_ammo
		weapon_slots[index] = slot
	if active_weapon_slot >= 0 and active_weapon_slot < weapon_slots.size():
		var active_slot: Dictionary = weapon_slots[active_weapon_slot]
		var active_weapon_variant: Variant = active_slot.get("weapon")
		if active_weapon_variant is WeaponData:
			var active_slot_weapon: WeaponData = active_weapon_variant
			reserve_ammo = active_slot_weapon.reserve_ammo
			ammo_changed.emit(ammo, reserve_ammo, reloading)
	_emit_weapon_slots_changed()

func get_weapon_slot_index(weapon_id: StringName) -> int:
	for index in weapon_slots.size():
		var slot: Dictionary = weapon_slots[index]
		var weapon_variant: Variant = slot.get("weapon")
		if weapon_variant is WeaponData:
			var slot_weapon: WeaponData = weapon_variant
			if slot_weapon.id == weapon_id:
				return index
	return -1

func owns_weapon(weapon_id: StringName) -> bool:
	return get_weapon_slot_index(weapon_id) >= 0

func get_held_weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for slot: Dictionary in weapon_slots:
		var weapon_variant: Variant = slot.get("weapon")
		if weapon_variant is WeaponData:
			var slot_weapon: WeaponData = weapon_variant
			ids.append(slot_weapon.id)
	return ids

func get_weapon_resources() -> Array[WeaponData]:
	var weapons: Array[WeaponData] = []
	for slot: Dictionary in weapon_slots:
		var weapon_variant: Variant = slot.get("weapon")
		if weapon_variant is WeaponData:
			weapons.append(weapon_variant as WeaponData)
	return weapons

func is_weapon_reserve_full(weapon_id: StringName) -> bool:
	var index: int = get_weapon_slot_index(weapon_id)
	if index < 0:
		return false
	if index == active_weapon_slot:
		_save_active_slot()
	var slot: Dictionary = weapon_slots[index]
	var weapon_variant: Variant = slot.get("weapon")
	var reserve_variant: Variant = slot.get("reserve", 0)
	if not weapon_variant is WeaponData:
		return false
	var slot_weapon: WeaponData = weapon_variant
	return int(reserve_variant) >= slot_weapon.reserve_ammo

func refill_weapon_reserve(weapon_id: StringName) -> bool:
	var index: int = get_weapon_slot_index(weapon_id)
	if index < 0:
		return false
	if index == active_weapon_slot:
		_save_active_slot()
	var slot: Dictionary = weapon_slots[index]
	var weapon_variant: Variant = slot.get("weapon")
	if not weapon_variant is WeaponData:
		return false
	var slot_weapon: WeaponData = weapon_variant
	slot["reserve"] = slot_weapon.reserve_ammo
	weapon_slots[index] = slot
	if index == active_weapon_slot:
		reserve_ammo = slot_weapon.reserve_ammo
		ammo_changed.emit(ammo, reserve_ammo, reloading)
	_emit_weapon_slots_changed()
	return true

func get_active_pack_level() -> int:
	if active_weapon_slot < 0 or active_weapon_slot >= weapon_slots.size():
		return 0
	var slot: Dictionary = weapon_slots[active_weapon_slot]
	return int(slot.get("pack_level", 0))

func set_active_pack_level(level: int) -> void:
	if active_weapon_slot < 0 or active_weapon_slot >= weapon_slots.size():
		return
	var slot: Dictionary = weapon_slots[active_weapon_slot]
	slot["pack_level"] = maxi(level, 0)
	weapon_slots[active_weapon_slot] = slot
	_emit_weapon_slots_changed()

func weapon_slot_summary() -> String:
	var parts: Array[String] = []
	for index in max_weapon_slots:
		var label: String = "EMPTY"
		if index < weapon_slots.size():
			var slot: Dictionary = weapon_slots[index]
			var weapon_variant: Variant = slot.get("weapon")
			if weapon_variant is WeaponData:
				var slot_weapon: WeaponData = weapon_variant
				label = slot_weapon.display_name.to_upper()
		var marker: String = ">" if index == active_weapon_slot and index < weapon_slots.size() else ""
		parts.append("%s%d:%s" % [marker, index + 1, label])
	return "   ".join(parts)

func _make_slot(slot_weapon: WeaponData, current_ammo: int, current_reserve: int, pack_level: int) -> Dictionary:
	return {
		"weapon": slot_weapon,
		"ammo": current_ammo,
		"reserve": current_reserve,
		"pack_level": pack_level
	}

func _save_active_slot() -> void:
	if not inventory_ready or weapon == null or active_weapon_slot < 0 or active_weapon_slot >= weapon_slots.size():
		return
	var slot: Dictionary = weapon_slots[active_weapon_slot]
	slot["weapon"] = weapon
	slot["ammo"] = ammo
	slot["reserve"] = reserve_ammo
	weapon_slots[active_weapon_slot] = slot

func _load_active_slot() -> void:
	if active_weapon_slot < 0 or active_weapon_slot >= weapon_slots.size():
		return
	var slot: Dictionary = weapon_slots[active_weapon_slot]
	var weapon_variant: Variant = slot.get("weapon")
	if not weapon_variant is WeaponData:
		return
	weapon = weapon_variant as WeaponData
	ammo = int(slot.get("ammo", weapon.magazine_size))
	reserve_ammo = int(slot.get("reserve", weapon.reserve_ammo))
	reloading = false
	reload_remaining = 0.0
	next_fire_time = 0.0
	weapon_kick = 0.0
	burst_remaining = 0
	_update_weapon_visual()
	ammo_changed.emit(ammo, reserve_ammo, false)
	weapon_changed.emit(weapon.display_name, weapon.id)
	_emit_weapon_slots_changed()

func _emit_weapon_slots_changed() -> void:
	weapon_slots_changed.emit(weapon_slot_summary())
