class_name ZombieTownAdvancedPlayer
extends ZombieTownPlayer

@onready var first_person_viewmodel: ZombieTownWeaponViewmodel = $Head/Camera3D/WeaponRoot/Viewmodel

var burst_remaining := 0
var burst_next_time := 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_burst_fire()

func _fire() -> void:
	if weapon == null:
		return
	if weapon.fire_mode == &"burst":
		_start_burst()
		return
	if _uses_advanced_effect(weapon):
		var now := float(Time.get_ticks_msec()) / 1000.0
		if now < next_fire_time:
			return
		if _fire_advanced_round():
			next_fire_time = now + weapon.fire_interval
		return
	var ammo_before := ammo
	super._fire()
	if ammo < ammo_before:
		_animate_viewmodel_fire()

func _begin_reload() -> void:
	var was_reloading := reloading
	super._begin_reload()
	if not was_reloading and reloading and weapon != null and first_person_viewmodel != null:
		first_person_viewmodel.animate_reload(weapon.reload_time, weapon.shell_reload)

func _start_burst() -> void:
	if weapon == null or burst_remaining > 0:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now < next_fire_time:
		return
	if not _fire_advanced_round():
		return
	burst_remaining = mini(maxi(weapon.burst_count - 1, 0), ammo)
	burst_next_time = now + weapon.burst_interval
	next_fire_time = now + weapon.fire_interval

func _update_burst_fire() -> void:
	if burst_remaining <= 0 or weapon == null or not alive:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now < burst_next_time:
		return
	if ammo <= 0:
		burst_remaining = 0
		_begin_reload()
		return
	if not _fire_advanced_round():
		burst_remaining = 0
		return
	burst_remaining -= 1
	burst_next_time = now + weapon.burst_interval

func _fire_advanced_round() -> bool:
	if weapon == null:
		return false
	if reloading:
		if weapon.shell_reload and ammo > 0:
			reloading = false
			ammo_changed.emit(ammo, reserve_ammo, false)
		else:
			return false
	if ammo <= 0:
		_begin_reload()
		return false

	ammo -= 1
	_animate_viewmodel_fire()
	weapon_kick = minf(weapon_kick + _kick_for_weapon(), 1.55)
	look_pitch = clampf(look_pitch - deg_to_rad(weapon.recoil_pitch), deg_to_rad(-85.0), deg_to_rad(85.0))
	head.rotation.x = look_pitch
	rotate_y(deg_to_rad(randf_range(-weapon.recoil_yaw, weapon.recoil_yaw)))
	muzzle_flash.visible = true
	muzzle_flash_remaining = 0.055
	ammo_changed.emit(ammo, reserve_ammo, reloading)

	var origin := camera.global_position
	var direction := _shot_direction()
	if not weapon.projectile_type.is_empty():
		_spawn_projectile(origin + direction * 0.55, direction)
	elif weapon.chain_count > 0:
		_fire_chain(origin, direction)
	elif weapon.cone_range > 0.0:
		_fire_cone(origin, direction)
	else:
		var pellet_count := maxi(1, weapon.pellets)
		for _pellet_index in pellet_count:
			_trace_shot(origin, _shot_direction())
	return true

func _animate_viewmodel_fire() -> void:
	if first_person_viewmodel != null:
		first_person_viewmodel.animate_fire()

func _uses_advanced_effect(data: WeaponData) -> bool:
	return data.fire_mode == &"burst" or not data.projectile_type.is_empty() or data.chain_count > 0 or data.cone_range > 0.0

func _kick_for_weapon() -> float:
	if weapon == null:
		return 0.75
	match weapon.weapon_class:
		&"shotgun":
			return 0.95
		&"sniper":
			return 1.15
		&"wonder":
			return 0.88
		&"lmg":
			return 0.72
		_:
			return 0.75

func _trace_shot(origin: Vector3, direction: Vector3) -> void:
	if weapon == null:
		return
	var current_origin := origin
	var remaining_range := weapon.range
	var excluded: Array[RID] = [get_rid()]
	var max_hits := maxi(1, weapon.pierce)

	for _hit_index in max_hits:
		if remaining_range <= 0.05:
			break
		var query := PhysicsRayQueryParameters3D.create(current_origin, current_origin + direction * remaining_range)
		query.exclude = excluded
		var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			break
		var collider_variant: Variant = result.get("collider")
		var hit_position_variant: Variant = result.get("position")
		if not hit_position_variant is Vector3:
			break
		var hit_position: Vector3 = hit_position_variant
		if not collider_variant is ZombieTownZombie:
			break
		var zombie := collider_variant as ZombieTownZombie
		if not zombie.alive:
			break
		var headshot := zombie.is_headshot_point(hit_position)
		var shot_damage := weapon.damage * (weapon.headshot_multiplier if headshot else 1.0)
		apply_weapon_damage(zombie, shot_damage, headshot)
		excluded.append(zombie.get_rid())
		var traveled_segment := current_origin.distance_to(hit_position)
		remaining_range -= traveled_segment
		current_origin = hit_position + direction * 0.05

func apply_weapon_damage(zombie: ZombieTownZombie, amount: float, headshot: bool) -> void:
	if zombie == null or not is_instance_valid(zombie) or not zombie.alive:
		return
	var outcome: Dictionary = zombie.take_damage(amount, headshot, self)
	points += 10
	var killed := bool(outcome.get("killed", false))
	if killed:
		kills += 1
		if headshot:
			headshots += 1
		points += 90 if headshot else 50
	stats_changed.emit(points, kills, headshots)
	hit_confirmed.emit(killed, headshot)

func _spawn_projectile(origin: Vector3, direction: Vector3) -> void:
	if weapon == null:
		return
	var projectile := ZombieTownWeaponProjectile.new()
	get_tree().current_scene.add_child(projectile)
	projectile.configure(self, origin, direction, weapon, _projectile_color(weapon.projectile_type))

func _projectile_color(projectile_type: StringName) -> Color:
	match projectile_type:
		&"ray":
			return Color(0.20, 1.0, 0.36, 1.0)
		&"ray2":
			return Color(0.20, 0.72, 1.0, 1.0)
		&"flare":
			return Color(1.0, 0.22, 0.06, 1.0)
		&"nade":
			return Color(1.0, 0.62, 0.12, 1.0)
		_:
			return Color(0.55, 0.82, 1.0, 1.0)

func _fire_chain(origin: Vector3, direction: Vector3) -> void:
	if weapon == null:
		return
	var first := _first_zombie_on_ray(origin, direction, weapon.range)
	if first == null:
		_spawn_beam(origin, origin + direction * minf(weapon.range, 16.0), Color(0.34, 0.78, 1.0, 1.0))
		return

	var hit_zombies: Array[ZombieTownZombie] = []
	var current := first
	var beam_start := origin
	for _chain_index in maxi(1, weapon.chain_count):
		if current == null or not is_instance_valid(current) or not current.alive:
			break
		var target_point := current.global_position + Vector3(0.0, 1.05, 0.0)
		_spawn_beam(beam_start, target_point, Color(0.34, 0.78, 1.0, 1.0))
		apply_weapon_damage(current, weapon.damage, false)
		hit_zombies.append(current)
		beam_start = target_point
		current = _nearest_chain_target(target_point, hit_zombies, weapon.chain_radius)

func _first_zombie_on_ray(origin: Vector3, direction: Vector3, ray_range: float) -> ZombieTownZombie:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * ray_range)
	query.exclude = [get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var collider_variant: Variant = result.get("collider")
	if collider_variant is ZombieTownZombie:
		return collider_variant as ZombieTownZombie
	return null

func _nearest_chain_target(from_position: Vector3, excluded: Array[ZombieTownZombie], radius: float) -> ZombieTownZombie:
	var best: ZombieTownZombie
	var best_distance := radius
	for node: Node in get_tree().get_nodes_in_group(&"zombie"):
		if not node is ZombieTownZombie:
			continue
		var zombie := node as ZombieTownZombie
		if zombie in excluded or not zombie.alive:
			continue
		var distance := zombie.global_position.distance_to(from_position)
		if distance <= best_distance:
			best_distance = distance
			best = zombie
	return best

func _fire_cone(origin: Vector3, direction: Vector3) -> void:
	if weapon == null:
		return
	var forward := direction.normalized()
	var min_dot := cos(weapon.cone_angle)
	for node: Node in get_tree().get_nodes_in_group(&"zombie"):
		if not node is ZombieTownZombie:
			continue
		var zombie := node as ZombieTownZombie
		if not zombie.alive:
			continue
		var offset := zombie.global_position + Vector3(0.0, 0.9, 0.0) - origin
		var distance := offset.length()
		if distance <= 0.01 or distance > weapon.cone_range:
			continue
		if forward.dot(offset / distance) < min_dot:
			continue
		apply_weapon_damage(zombie, maxf(zombie.max_health * 10.0, 10000.0), false)
	_spawn_cone_flash(origin, forward)

func _spawn_beam(from_position: Vector3, to_position: Vector3, color: Color) -> void:
	var immediate := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 5.0
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate.surface_add_vertex(from_position)
	immediate.surface_add_vertex(to_position)
	immediate.surface_end()
	var visual := MeshInstance3D.new()
	visual.mesh = immediate
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(visual)
	var tween := visual.create_tween()
	tween.tween_interval(0.09)
	tween.tween_property(visual, "transparency", 1.0, 0.10)
	tween.tween_callback(visual.queue_free)

func _spawn_cone_flash(origin: Vector3, direction: Vector3) -> void:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.48
	mesh.height = 0.96
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.55, 0.82, 1.0, 0.32)
	material.emission_enabled = true
	material.emission = Color(0.42, 0.72, 1.0, 1.0)
	material.emission_energy_multiplier = 4.0
	mesh.material = material
	visual.mesh = mesh
	get_tree().current_scene.add_child(visual)
	visual.global_position = origin + direction * 1.2
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", Vector3(9.0, 5.0, 15.0), 0.18)
	tween.parallel().tween_property(visual, "transparency", 1.0, 0.18)
	tween.tween_callback(visual.queue_free)

func _update_weapon_visual() -> void:
	super._update_weapon_visual()
	if weapon == null:
		return
	match weapon.weapon_class:
		&"lmg":
			weapon_body.scale = Vector3(1.45, 1.05, 2.7)
			weapon_grip.scale = Vector3(1.1, 1.28, 1.1)
			hip_weapon_position = Vector3(0.29, -0.23, -0.70)
			ads_weapon_position = Vector3(0.0, -0.16, -0.64)
		&"sniper":
			weapon_body.scale = Vector3(1.25, 0.82, 3.0)
			weapon_grip.scale = Vector3(1.0, 1.15, 1.0)
			hip_weapon_position = Vector3(0.27, -0.21, -0.72)
			ads_weapon_position = Vector3(0.0, -0.145, -0.66)
		&"wonder":
			weapon_body.scale = Vector3(1.45, 1.22, 1.7)
			weapon_grip.scale = Vector3(1.15, 1.18, 1.15)
			hip_weapon_position = Vector3(0.27, -0.22, -0.60)
			ads_weapon_position = Vector3(0.0, -0.16, -0.55)
	weapon_root.position = hip_weapon_position
	if first_person_viewmodel != null:
		first_person_viewmodel.set_weapon(weapon)
		muzzle_flash.position = first_person_viewmodel.muzzle_position_for(weapon)
