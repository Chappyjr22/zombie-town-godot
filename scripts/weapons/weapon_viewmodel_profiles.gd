class_name ZombieTownWeaponViewmodelProfiles
extends RefCounted

const PROFILE_ROOT := "res://resources/weapons/viewmodels"


static func resolve(data: WeaponData) -> WeaponViewmodelProfile:
	if data == null:
		return null
	if data.viewmodel_profile != null:
		return data.viewmodel_profile
	var path := profile_path(data.id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as WeaponViewmodelProfile


static func profile_path(weapon_id: StringName) -> String:
	if ZombieTownWeaponCatalog.weapon_path(weapon_id).is_empty():
		return ""
	return "%s/%s_viewmodel.tres" % [PROFILE_ROOT, String(weapon_id)]


static func profile_path_for(data: WeaponData) -> String:
	if data == null:
		return ""
	if data.viewmodel_profile != null and not data.viewmodel_profile.resource_path.is_empty():
		return data.viewmodel_profile.resource_path
	var weapon_path := ZombieTownWeaponCatalog.weapon_path(data.id)
	if not weapon_path.is_empty():
		var canonical_weapon := ResourceLoader.load(
			weapon_path,
			"",
			ResourceLoader.CACHE_MODE_IGNORE
		) as WeaponData
		if (
			canonical_weapon != null
			and canonical_weapon.viewmodel_profile != null
			and not canonical_weapon.viewmodel_profile.resource_path.is_empty()
		):
			return canonical_weapon.viewmodel_profile.resource_path
	return profile_path(data.id)
