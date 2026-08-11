class_name ZombieTownGameplayPlayer
extends ZombieTownInventoryPlayer

func _fire() -> void:
	if _melee_is_attacking():
		return
	super._fire()

func _begin_reload() -> void:
	if _melee_is_attacking():
		return
	super._begin_reload()

func apply_weapon_damage(zombie: ZombieTownZombie, amount: float, headshot: bool) -> void:
	if zombie == null or not is_instance_valid(zombie) or not zombie.alive:
		return
	var resolved_damage := amount
	if is_insta_kill_active():
		resolved_damage = maxf(zombie.max_health * 20.0, 50000.0)
	var outcome: Dictionary = zombie.take_damage(resolved_damage, headshot, self)
	var multiplier := get_point_multiplier()
	points += 10 * multiplier
	var killed := bool(outcome.get("killed", false))
	if killed:
		kills += 1
		if headshot:
			headshots += 1
		points += (90 if headshot else 50) * multiplier
	stats_changed.emit(points, kills, headshots)
	hit_confirmed.emit(killed, headshot)

func apply_melee_damage(zombie: ZombieTownZombie, amount: float) -> void:
	if zombie == null or not is_instance_valid(zombie) or not zombie.alive:
		return
	var resolved_damage := amount
	if is_insta_kill_active():
		resolved_damage = maxf(zombie.max_health * 20.0, 50000.0)
	var outcome: Dictionary = zombie.take_damage(resolved_damage, false, self)
	var multiplier: int = get_point_multiplier()
	var killed: bool = bool(outcome.get("killed", false))
	if killed:
		kills += 1
		points += 130 * multiplier
	else:
		points += 10 * multiplier
	stats_changed.emit(points, kills, headshots)
	hit_confirmed.emit(killed, false)

func _melee_is_attacking() -> bool:
	var melee_node: Node = get_node_or_null("Melee")
	if melee_node == null or not melee_node.has_method("is_attacking"):
		return false
	return bool(melee_node.call("is_attacking"))
