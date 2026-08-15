class_name ZombieTownWeaponCatalog
extends RefCounted

const WEAPON_IDS: Array[StringName] = [
	&"m1911",
	&"ak74u",
	&"mp7",
	&"ump",
	&"hk416",
	&"m16",
	&"rem870",
	&"benelli_m4",
	&"aa12",
	&"rpd",
	&"m200",
	&"rpg7",
	&"flaregun",
	&"bknife",
	&"raygun",
	&"raygun2",
	&"thunder",
	&"waffe",
	&"makarov",
	&"mp5",
	&"skorpion",
	&"m4a1",
	&"rpk",
	&"m1216",
	&"dsr50",
	&"m14",
	&"olympia",
	&"warmachine",
	&"hamr",
	&"luger",
	&"galil",
]

const DEVELOPER_EVALUATION_WEAPON_IDS: Array[StringName] = [
	&"dev_vector",
	&"dev_cz_scorpion",
]

## Version-stable inventory/save migrations. Retired weapons deliberately do
## not appear here: their original IDs remain loadable so an old save retains
## ownership, ammo, order, and Pack-a-Punch state instead of receiving an
## unrelated replacement.
const SAVE_ID_MIGRATIONS := {
	&"m4a1": &"hk416",
	&"rpk": &"rpd",
	&"m1216": &"aa12",
	&"dsr50": &"m200",
}

const RETAINED_LEGACY_SAVE_IDS: Array[StringName] = [
	&"m14", &"olympia", &"warmachine", &"hamr", &"mp5", &"skorpion",
]


static func all_weapon_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(WEAPON_IDS)
	return result


static func developer_weapon_ids() -> Array[StringName]:
	var result := all_weapon_ids()
	if OS.is_debug_build():
		result.append_array(DEVELOPER_EVALUATION_WEAPON_IDS)
	return result


static func standard_gameplay_weapon_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for weapon_id: StringName in WEAPON_IDS:
		var data := load_weapon(weapon_id)
		if data != null and data.standard_gameplay_enabled and not data.deprecated:
			result.append(weapon_id)
	return result


static func is_standard_gameplay_weapon(weapon_id: StringName) -> bool:
	var data := load_weapon(weapon_id)
	return data != null and data.standard_gameplay_enabled and not data.deprecated


static func load_weapon(weapon_id: StringName) -> WeaponData:
	var path := weapon_path(weapon_id)
	if path.is_empty():
		return null
	return load(path) as WeaponData


static func load_developer_weapon(weapon_id: StringName) -> WeaponData:
	var weapon := load_weapon(weapon_id)
	if weapon != null:
		return weapon
	if not OS.is_debug_build():
		return null
	var path := developer_weapon_path(weapon_id)
	if path.is_empty():
		return null
	return load(path) as WeaponData


static func resolve_saved_weapon_id(saved_weapon_id: StringName) -> StringName:
	var mapped_variant: Variant = SAVE_ID_MIGRATIONS.get(saved_weapon_id, saved_weapon_id)
	return StringName(str(mapped_variant))


static func load_saved_weapon(saved_weapon_id: StringName) -> WeaponData:
	var resolved_id := resolve_saved_weapon_id(saved_weapon_id)
	var migrated := load_weapon(resolved_id)
	if migrated != null:
		return migrated
	# Forward/backward robustness for a mapping whose target is unavailable in
	# a partially updated build: prefer the original resource before falling
	# back to the non-destructive starting pistol.
	var original := load_weapon(saved_weapon_id)
	if original != null:
		return original
	return load_weapon(&"m1911")


static func developer_weapon_path(weapon_id: StringName) -> String:
	if not OS.is_debug_build():
		return ""
	match weapon_id:
		&"dev_vector":
			return "res://resources/weapons/candidates/vector_reserve.tres"
		&"dev_cz_scorpion":
			return "res://resources/weapons/candidates/cz_scorpion_reserve.tres"
		_:
			return ""

static func weapon_path(weapon_id: StringName) -> String:
	match weapon_id:
		&"m1911":
			return "res://resources/weapons/m1911.tres"
		&"makarov":
			return "res://resources/weapons/makarov.tres"
		&"m14":
			return "res://resources/weapons/m14.tres"
		&"olympia":
			return "res://resources/weapons/olympia.tres"
		&"mp7":
			return "res://resources/weapons/mp7.tres"
		&"ump":
			return "res://resources/weapons/ump.tres"
		&"mp5":
			return "res://resources/weapons/mp5.tres"
		&"ak74u":
			return "res://resources/weapons/ak74u.tres"
		&"galil":
			return "res://resources/weapons/galil.tres"
		&"rem870":
			return "res://resources/weapons/rem870.tres"
		&"m4a1":
			return "res://resources/weapons/m4a1.tres"
		&"hk416":
			return "res://resources/weapons/hk416.tres"
		&"m16":
			return "res://resources/weapons/m16.tres"
		&"benelli_m4":
			return "res://resources/weapons/benelli_m4.tres"
		&"aa12":
			return "res://resources/weapons/aa12.tres"
		&"rpd":
			return "res://resources/weapons/rpd.tres"
		&"m200":
			return "res://resources/weapons/m200.tres"
		&"rpg7":
			return "res://resources/weapons/rpg7.tres"
		&"skorpion":
			return "res://resources/weapons/skorpion.tres"
		&"luger":
			return "res://resources/weapons/luger.tres"
		&"flaregun":
			return "res://resources/weapons/flaregun.tres"
		&"rpk":
			return "res://resources/weapons/rpk.tres"
		&"hamr":
			return "res://resources/weapons/hamr.tres"
		&"m1216":
			return "res://resources/weapons/m1216.tres"
		&"dsr50":
			return "res://resources/weapons/dsr50.tres"
		&"bknife":
			return "res://resources/weapons/bknife.tres"
		&"raygun":
			return "res://resources/weapons/raygun.tres"
		&"raygun2":
			return "res://resources/weapons/raygun2.tres"
		&"warmachine":
			return "res://resources/weapons/warmachine.tres"
		&"thunder":
			return "res://resources/weapons/thunder.tres"
		&"waffe":
			return "res://resources/weapons/waffe.tres"
		_:
			return ""
