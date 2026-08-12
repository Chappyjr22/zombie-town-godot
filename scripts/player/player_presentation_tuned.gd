class_name ZombieTownPresentationTunedPlayer
extends ZombieTownAdvancedPlayer

const DEFAULT_VIEWMODEL_FOV := 75.0

var viewmodel_viewport: SubViewport
var viewmodel_camera: Camera3D
var viewmodel_world_root: Node3D
var viewmodel_overlay_layer: CanvasLayer
var viewmodel_overlay: TextureRect

var hip_weapon_rotation := Vector3.ZERO
var ads_weapon_rotation := Vector3.ZERO
var viewmodel_hip_fov := DEFAULT_VIEWMODEL_FOV
var viewmodel_ads_fov := DEFAULT_VIEWMODEL_FOV
var active_viewmodel_profile: WeaponViewmodelProfile

var look_lag_rotation := Vector3.ZERO
var look_lag_position := Vector3.ZERO
var bob_position := Vector3.ZERO
var bob_rotation := Vector3.ZERO
var visual_recoil_position := Vector3.ZERO
var visual_recoil_rotation := Vector3.ZERO
var bob_phase := 0.0
var idle_time := 0.0
var last_player_yaw := 0.0
var last_look_pitch := 0.0
var viewmodel_renderer_ready := false


func _ready() -> void:
	super._ready()
	_setup_viewmodel_renderer()
	_reset_viewmodel_motion()


func _setup_viewmodel_renderer() -> void:
	if viewmodel_renderer_ready:
		return
	var root_viewport := get_viewport()
	if root_viewport == null:
		return

	viewmodel_viewport = SubViewport.new()
	viewmodel_viewport.name = "ViewmodelViewport"
	viewmodel_viewport.transparent_bg = true
	viewmodel_viewport.own_world_3d = true
	viewmodel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewmodel_viewport)

	viewmodel_world_root = Node3D.new()
	viewmodel_world_root.name = "ViewmodelWorld"
	viewmodel_viewport.add_child(viewmodel_world_root)

	viewmodel_camera = Camera3D.new()
	viewmodel_camera.name = "ViewmodelCamera"
	viewmodel_camera.current = true
	viewmodel_camera.fov = DEFAULT_VIEWMODEL_FOV
	viewmodel_camera.near = 0.01
	viewmodel_camera.far = 6.0
	viewmodel_world_root.add_child(viewmodel_camera)

	var key_light := DirectionalLight3D.new()
	key_light.name = "ViewmodelKeyLight"
	key_light.rotation_degrees = Vector3(-24.0, -32.0, 0.0)
	key_light.light_color = Color(1.0, 0.94, 0.86, 1.0)
	key_light.light_energy = 1.65
	key_light.shadow_enabled = false
	viewmodel_world_root.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "ViewmodelFillLight"
	fill_light.rotation_degrees = Vector3(28.0, 145.0, 0.0)
	fill_light.light_color = Color(0.55, 0.65, 0.82, 1.0)
	fill_light.light_energy = 0.72
	fill_light.shadow_enabled = false
	viewmodel_world_root.add_child(fill_light)

	var old_parent := weapon_root.get_parent()
	if old_parent != null:
		old_parent.remove_child(weapon_root)
	viewmodel_world_root.add_child(weapon_root)

	viewmodel_overlay_layer = CanvasLayer.new()
	viewmodel_overlay_layer.name = "ViewmodelOverlayLayer"
	viewmodel_overlay_layer.layer = 0
	add_child(viewmodel_overlay_layer)

	viewmodel_overlay = TextureRect.new()
	viewmodel_overlay.name = "ViewmodelOverlay"
	viewmodel_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewmodel_overlay.texture = viewmodel_viewport.get_texture()
	viewmodel_overlay.position = Vector2.ZERO
	viewmodel_overlay_layer.add_child(viewmodel_overlay)

	_sync_viewmodel_viewport_size()
	viewmodel_renderer_ready = true


func _sync_viewmodel_viewport_size() -> void:
	if viewmodel_viewport == null or viewmodel_overlay == null:
		return
	var visible_size: Vector2 = get_viewport().get_visible_rect().size
	var desired_size := Vector2i(
		maxi(2, int(round(visible_size.x))),
		maxi(2, int(round(visible_size.y)))
	)
	if viewmodel_viewport.size != desired_size:
		viewmodel_viewport.size = desired_size
	var overlay_size := Vector2(float(desired_size.x), float(desired_size.y))
	if viewmodel_overlay.size != overlay_size:
		viewmodel_overlay.size = overlay_size


func _update_weapon_visual() -> void:
	super._update_weapon_visual()
	if weapon == null:
		return

	hip_weapon_rotation = Vector3.ZERO
	ads_weapon_rotation = Vector3.ZERO
	viewmodel_hip_fov = DEFAULT_VIEWMODEL_FOV
	viewmodel_ads_fov = DEFAULT_VIEWMODEL_FOV
	active_viewmodel_profile = weapon.viewmodel_profile

	match weapon.weapon_class:
		&"pistol":
			hip_weapon_position = Vector3(0.285, -0.235, -0.57)
		&"knife":
			hip_weapon_position = Vector3(0.285, -0.230, -0.54)
			ads_weapon_position = Vector3(0.0, -0.155, -0.50)
		&"smg":
			hip_weapon_position = Vector3(0.285, -0.225, -0.61)
		&"rifle":
			hip_weapon_position = Vector3(0.305, -0.235, -0.68)
		&"shotgun":
			hip_weapon_position = Vector3(0.315, -0.245, -0.70)
		&"lmg":
			hip_weapon_position = Vector3(0.335, -0.265, -0.74)
		&"sniper":
			hip_weapon_position = Vector3(0.315, -0.245, -0.76)
		&"wonder":
			hip_weapon_position = Vector3(0.305, -0.250, -0.64)

	if active_viewmodel_profile != null:
		hip_weapon_position = active_viewmodel_profile.hip_position
		hip_weapon_rotation = active_viewmodel_profile.hip_rotation_radians()
		ads_weapon_position = active_viewmodel_profile.resolved_ads_position()
		ads_weapon_rotation = active_viewmodel_profile.ads_rotation_radians()
		viewmodel_hip_fov = active_viewmodel_profile.hip_viewmodel_fov
		viewmodel_ads_fov = active_viewmodel_profile.ads_viewmodel_fov
	else:
		match weapon.id:
			&"raygun":
				ads_weapon_position = Vector3(0.0, -0.245, -0.60)
			&"raygun2":
				ads_weapon_position = Vector3(0.0, -0.245, -0.63)
			_:
				pass

	weapon_root.position = hip_weapon_position
	weapon_root.rotation = hip_weapon_rotation
	if viewmodel_camera != null:
		viewmodel_camera.fov = viewmodel_hip_fov
	_reset_viewmodel_motion()


func _update_camera_and_weapon(delta: float) -> void:
	if weapon == null:
		return

	var desired_height := CROUCH_CAMERA_HEIGHT if crouched else STANDING_CAMERA_HEIGHT
	head.position.y = move_toward(head.position.y, desired_height, delta * 4.2)

	var desired_world_fov := weapon.ads_fov if ads else weapon.hip_fov
	camera.fov = lerpf(camera.fov, desired_world_fov, 1.0 - exp(-delta * 11.0))

	_sync_viewmodel_viewport_size()
	weapon_kick = move_toward(weapon_kick, 0.0, delta * 1.8)

	if active_viewmodel_profile != null:
		_update_profile_viewmodel(delta, active_viewmodel_profile)
	else:
		_update_standard_viewmodel(delta)


func _update_standard_viewmodel(delta: float) -> void:
	var desired_position := ads_weapon_position if ads else hip_weapon_position
	desired_position.z += weapon_kick * 0.06
	var desired_rotation := Vector3(weapon_kick * 0.08, 0.0, 0.0)

	weapon_root.position = weapon_root.position.lerp(
		desired_position,
		1.0 - exp(-delta * 15.0)
	)
	weapon_root.rotation = _lerp_rotation(
		weapon_root.rotation,
		desired_rotation,
		1.0 - exp(-delta * 14.0)
	)

	if viewmodel_camera != null:
		var target_fov := viewmodel_ads_fov if ads else viewmodel_hip_fov
		viewmodel_camera.fov = lerpf(
			viewmodel_camera.fov,
			target_fov,
			1.0 - exp(-delta * 14.0)
		)


func _update_profile_viewmodel(delta: float, profile: WeaponViewmodelProfile) -> void:
	var move_input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and horizontal_speed > 0.12
	var sprinting := (
		not ads
		and not crouched
		and move_input.y < -0.1
		and Input.is_action_pressed(&"sprint")
		and horizontal_speed > walk_speed * 0.72
	)

	var current_yaw := rotation.y
	var yaw_step := wrapf(current_yaw - last_player_yaw, -PI, PI)
	var pitch_step := look_pitch - last_look_pitch
	last_player_yaw = current_yaw
	last_look_pitch = look_pitch

	var lag_weight := profile.ads_motion_scale if ads else 1.0
	var lag_limit := profile.look_lag_limit_radians()
	var target_lag_rotation := Vector3(
		clampf(-pitch_step * profile.look_lag_pitch, -lag_limit.x, lag_limit.x),
		clampf(-yaw_step * profile.look_lag_yaw, -lag_limit.y, lag_limit.y),
		clampf(yaw_step * profile.look_lag_roll, -lag_limit.z, lag_limit.z)
	) * lag_weight
	look_lag_rotation = look_lag_rotation.lerp(
		target_lag_rotation,
		1.0 - exp(-delta * 17.0)
	)

	var target_lag_position := Vector3(
		-look_lag_rotation.y * profile.look_lag_position_scale.x,
		look_lag_rotation.x * profile.look_lag_position_scale.y,
		0.0
	)
	look_lag_position = look_lag_position.lerp(
		target_lag_position,
		1.0 - exp(-delta * 18.0)
	)

	var target_bob_position := Vector3.ZERO
	var target_bob_rotation := Vector3.ZERO
	if moving:
		var speed_ratio := clampf(horizontal_speed / maxf(walk_speed, 0.01), 0.0, 1.55)
		var cadence := profile.sprint_bob_cadence if sprinting else profile.walk_bob_cadence
		bob_phase += delta * cadence * clampf(speed_ratio, 0.65, 1.45)
		var bob_weight := profile.ads_motion_scale if ads else 1.0
		bob_weight *= clampf(speed_ratio, 0.35, 1.25)
		target_bob_position = Vector3(
			sin(bob_phase) * profile.bob_position.x,
			cos(bob_phase * 2.0) * profile.bob_position.y,
			profile.bob_position.z
		) * bob_weight
		var bob_rotation_amount := profile.bob_rotation_radians()
		target_bob_rotation = Vector3(
			cos(bob_phase * 2.0) * bob_rotation_amount.x,
			sin(bob_phase) * bob_rotation_amount.y,
			sin(bob_phase) * bob_rotation_amount.z
		) * bob_weight

	bob_position = bob_position.lerp(
		target_bob_position,
		1.0 - exp(-delta * 14.0)
	)
	bob_rotation = bob_rotation.lerp(
		target_bob_rotation,
		1.0 - exp(-delta * 14.0)
	)

	idle_time += delta
	var idle_weight := 0.22 if moving else 1.0
	if ads:
		idle_weight *= profile.ads_motion_scale
	var idle_position := Vector3(
		sin(idle_time * 0.86) * profile.idle_position.x,
		sin(idle_time * 1.37) * profile.idle_position.y,
		profile.idle_position.z
	) * idle_weight
	var idle_rotation_amount := profile.idle_rotation_radians()
	var idle_rotation := Vector3(
		sin(idle_time * 1.11) * idle_rotation_amount.x,
		cos(idle_time * 0.73) * idle_rotation_amount.y,
		sin(idle_time * 0.91) * idle_rotation_amount.z
	) * idle_weight

	visual_recoil_position = visual_recoil_position.lerp(
		Vector3.ZERO,
		1.0 - exp(-delta * profile.recoil_position_recovery)
	)
	visual_recoil_rotation = visual_recoil_rotation.lerp(
		Vector3.ZERO,
		1.0 - exp(-delta * profile.recoil_rotation_recovery)
	)

	var desired_position := ads_weapon_position if ads else hip_weapon_position
	var desired_rotation := ads_weapon_rotation if ads else hip_weapon_rotation

	if sprinting:
		desired_position = profile.sprint_position
		desired_rotation = profile.sprint_rotation_radians()

	desired_position += look_lag_position
	desired_position += bob_position
	desired_position += idle_position
	desired_position += visual_recoil_position

	desired_rotation += look_lag_rotation
	desired_rotation += bob_rotation
	desired_rotation += idle_rotation
	desired_rotation += visual_recoil_rotation

	var position_response := profile.ads_position_response if ads else profile.hip_position_response
	var rotation_response := profile.ads_rotation_response if ads else profile.hip_rotation_response
	if sprinting:
		position_response = profile.sprint_position_response
		rotation_response = profile.sprint_rotation_response
	weapon_root.position = weapon_root.position.lerp(
		desired_position,
		1.0 - exp(-delta * position_response)
	)
	weapon_root.rotation = _lerp_rotation(
		weapon_root.rotation,
		desired_rotation,
		1.0 - exp(-delta * rotation_response)
	)

	if viewmodel_camera != null:
		var target_viewmodel_fov := viewmodel_ads_fov if ads else viewmodel_hip_fov
		if sprinting:
			target_viewmodel_fov = profile.sprint_viewmodel_fov
		viewmodel_camera.fov = lerpf(
			viewmodel_camera.fov,
			target_viewmodel_fov,
			1.0 - exp(-delta * profile.fov_response)
		)


func _animate_viewmodel_fire() -> void:
	super._animate_viewmodel_fire()
	if weapon == null or active_viewmodel_profile == null:
		return
	var profile := active_viewmodel_profile

	# Keep the existing mesh kick subtle and let the root spring provide the
	# heavier shoulder impulse so the whole gun and hands move together.
	if first_person_viewmodel != null:
		first_person_viewmodel.fire_kick = minf(
			first_person_viewmodel.fire_kick,
			profile.model_fire_kick_limit
		)

	visual_recoil_position += profile.recoil_position_impulse
	visual_recoil_position.x += randf_range(
		-profile.recoil_position_random_x,
		profile.recoil_position_random_x
	)
	visual_recoil_rotation += profile.recoil_rotation_impulse_radians()
	visual_recoil_rotation.y += deg_to_rad(randf_range(
		-profile.recoil_yaw_random_degrees,
		profile.recoil_yaw_random_degrees
	))
	visual_recoil_rotation.z += deg_to_rad(randf_range(
		-profile.recoil_roll_random_degrees,
		profile.recoil_roll_random_degrees
	))

	var position_limit := profile.recoil_position_limit
	visual_recoil_position.x = clampf(visual_recoil_position.x, -position_limit.x, position_limit.x)
	visual_recoil_position.y = clampf(visual_recoil_position.y, -position_limit.y, position_limit.y)
	visual_recoil_position.z = clampf(visual_recoil_position.z, 0.0, position_limit.z)
	var rotation_limit := profile.recoil_rotation_limit_radians()
	visual_recoil_rotation.x = clampf(visual_recoil_rotation.x, -rotation_limit.x, rotation_limit.x)
	visual_recoil_rotation.y = clampf(visual_recoil_rotation.y, -rotation_limit.y, rotation_limit.y)
	visual_recoil_rotation.z = clampf(visual_recoil_rotation.z, -rotation_limit.z, rotation_limit.z)


func _reset_viewmodel_motion() -> void:
	look_lag_rotation = Vector3.ZERO
	look_lag_position = Vector3.ZERO
	bob_position = Vector3.ZERO
	bob_rotation = Vector3.ZERO
	visual_recoil_position = Vector3.ZERO
	visual_recoil_rotation = Vector3.ZERO
	bob_phase = 0.0
	idle_time = 0.0
	last_player_yaw = rotation.y
	last_look_pitch = look_pitch


func _lerp_rotation(from_rotation: Vector3, to_rotation: Vector3, weight: float) -> Vector3:
	return Vector3(
		lerp_angle(from_rotation.x, to_rotation.x, weight),
		lerp_angle(from_rotation.y, to_rotation.y, weight),
		lerp_angle(from_rotation.z, to_rotation.z, weight)
	)
