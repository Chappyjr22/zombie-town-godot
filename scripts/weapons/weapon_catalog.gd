class_name ZombieTownWeaponCatalog
extends RefCounted

static func load_weapon(weapon_id: StringName) -> WeaponData:
	var path := weapon_path(weapon_id)
	if path.is_empty():
		return null
	return load(path) as WeaponData

static func weapon_path(weapon_id: StringName) -> String:
	match weapon_id:
		&"m1911":
			return "res://resources/weapons/m1911.tres"
		&"m14":
			return "res://resources/weapons/m14.tres"
		&"olympia":
			return "res://resources/weapons/olympia.tres"
		&"mp5":
			return "res://resources/weapons/mp5.tres"
		&"ak74u":
			return "res://resources/weapons/ak74u.tres"
		&"galil":
			return "res://resources/weapons/galil.tres"
		&"rem870":
			return "res://resources/weapons/rem870.tres"
		_:
			return ""
