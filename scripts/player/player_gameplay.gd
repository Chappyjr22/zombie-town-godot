class_name ZombieTownGameplayPlayer
extends ZombieTownInventoryPlayer

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
