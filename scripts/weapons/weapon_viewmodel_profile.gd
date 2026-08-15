class_name WeaponViewmodelProfile
extends Resource

## Production model and canonical import correction. Production scenes should
## eventually be authored facing Godot camera-forward (-Z), but these fields let
## raw source assets participate while that normalization work is in progress.
@export var model_scene: PackedScene
@export var model_rotation_degrees := Vector3.ZERO
@export var model_offset := Vector3.ZERO
@export var target_length := 0.8
@export var model_back_z := 0.24
@export var use_profile_hands := false
@export var use_advanced_motion := false
@export var attachment_layout: WeaponAttachmentLayout

## Each presentation state is independently authored in screen space. ADS is
## intentionally not derived from the hip transform.
@export_group("Hip")
@export var hip_position := Vector3(0.30, -0.24, -0.64)
@export var hip_rotation_degrees := Vector3.ZERO
@export var hip_viewmodel_fov := 75.0

@export_group("ADS")
@export var ads_position := Vector3(0.0, -0.15, -0.58)
@export var ads_rotation_degrees := Vector3.ZERO
@export var ads_viewmodel_fov := 60.0
@export var align_ads_to_sight := false
@export var sight_center := Vector3.ZERO

@export_group("Sprint")
@export var sprint_position := Vector3(0.42, -0.36, -0.58)
@export var sprint_rotation_degrees := Vector3(8.0, -8.0, -15.0)
@export var sprint_viewmodel_fov := 65.0

@export_group("State Blending")
@export var hip_position_response := 16.0
@export var hip_rotation_response := 17.0
@export var ads_position_response := 23.0
@export var ads_rotation_response := 25.0
@export var sprint_position_response := 10.0
@export var sprint_rotation_response := 11.0
@export var fov_response := 13.0

## Grip anchors are expressed in viewmodel-local coordinates. They are data,
## not weapon-id branches, so a future rigged-arm/IK implementation can consume
## the same profiles without changing player code.
@export_group("Hands")
@export var right_hand_position := Vector3(0.025, -0.148, -0.238)
@export var right_hand_rotation_degrees := Vector3(17.0, -4.0, -6.0)
@export var right_hand_scale := Vector3.ONE
@export var right_arm_origin := Vector3(0.18, -0.415, 0.035)
@export var left_hand_position := Vector3(-0.012, -0.075, -0.565)
@export var left_hand_rotation_degrees := Vector3(4.0, 3.0, 6.0)
@export var left_hand_scale := Vector3.ONE
@export var left_arm_origin := Vector3(-0.215, -0.395, -0.315)
@export_enum("trigger", "support", "underbarrel", "rail") var right_hand_pose := "trigger"
@export_enum("trigger", "support", "underbarrel", "rail") var left_hand_pose := "underbarrel"

@export_group("Motion")
@export var ads_motion_scale := 0.25
@export var look_lag_pitch := 6.0
@export var look_lag_yaw := 7.5
@export var look_lag_roll := 2.8
@export var look_lag_limit_degrees := Vector3(3.0, 4.7, 1.85)
@export var look_lag_position_scale := Vector2(0.16, 0.11)
@export var walk_bob_cadence := 10.2
@export var sprint_bob_cadence := 13.0
@export var bob_position := Vector3(0.010, 0.0065, 0.0)
@export var bob_rotation_degrees := Vector3(0.26, 0.37, 0.57)
@export var idle_position := Vector3(0.0018, 0.0026, 0.0)
@export var idle_rotation_degrees := Vector3(0.14, 0.16, 0.10)

@export_group("Recoil Presentation")
@export var recoil_position_impulse := Vector3(0.0, 0.0005, 0.034)
@export var recoil_position_random_x := 0.0025
@export var recoil_rotation_impulse_degrees := Vector3(1.55, 0.0, 0.0)
@export var recoil_yaw_random_degrees := 0.32
@export var recoil_roll_random_degrees := 0.42
@export var recoil_position_recovery := 18.5
@export var recoil_rotation_recovery := 16.0
@export var recoil_position_limit := Vector3(0.010, 0.010, 0.075)
@export var recoil_rotation_limit_degrees := Vector3(3.8, 1.1, 1.4)
@export var model_fire_kick_limit := 0.38

@export_group("Sockets")
@export var use_authored_muzzle := false
@export var muzzle_position := Vector3(0.0, 0.04, -0.78)


func model_rotation_radians() -> Vector3:
	return _radians(model_rotation_degrees)


func hip_rotation_radians() -> Vector3:
	return _radians(hip_rotation_degrees)


func ads_rotation_radians() -> Vector3:
	return _radians(ads_rotation_degrees)


func resolved_ads_position() -> Vector3:
	if not align_ads_to_sight:
		return ads_position
	var rotated_sight := Basis.from_euler(ads_rotation_radians()) * sight_center
	return Vector3(-rotated_sight.x, -rotated_sight.y, ads_position.z)


func sprint_rotation_radians() -> Vector3:
	return _radians(sprint_rotation_degrees)


func right_hand_rotation_radians() -> Vector3:
	return _radians(right_hand_rotation_degrees)


func left_hand_rotation_radians() -> Vector3:
	return _radians(left_hand_rotation_degrees)


func bob_rotation_radians() -> Vector3:
	return _radians(bob_rotation_degrees)


func idle_rotation_radians() -> Vector3:
	return _radians(idle_rotation_degrees)


func recoil_rotation_impulse_radians() -> Vector3:
	return _radians(recoil_rotation_impulse_degrees)


func recoil_rotation_limit_radians() -> Vector3:
	return _radians(recoil_rotation_limit_degrees)


func look_lag_limit_radians() -> Vector3:
	return _radians(look_lag_limit_degrees)


func state_position(state: StringName) -> Vector3:
	match state:
		&"ads":
			return resolved_ads_position()
		&"sprint":
			return sprint_position
		_:
			return hip_position


func state_rotation_degrees(state: StringName) -> Vector3:
	match state:
		&"ads":
			return ads_rotation_degrees
		&"sprint":
			return sprint_rotation_degrees
		_:
			return hip_rotation_degrees


func state_rotation_radians(state: StringName) -> Vector3:
	return _radians(state_rotation_degrees(state))


func state_viewmodel_fov(state: StringName) -> float:
	match state:
		&"ads":
			return ads_viewmodel_fov
		&"sprint":
			return sprint_viewmodel_fov
		_:
			return hip_viewmodel_fov


func set_state_position(state: StringName, value: Vector3) -> void:
	match state:
		&"ads":
			_prepare_manual_ads_transform()
			ads_position = value
		&"sprint":
			sprint_position = value
		_:
			hip_position = value


func set_state_rotation_degrees(state: StringName, value: Vector3) -> void:
	match state:
		&"ads":
			_prepare_manual_ads_transform()
			ads_rotation_degrees = value
		&"sprint":
			sprint_rotation_degrees = value
		_:
			hip_rotation_degrees = value


func set_state_viewmodel_fov(state: StringName, value: float) -> void:
	var clamped_value := clampf(value, 15.0, 120.0)
	match state:
		&"ads":
			ads_viewmodel_fov = clamped_value
		&"sprint":
			sprint_viewmodel_fov = clamped_value
		_:
			hip_viewmodel_fov = clamped_value


func copy_state_from(source: WeaponViewmodelProfile, state: StringName) -> void:
	if source == null:
		return
	match state:
		&"ads":
			ads_position = source.ads_position
			ads_rotation_degrees = source.ads_rotation_degrees
			ads_viewmodel_fov = source.ads_viewmodel_fov
			align_ads_to_sight = source.align_ads_to_sight
			sight_center = source.sight_center
		&"sprint":
			sprint_position = source.sprint_position
			sprint_rotation_degrees = source.sprint_rotation_degrees
			sprint_viewmodel_fov = source.sprint_viewmodel_fov
		_:
			hip_position = source.hip_position
			hip_rotation_degrees = source.hip_rotation_degrees
			hip_viewmodel_fov = source.hip_viewmodel_fov


func reusable_configuration_text() -> String:
	return "\n".join([
		"hip_position = %s" % _vector3_text(hip_position),
		"hip_rotation_degrees = %s" % _vector3_text(hip_rotation_degrees),
		"hip_viewmodel_fov = %.3f" % hip_viewmodel_fov,
		"ads_position = %s" % _vector3_text(ads_position),
		"ads_rotation_degrees = %s" % _vector3_text(ads_rotation_degrees),
		"ads_viewmodel_fov = %.3f" % ads_viewmodel_fov,
		"align_ads_to_sight = %s" % str(align_ads_to_sight).to_lower(),
		"sight_center = %s" % _vector3_text(sight_center),
		"sprint_position = %s" % _vector3_text(sprint_position),
		"sprint_rotation_degrees = %s" % _vector3_text(sprint_rotation_degrees),
		"sprint_viewmodel_fov = %.3f" % sprint_viewmodel_fov,
		"model_rotation_degrees = %s" % _vector3_text(model_rotation_degrees),
		"model_offset = %s" % _vector3_text(model_offset),
		"target_length = %.4f" % target_length,
		"model_back_z = %.4f" % model_back_z
	])


func _prepare_manual_ads_transform() -> void:
	if not align_ads_to_sight:
		return
	ads_position = resolved_ads_position()
	align_ads_to_sight = false


func _vector3_text(value: Vector3) -> String:
	return "Vector3(%.6f, %.6f, %.6f)" % [value.x, value.y, value.z]


func _radians(value: Vector3) -> Vector3:
	return Vector3(deg_to_rad(value.x), deg_to_rad(value.y), deg_to_rad(value.z))
