class_name ZombieTownPresentationTunedPlayer
extends ZombieTownAdvancedPlayer

const DEFAULT_VIEWMODEL_FOV := 75.0
const AK_VIEWMODEL_HIP_FOV := 62.0
const AK_VIEWMODEL_ADS_FOV := 58.0
const AK_VIEWMODEL_SPRINT_FOV := 65.0

const AK_HIP_POSITION := Vector3(0.398, -0.298, -0.642)
const AK_HIP_ROTATION := Vector3(-0.03150, 0.10800, -0.05200)
const AK_SPRINT_POSITION_OFFSET := Vector3(0.105, -0.115, 0.055)
const AK_SPRINT_ROTATION_OFFSET := Vector3(0.13963, -0.17453, -0.20944)

var viewmodel_viewport: SubViewport
var viewmodel_camera: Camera3D
var viewmodel_world_root: Node3D
var viewmodel_overlay_layer: CanvasLayer
var viewmodel_overlay: TextureRect

var hip_weapon_rotation := Vector3.ZERO
var ads_weapon_rotation := Vector3.ZERO
var viewmodel_hip_fov := DEFAULT_VIEWMODEL_FOV
var viewmodel_ads_fov := DEFAULT_VIEWMODEL_FOV

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

	match weapon.id:
		&"ak74u":
			# The AK uses an authored transform and a narrower first-person lens.
			# Position alone cannot create the perspective or shoulder-mounted feel.
			hip_weapon_position = AK_HIP_POSITION
			hip_weapon_rotation = AK_HIP_ROTATION
			viewmodel_hip_fov = AK_VIEWMODEL_HIP_FOV
			viewmodel_ads_fov = AK_VIEWMODEL_ADS_FOV
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

	if weapon.id == &"ak74u":
		_update_ak_viewmodel(delta)
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


func _update_ak_viewmodel(delta: float) -> void:
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

	var lag_weight := 0.28 if ads else 1.0
	var target_lag_rotation := Vector3(
		clampf(-pitch_step * 6.0, -0.052, 0.052),
		clampf(-yaw_step * 7.5, -0.082, 0.082),
		clampf(yaw_step * 2.8, -0.032, 0.032)
	) * lag_weight
	look_lag_rotation = look_lag_rotation.lerp(
		target_lag_rotation,
		1.0 - exp(-delta * 17.0)
	)

	var target_lag_position := Vector3(
		-look_lag_rotation.y * 0.16,
		look_lag_rotation.x * 0.11,
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
		var cadence := 13.0 if sprinting else 10.2
		bob_phase += delta * cadence * clampf(speed_ratio, 0.65, 1.45)
		var bob_weight := (0.20 if ads else 1.0) * clampf(speed_ratio, 0.35, 1.25)
		target_bob_position = Vector3(
			sin(bob_phase) * 0.010,
			cos(bob_phase * 2.0) * 0.0065,
			0.0
		) * bob_weight
		target_bob_rotation = Vector3(
			cos(bob_phase * 2.0) * 0.0045,
			sin(bob_phase) * 0.0065,
			sin(bob_phase) * 0.010
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
		idle_weight *= 0.32
	var idle_position := Vector3(
		sin(idle_time * 0.86) * 0.0018,
		sin(idle_time * 1.37) * 0.0026,
		0.0
	) * idle_weight
	var idle_rotation := Vector3(
		sin(idle_time * 1.11) * 0.0024,
		cos(idle_time * 0.73) * 0.0028,
		sin(idle_time * 0.91) * 0.0018
	) * idle_weight

	visual_recoil_position = visual_recoil_position.lerp(
		Vector3.ZERO,
		1.0 - exp(-delta * 18.5)
	)
	visual_recoil_rotation = visual_recoil_rotation.lerp(
		Vector3.ZERO,
		1.0 - exp(-delta * 16.0)
	)

	var desired_position := ads_weapon_position if ads else hip_weapon_position
	var desired_rotation := ads_weapon_rotation if ads else hip_weapon_rotation

	if sprinting:
		desired_position += AK_SPRINT_POSITION_OFFSET
		desired_rotation += AK_SPRINT_ROTATION_OFFSET

	desired_position += look_lag_position
	desired_position += bob_position
	desired_position += idle_position
	desired_position += visual_recoil_position

	desired_rotation += look_lag_rotation
	desired_rotation += bob_rotation
	desired_rotation += idle_rotation
	desired_rotation += visual_recoil_rotation

	var position_response := 23.0 if ads else 16.0
	var rotation_response := 25.0 if ads else 17.0
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
			target_viewmodel_fov = AK_VIEWMODEL_SPRINT_FOV
		viewmodel_camera.fov = lerpf(
			viewmodel_camera.fov,
			target_viewmodel_fov,
			1.0 - exp(-delta * 13.0)
		)


func _animate_viewmodel_fire() -> void:
	super._animate_viewmodel_fire()
	if weapon == null or weapon.id != &"ak74u":
		return

	# Keep the existing mesh kick subtle and let the root spring provide the
	# heavier shoulder impulse so the whole gun and hands move together.
	if first_person_viewmodel != null:
		first_person_viewmodel.fire_kick = minf(first_person_viewmodel.fire_kick, 0.38)

	visual_recoil_position += Vector3(
		randf_range(-0.0025, 0.0025),
		randf_range(-0.0010, 0.0020),
		0.034
	)
	visual_recoil_rotation += Vector3(
		deg_to_rad(1.55),
		deg_to_rad(randf_range(-0.32, 0.32)),
		deg_to_rad(randf_range(-0.42, 0.42))
	)

	visual_recoil_position.x = clampf(visual_recoil_position.x, -0.010, 0.010)
	visual_recoil_position.y = clampf(visual_recoil_position.y, -0.008, 0.010)
	visual_recoil_position.z = clampf(visual_recoil_position.z, 0.0, 0.075)
	visual_recoil_rotation.x = clampf(
		visual_recoil_rotation.x,
		deg_to_rad(-0.4),
		deg_to_rad(3.8)
	)
	visual_recoil_rotation.y = clampf(
		visual_recoil_rotation.y,
		deg_to_rad(-1.1),
		deg_to_rad(1.1)
	)
	visual_recoil_rotation.z = clampf(
		visual_recoil_rotation.z,
		deg_to_rad(-1.4),
		deg_to_rad(1.4)
	)


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
