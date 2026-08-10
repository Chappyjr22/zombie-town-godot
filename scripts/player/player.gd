class_name ZombieTownPlayer
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal ammo_changed(current: int, reserve: int, reloading: bool)
signal stats_changed(points: int, kills: int, headshots: int)
signal hit_confirmed(killed: bool, headshot: bool)
signal died

@export var weapon: WeaponData
@export var walk_speed := 4.6
@export var sprint_speed := 7.2
@export var crouch_speed := 2.5
@export var acceleration := 22.0
@export var air_acceleration := 7.5
@export var jump_velocity := 5.4
@export var mouse_sensitivity := 0.0019
@export var controller_look_speed := 2.6
@export var max_health := 100.0
@export var starting_points := 500

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_root: Node3D = $Head/Camera3D/WeaponRoot
@onready var muzzle_flash: MeshInstance3D = $Head/Camera3D/WeaponRoot/MuzzleFlash

var health := 100.0
var points := 500
var kills := 0
var headshots := 0
var ammo := 0
var reserve_ammo := 0
var crouched := false
var alive := true
var reloading := false
var reload_remaining := 0.0
var next_fire_time := 0.0
var look_pitch := 0.0
var muzzle_flash_remaining := 0.0
var weapon_kick := 0.0
var ads := false

const STANDING_CAMERA_HEIGHT := 1.58
const CROUCH_CAMERA_HEIGHT := 1.08
const HIP_WEAPON_POSITION := Vector3(0.24, -0.20, -0.54)
const ADS_WEAPON_POSITION := Vector3(0.0, -0.155, -0.48)

func _ready() -> void:
	_ensure_input_map()
	health = max_health
	points = starting_points
	if weapon == null:
		weapon = load("res://resources/weapons/m1911.tres") as WeaponData
	ammo = weapon.magazine_size
	reserve_ammo = weapon.reserve_ammo
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_sync_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and alive:
		rotate_y(-event.relative.x * mouse_sensitivity)
		look_pitch = clampf(look_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-85.0), deg_to_rad(85.0))
		head.rotation.x = look_pitch

func _physics_process(delta: float) -> void:
	if not alive:
		_apply_gravity(delta)
		move_and_slide()
		return

	_update_controller_look(delta)
	_update_actions(delta)
	_update_movement(delta)
	_update_camera_and_weapon(delta)
	_update_reload(delta)
	_update_muzzle_flash(delta)
	move_and_slide()

func _update_actions(_delta: float) -> void:
	if Input.is_action_just_pressed(&"crouch"):
		crouched = not crouched

	ads = Input.is_action_pressed(&"ads")

	if Input.is_action_just_pressed(&"reload"):
		_begin_reload()

	if Input.is_action_just_pressed(&"fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_fire()

	if Input.is_action_just_pressed(&"jump") and is_on_floor() and not crouched:
		velocity.y = jump_velocity

func _update_movement(delta: float) -> void:
	_apply_gravity(delta)
	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction := global_transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)
	direction.y = 0.0
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	var speed := walk_speed
	if crouched:
		speed = crouch_speed
	elif Input.is_action_pressed(&"sprint") and input_vector.y < -0.1 and not ads:
		speed = sprint_speed

	var target_horizontal := Vector2(direction.x, direction.z) * speed
	var current_horizontal := Vector2(velocity.x, velocity.z)
	var accel := acceleration if is_on_floor() else air_acceleration
	current_horizontal = current_horizontal.move_toward(target_horizontal, accel * delta)
	velocity.x = current_horizontal.x
	velocity.z = current_horizontal.y

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1

func _update_controller_look(delta: float) -> void:
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look.length_squared() < 0.0025:
		return
	rotate_y(-look.x * controller_look_speed * delta)
	look_pitch = clampf(look_pitch - look.y * controller_look_speed * delta, deg_to_rad(-85.0), deg_to_rad(85.0))
	head.rotation.x = look_pitch

func _update_camera_and_weapon(delta: float) -> void:
	var desired_height := CROUCH_CAMERA_HEIGHT if crouched else STANDING_CAMERA_HEIGHT
	head.position.y = move_toward(head.position.y, desired_height, delta * 4.2)

	var desired_fov := weapon.ads_fov if ads else weapon.hip_fov
	camera.fov = lerpf(camera.fov, desired_fov, 1.0 - exp(-delta * 11.0))

	weapon_kick = move_toward(weapon_kick, 0.0, delta * 1.8)
	var desired_weapon_position := ADS_WEAPON_POSITION if ads else HIP_WEAPON_POSITION
	desired_weapon_position.z += weapon_kick * 0.06
	weapon_root.position = weapon_root.position.lerp(desired_weapon_position, 1.0 - exp(-delta * 15.0))
	weapon_root.rotation.x = lerpf(weapon_root.rotation.x, weapon_kick * 0.08, 1.0 - exp(-delta * 14.0))

func _fire() -> void:
	if reloading or Time.get_ticks_msec() / 1000.0 < next_fire_time:
		return
	if ammo <= 0:
		_begin_reload()
		return

	ammo -= 1
	next_fire_time = Time.get_ticks_msec() / 1000.0 + weapon.fire_interval
	weapon_kick = minf(weapon_kick + 0.75, 1.25)
	look_pitch = clampf(look_pitch - deg_to_rad(weapon.recoil_pitch), deg_to_rad(-85.0), deg_to_rad(85.0))
	head.rotation.x = look_pitch
	rotate_y(deg_to_rad(randf_range(-weapon.recoil_yaw, weapon.recoil_yaw)))
	muzzle_flash.visible = true
	muzzle_flash_remaining = 0.045
	ammo_changed.emit(ammo, reserve_ammo, reloading)

	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * weapon.range)
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider := result.get("collider")
	if collider == null or not collider.has_method("take_damage"):
		return

	var hit_position: Vector3 = result.get("position", origin)
	var headshot := false
	if collider.has_method("is_headshot_point"):
		headshot = bool(collider.is_headshot_point(hit_position))
	var damage := weapon.damage * (weapon.headshot_multiplier if headshot else 1.0)
	var outcome: Dictionary = collider.take_damage(damage, headshot, self)
	points += 10
	if bool(outcome.get("killed", false)):
		kills += 1
		if headshot:
			headshots += 1
		points += 90 if headshot else 50
	stats_changed.emit(points, kills, headshots)
	hit_confirmed.emit(bool(outcome.get("killed", false)), headshot)

func _begin_reload() -> void:
	if reloading or ammo >= weapon.magazine_size or reserve_ammo <= 0:
		return
	reloading = true
	reload_remaining = weapon.reload_time
	ammo_changed.emit(ammo, reserve_ammo, true)

func _update_reload(delta: float) -> void:
	if not reloading:
		return
	reload_remaining -= delta
	if reload_remaining > 0.0:
		return
	var needed := weapon.magazine_size - ammo
	var loaded := mini(needed, reserve_ammo)
	ammo += loaded
	reserve_ammo -= loaded
	reloading = false
	ammo_changed.emit(ammo, reserve_ammo, false)

func _update_muzzle_flash(delta: float) -> void:
	if muzzle_flash_remaining <= 0.0:
		return
	muzzle_flash_remaining -= delta
	if muzzle_flash_remaining <= 0.0:
		muzzle_flash.visible = false

func take_damage(amount: float) -> void:
	if not alive:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		alive = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		died.emit()

func heal_full() -> void:
	health = max_health
	health_changed.emit(health, max_health)

func _sync_ui() -> void:
	health_changed.emit(health, max_health)
	ammo_changed.emit(ammo, reserve_ammo, reloading)
	stats_changed.emit(points, kills, headshots)

func _ensure_input_map() -> void:
	_add_key_action(&"move_forward", KEY_W)
	_add_key_action(&"move_back", KEY_S)
	_add_key_action(&"move_left", KEY_A)
	_add_key_action(&"move_right", KEY_D)
	_add_key_action(&"jump", KEY_SPACE)
	_add_key_action(&"sprint", KEY_SHIFT)
	_add_key_action(&"crouch", KEY_CTRL)
	_add_key_action(&"crouch", KEY_C)
	_add_key_action(&"reload", KEY_R)
	_add_mouse_action(&"fire", MOUSE_BUTTON_LEFT)
	_add_mouse_action(&"ads", MOUSE_BUTTON_RIGHT)

	_add_joy_axis_action(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis_action(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis_action(&"move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis_action(&"move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis_action(&"look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis_action(&"look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_axis_action(&"look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis_action(&"look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_joy_button_action(&"jump", JOY_BUTTON_A)
	_add_joy_button_action(&"crouch", JOY_BUTTON_B)
	_add_joy_button_action(&"reload", JOY_BUTTON_X)
	_add_joy_button_action(&"sprint", JOY_BUTTON_LEFT_STICK)
	_add_joy_axis_action(&"fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_axis_action(&"ads", JOY_AXIS_TRIGGER_LEFT, 1.0)

func _add_key_action(action: StringName, keycode: int) -> void:
	_ensure_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _add_mouse_action(action: StringName, button: int) -> void:
	_ensure_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

func _add_joy_button_action(action: StringName, button: int) -> void:
	_ensure_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

func _add_joy_axis_action(action: StringName, axis: int, value: float) -> void:
	_ensure_action(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)

func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.18)
