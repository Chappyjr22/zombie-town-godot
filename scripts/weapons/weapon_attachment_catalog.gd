class_name ZombieTownWeaponAttachmentCatalog
extends RefCounted

const ATTACHMENT_PATHS := {
	&"quaternius_bayonet": "res://resources/weapons/attachments/quaternius/bayonet.tres",
	&"quaternius_bayonet_2": "res://resources/weapons/attachments/quaternius/bayonet_2.tres",
	&"quaternius_bipod": "res://resources/weapons/attachments/quaternius/bipod.tres",
	&"quaternius_flashlight": "res://resources/weapons/attachments/quaternius/flashlight.tres",
	&"quaternius_grip": "res://resources/weapons/attachments/quaternius/grip.tres",
	&"quaternius_scope_1": "res://resources/weapons/attachments/quaternius/scope_1.tres",
	&"quaternius_scope_2": "res://resources/weapons/attachments/quaternius/scope_2.tres",
	&"quaternius_scope_3": "res://resources/weapons/attachments/quaternius/scope_3.tres",
	&"quaternius_silencer_1": "res://resources/weapons/attachments/quaternius/silencer_1.tres",
	&"quaternius_silencer_2": "res://resources/weapons/attachments/quaternius/silencer_2.tres",
	&"quaternius_silencer_3": "res://resources/weapons/attachments/quaternius/silencer_3.tres",
	&"quaternius_silencer_long": "res://resources/weapons/attachments/quaternius/silencer_long.tres",
	&"quaternius_silencer_short": "res://resources/weapons/attachments/quaternius/silencer_short.tres",
	&"quaternius_stock": "res://resources/weapons/attachments/quaternius/stock.tres",
	&"quaternius_tripod": "res://resources/weapons/attachments/quaternius/tripod.tres",
}


static func all_attachment_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for attachment_variant: Variant in ATTACHMENT_PATHS.keys():
		result.append(StringName(str(attachment_variant)))
	result.sort()
	return result


static func load_attachment(attachment_id: StringName) -> WeaponAttachmentData:
	var path := str(ATTACHMENT_PATHS.get(attachment_id, ""))
	if path.is_empty():
		return null
	return load(path) as WeaponAttachmentData

