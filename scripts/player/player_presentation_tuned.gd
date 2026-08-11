class_name ZombieTownPresentationTunedPlayer
extends ZombieTownAdvancedPlayer

func _update_weapon_visual() -> void:
	super._update_weapon_visual()
	if weapon == null:
		return
	match weapon.weapon_class:
		&"pistol":
			hip_weapon_position = Vector3(0.285, -0.235, -0.57)
		&"knife":
			hip_weapon_position = Vector3(0.285, -0.230, -0.54)
			ads_weapon_position = Vector3(0.0, -0.155, -0.50)
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

	match weapon.id:
		&"ak74u":
			# COD-style hip framing: closer, lower, and farther right while ADS stays centered.
			hip_weapon_position = Vector3(0.360, -0.270, -0.560)
		&"raygun":
			ads_weapon_position = Vector3(0.0, -0.245, -0.60)
		&"raygun2":
			ads_weapon_position = Vector3(0.0, -0.245, -0.63)
		_:
			pass
	weapon_root.position = hip_weapon_position
