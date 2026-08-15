class_name WeaponAttachmentData
extends Resource

## Visual-only attachment metadata. Gameplay modifiers deliberately do not live
## here; future Pack-a-Punch and progression systems can choose an attachment
## set without turning this resource into a player-facing Gunsmith definition.
@export var id: StringName = &"attachment"
@export var display_name := "Attachment"
@export_enum("optic", "muzzle", "underbarrel", "side", "stock", "bayonet") var slot := "optic"
@export var socket_name: StringName = &"Socket_Optic"
@export var model_scene: PackedScene
@export var default_local_transform := Transform3D.IDENTITY
@export var compatible_weapon_ids: Array[StringName] = []
@export var variant_tags: Array[StringName] = []
@export_multiline var notes := ""


func supports_weapon(weapon_id: StringName) -> bool:
	return compatible_weapon_ids.is_empty() or weapon_id in compatible_weapon_ids

