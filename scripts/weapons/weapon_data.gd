class_name WeaponData
extends Resource

@export var id: StringName = &"weapon"
@export var display_name := "Weapon"
@export_group("Roster")
@export var standard_gameplay_enabled := true
@export var deprecated := false
@export_multiline var roster_note := ""
@export_group("")
@export var weapon_class: StringName = &"pistol"
@export var fire_mode: StringName = &"semi"
@export var damage := 50.0
@export var headshot_multiplier := 3.0
@export var pellets := 1
@export var pierce := 1
@export var magazine_size := 8
@export var reserve_ammo := 96
@export var reload_time := 1.6
@export var fire_interval := 0.14
@export var burst_count := 1
@export var burst_interval := 0.08
@export var range := 100.0
@export var spread := 0.02
@export var ads_spread := 0.004
@export var recoil_pitch := 1.25
@export var recoil_yaw := 0.35
@export var hip_fov := 75.0
@export var ads_fov := 58.0
@export var shell_reload := false
@export var projectile_type: StringName = &""
@export var projectile_speed := 42.0
@export var projectile_gravity := 0.0
@export var splash_damage := 0.0
@export var splash_radius := 0.0
@export var self_damage := false
@export var chain_count := 0
@export var chain_radius := 0.0
@export var cone_range := 0.0
@export var cone_angle := 0.0
@export var wall_cost := 0
@export var ammo_cost := 250
@export var viewmodel_profile: WeaponViewmodelProfile
