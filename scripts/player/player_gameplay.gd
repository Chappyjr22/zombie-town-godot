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
	if is_insta_kill_active() and not zombie.insta_kill_immune:
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
	if is_insta_kill_active() and not zombie.insta_kill_immune:
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

func _fire_cone(origin: Vector3, direction: Vector3) -> void:
	if weapon == null:
		return
	var forward: Vector3 = direction.normalized()
	var min_dot: float = cos(weapon.cone_angle)
	for node: Node in get_tree().get_nodes_in_group(&"zombie"):
		if not node is ZombieTownZombie:
			continue
		var zombie: ZombieTownZombie = node as ZombieTownZombie
		if not zombie.alive:
			continue
		var offset: Vector3 = zombie.global_position + Vector3(0.0, 0.9, 0.0) - origin
		var distance: float = offset.length()
		if distance <= 0.01 or distance > weapon.cone_range:
			continue
		if forward.dot(offset / distance) < min_dot:
			continue
		var cone_damage: float = maxf(zombie.max_health * 10.0, 10000.0)
		if zombie.thundergun_immune:
			cone_damage = maxf(zombie.max_health * 0.08, 450.0)
		apply_weapon_damage(zombie, cone_damage, false)
	_spawn_cone_flash(origin, forward)

func _melee_is_attacking() -> bool:
	var melee_node: Node = get_node_or_null("Melee")
	if melee_node == null or not melee_node.has_method("is_attacking"):
		return false
	return bool(melee_node.call("is_attacking"))
