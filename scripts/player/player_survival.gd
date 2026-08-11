class_name ZombieTownSurvivalPlayer
extends ZombieTownGameplayPlayer

signal downed_status_changed(active: bool, bleedout_remaining: float, self_revive_remaining: float)
signal revived(method: StringName)
signal quick_revive_consumed

const BLEEDOUT_DURATION := 25.0
const SELF_REVIVE_DELAY := 4.5
const REVIVE_INVULNERABILITY := 2.5
const DOWNED_CRAWL_SPEED := 1.15
const DOWNED_CAMERA_HEIGHT := 0.68

var downed := false
var bleedout_remaining := 0.0
var self_revive_remaining := 0.0
var quick_revive_available := false
var revive_invulnerability_remaining := 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not downed:
		super._unhandled_input(event)
		return

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
	if revive_invulnerability_remaining > 0.0:
		revive_invulnerability_remaining = maxf(0.0, revive_invulnerability_remaining - delta)

	if not downed:
		super._physics_process(delta)
		return

	if not alive:
		_apply_gravity(delta)
		move_and_slide()
		return

	_update_controller_look(delta)
	_update_downed_movement(delta)
	_update_downed_camera(delta)
	move_and_slide()
	_update_downed_state(delta)

func take_damage(amount: float) -> void:
	if not alive or downed or revive_invulnerability_remaining > 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_enter_downed()

func is_downed() -> bool:
	return downed

func has_quick_revive_charge() -> bool:
	return quick_revive_available

func grant_quick_revive() -> void:
	quick_revive_available = true

func revive_from_downed(method: StringName = &"teammate") -> bool:
	if not downed or not alive:
		return false
	if method == &"quick_revive" and not quick_revive_available:
		return false

	downed = false
	bleedout_remaining = 0.0
	self_revive_remaining = 0.0
	health = max_health
	revive_invulnerability_remaining = REVIVE_INVULNERABILITY
	crouched = false
	ads = false
	weapon_root.visible = true
	head.position.y = maxf(head.position.y, 0.90)
	health_changed.emit(health, max_health)
	downed_status_changed.emit(false, 0.0, 0.0)

	if method == &"quick_revive":
		quick_revive_available = false
		quick_revive_consumed.emit()
	revived.emit(method)
	return true

func _enter_downed() -> void:
	if downed or not alive:
		return
	downed = true
	bleedout_remaining = BLEEDOUT_DURATION
	self_revive_remaining = SELF_REVIVE_DELAY if quick_revive_available else 0.0
	reloading = false
	reload_remaining = 0.0
	burst_remaining = 0
	ads = false
	crouched = false
	velocity.x = 0.0
	velocity.z = 0.0
	weapon_root.visible = false
	muzzle_flash.visible = false
	ammo_changed.emit(ammo, reserve_ammo, false)
	downed_status_changed.emit(true, bleedout_remaining, self_revive_remaining)

func _update_downed_state(delta: float) -> void:
	bleedout_remaining = maxf(0.0, bleedout_remaining - delta)
	if quick_revive_available and self_revive_remaining > 0.0:
		self_revive_remaining = maxf(0.0, self_revive_remaining - delta)
		if self_revive_remaining <= 0.0:
			revive_from_downed(&"quick_revive")
			return

	if bleedout_remaining <= 0.0:
		_bleed_out()
		return
	downed_status_changed.emit(true, bleedout_remaining, self_revive_remaining)

func _update_downed_movement(delta: float) -> void:
	_apply_gravity(delta)
	var input_vector: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction: Vector3 = global_transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)
	direction.y = 0.0
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	var target_horizontal: Vector2 = Vector2(direction.x, direction.z) * DOWNED_CRAWL_SPEED
	var current_horizontal: Vector2 = Vector2(velocity.x, velocity.z)
	current_horizontal = current_horizontal.move_toward(target_horizontal, acceleration * 0.55 * delta)
	velocity.x = current_horizontal.x
	velocity.z = current_horizontal.y

func _update_downed_camera(delta: float) -> void:
	head.position.y = move_toward(head.position.y, DOWNED_CAMERA_HEIGHT, delta * 4.8)
	var target_fov: float = 75.0 if weapon == null else weapon.hip_fov
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-delta * 10.0))

func _bleed_out() -> void:
	if not downed or not alive:
		return
	downed = false
	bleedout_remaining = 0.0
	self_revive_remaining = 0.0
	alive = false
	weapon_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	downed_status_changed.emit(false, 0.0, 0.0)
	died.emit()
