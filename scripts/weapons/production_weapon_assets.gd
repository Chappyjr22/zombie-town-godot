class_name ZombieTownProductionWeaponAssets
extends RefCounted

const ASSET_ROOT := "res://assets/weapons/cc0"

const CONFIG := {
	&"m1911": {
		"path": ASSET_ROOT + "/makarov.glb",
		"target_length": 0.50,
		"back_z": 0.20,
		"rotation_degrees": Vector3.ZERO
	},
	&"ak74u": {
		"path": ASSET_ROOT + "/ak47.glb",
		"target_length": 0.98,
		"back_z": 0.28,
		"rotation_degrees": Vector3.ZERO
	},
	&"mp5": {
		"path": ASSET_ROOT + "/suomi_kp.glb",
		"target_length": 0.90,
		"back_z": 0.28,
		"rotation_degrees": Vector3.ZERO
	},
	&"skorpion": {
		"path": ASSET_ROOT + "/grease_gun.glb",
		"target_length": 0.80,
		"back_z": 0.25,
		"rotation_degrees": Vector3.ZERO
	},
	&"luger": {
		"path": ASSET_ROOT + "/luger.glb",
		"target_length": 0.52,
		"back_z": 0.20,
		"rotation_degrees": Vector3.ZERO
	},
	&"flaregun": {
		"path": ASSET_ROOT + "/flare_gun.glb",
		"target_length": 0.54,
		"back_z": 0.20,
		"rotation_degrees": Vector3.ZERO
	},
	&"olympia": {
		"path": ASSET_ROOT + "/shotgun.glb",
		"target_length": 1.06,
		"back_z": 0.31,
		"rotation_degrees": Vector3.ZERO
	},
	&"dsr50": {
		"path": ASSET_ROOT + "/sniper.glb",
		"target_length": 1.14,
		"back_z": 0.32,
		"rotation_degrees": Vector3.ZERO
	}
}

static func supports(weapon_id: StringName) -> bool:
	return CONFIG.has(weapon_id)

static func asset_path(weapon_id: StringName) -> String:
	var config_variant: Variant = CONFIG.get(weapon_id, {})
	if not config_variant is Dictionary:
		return ""
	var config: Dictionary = config_variant
	return str(config.get("path", ""))

static func asset_available(weapon_id: StringName) -> bool:
	var path := asset_path(weapon_id)
	return not path.is_empty() and ResourceLoader.exists(path)

static func target_length(weapon_id: StringName) -> float:
	var config_variant: Variant = CONFIG.get(weapon_id, {})
	if not config_variant is Dictionary:
		return 0.8
	var config: Dictionary = config_variant
	return float(config.get("target_length", 0.8))

static func back_z(weapon_id: StringName) -> float:
	var config_variant: Variant = CONFIG.get(weapon_id, {})
	if not config_variant is Dictionary:
		return 0.24
	var config: Dictionary = config_variant
	return float(config.get("back_z", 0.24))

static func rotation_radians(weapon_id: StringName) -> Vector3:
	var config_variant: Variant = CONFIG.get(weapon_id, {})
	if not config_variant is Dictionary:
		return Vector3.ZERO
	var config: Dictionary = config_variant
	var rotation_variant: Variant = config.get("rotation_degrees", Vector3.ZERO)
	if not rotation_variant is Vector3:
		return Vector3.ZERO
	var rotation_degrees_value: Vector3 = rotation_variant
	return Vector3(
		deg_to_rad(rotation_degrees_value.x),
		deg_to_rad(rotation_degrees_value.y),
		deg_to_rad(rotation_degrees_value.z)
	)
