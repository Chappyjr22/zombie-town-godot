class_name ZombieTownGameplayMysteryBox
extends ZombieTownMysteryBox

const GAMEPLAY_WEAPON_WEIGHTS := {
	&"m14": 12.0,
	&"olympia": 12.0,
	&"mp5": 12.0,
	&"ak74u": 12.0,
	&"galil": 12.0,
	&"rem870": 12.0,
	&"an94": 7.0,
	&"skorpion": 7.0,
	&"luger": 8.0,
	&"flaregun": 3.0,
	&"rpk": 6.0,
	&"hamr": 6.0,
	&"m1216": 6.0,
	&"dsr50": 5.0,
	&"bknife": 5.0,
	&"raygun": 2.08,
	&"raygun2": 2.08,
	&"warmachine": 1.89,
	&"thunder": 1.6793,
	&"waffe": 1.6793
}

const GAMEPLAY_CYCLE_POOL: Array[StringName] = [
	&"m14", &"olympia", &"mp5", &"ak74u", &"galil", &"rem870",
	&"an94", &"skorpion", &"luger", &"flaregun", &"rpk", &"hamr",
	&"m1216", &"dsr50", &"bknife", &"raygun", &"raygun2", &"warmachine", &"thunder", &"waffe"
]

func _update_roll(delta: float) -> void:
	roll_elapsed += delta
	cycle_elapsed += delta
	if lid_pivot != null:
		var lid_target := deg_to_rad(-82.0)
		lid_pivot.rotation.x = lerpf(lid_pivot.rotation.x, lid_target, 1.0 - exp(-delta * 11.0))
	if weapon_preview != null:
		weapon_preview.position.y = 1.88 + sin(roll_elapsed * 5.5) * 0.10
		weapon_preview.rotation.y += delta * 2.8
	if cycle_elapsed >= _current_cycle_interval():
		cycle_elapsed = 0.0
		cycle_index = (cycle_index + 1) % GAMEPLAY_CYCLE_POOL.size()
		_show_weapon(GAMEPLAY_CYCLE_POOL[cycle_index])
	if roll_elapsed >= ROLL_DURATION:
		_finish_roll()

func _choose_result() -> StringName:
	var total_weight := 0.0
	var weighted_ids: Array[StringName] = []
	var weighted_values: Array[float] = []
	var held_ids: Array[StringName] = []
	if rolling_player is ZombieTownInventoryPlayer:
		var inventory_player := rolling_player as ZombieTownInventoryPlayer
		held_ids = inventory_player.get_held_weapon_ids()
	elif rolling_player != null and rolling_player.weapon != null:
		held_ids.append(rolling_player.weapon.id)

	var pity_multiplier := minf(4.0, 1.0 + float(dry_streak) * 0.13)
	for weapon_variant: Variant in GAMEPLAY_WEAPON_WEIGHTS.keys():
		var weapon_id := StringName(str(weapon_variant))
		if weapon_id in held_ids:
			continue
		var weight_variant: Variant = GAMEPLAY_WEAPON_WEIGHTS.get(weapon_id, 0.0)
		var weight := float(weight_variant)
		if weapon_id in WONDER_WEAPONS:
			weight *= pity_multiplier
		weighted_ids.append(weapon_id)
		weighted_values.append(weight)
		total_weight += weight

	if weighted_ids.is_empty() or total_weight <= 0.0:
		return &"m14"
	var roll := randf() * total_weight
	for index in weighted_ids.size():
		roll -= weighted_values[index]
		if roll <= 0.0:
			return weighted_ids[index]
	return weighted_ids[weighted_ids.size() - 1]
