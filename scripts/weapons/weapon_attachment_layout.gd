class_name WeaponAttachmentLayout
extends Resource

## Socket paths are resolved below the imported WeaponRoot. Generated
## Quaternius GLBs use these names directly, while another pack can override
## only the paths in its per-weapon layout resource.
@export_group("Sockets")
@export var optic_socket := NodePath("Socket_Optic")
@export var muzzle_socket := NodePath("Socket_Muzzle")
@export var underbarrel_socket := NodePath("Socket_Underbarrel")
@export var side_socket := NodePath("Socket_Side")
@export var stock_socket := NodePath("Socket_Stock")
@export var bayonet_socket := NodePath("Socket_Bayonet")
@export var magazine_socket := NodePath("Socket_Magazine")
@export var projectile_socket := NodePath("Socket_Projectile")
@export var primary_grip_socket := NodePath("Socket_PrimaryGrip")
@export var support_grip_socket := NodePath("Socket_SupportGrip")

## These are visual recipes only. They provide a data home for future base,
## Pack-a-Punch, weapon-specific, and map/progression variants without adding
## weapon-id branches to the player presentation script.
@export_group("Visual Variants")
@export var supported_slots: Array[StringName] = []
@export var base_attachment_ids: Array[StringName] = []
@export var pack_a_punch_attachment_ids: Array[StringName] = []
@export var named_variant_attachment_ids: Dictionary = {}


func socket_path(slot: StringName) -> NodePath:
	match slot:
		&"optic":
			return optic_socket
		&"muzzle":
			return muzzle_socket
		&"underbarrel":
			return underbarrel_socket
		&"side":
			return side_socket
		&"stock":
			return stock_socket
		&"bayonet":
			return bayonet_socket
		&"magazine":
			return magazine_socket
		&"projectile":
			return projectile_socket
		_:
			return NodePath()
