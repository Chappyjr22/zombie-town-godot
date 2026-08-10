class_name ZombieTownPresentationTunedPlayer
extends ZombieTownAdvancedPlayer

func _update_weapon_visual() -> void:
	super._update_weapon_visual()
	if weapon == null:
		return
	match weapon.weapon_class:
		&"pistol":
			hip_weapon_position = Vector3(0.285, -0.235, -0.57)
		&"smg":
			hip_weapon_position = Vector3(0.285, -0.225, -0.61)
		&"rifle":
			hip_weapon_position = Vector3(0.305, -0.235, -0.68)
		&"shotgun":
			hip_weapon_position = Vector3(0.315, -0.245, -0.70)
		&"lmg":
			hip_weapon_position = Vector3(0.335, -0.265, -0.74)
		&"sniper":
			hip_weapon_position = Vector3(0.315, -0.245, -0.76)
		&"wonder":
			hip_weapon_position = Vector3(0.305, -0.250, -0.64)
	weapon_root.position = hip_weapon_position
