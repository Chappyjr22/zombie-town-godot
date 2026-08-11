class_name ZombieTownGameplayPrototype
extends Node3D

@onready var player: ZombieTownSurvivalPlayer = $Player
@onready var interaction: ZombieTownSurvivalInteraction = $Player/Interaction
@onready var equipment: ZombieTownPlayerEquipment = $Player/Equipment
@onready var round_manager: ZombieTownGameplayRoundManager = $RoundManager
@onready var powerup_manager: ZombieTownPowerupManager = $PowerupManager
@onready var hud: ZombieTownGameplayHUD = $HUD

var game_over := false

func _ready() -> void:
	player.health_changed.connect(hud.set_health)
	player.weapon_changed.connect(hud.set_weapon)
	player.ammo_changed.connect(hud.set_ammo)
	player.stats_changed.connect(hud.set_stats)
	player.hit_confirmed.connect(hud.show_hit)
	player.weapon_slots_changed.connect(hud.set_weapon_slots)
	player.downed_status_changed.connect(hud.set_downed_status)
	player.revived.connect(hud.show_revived)
	player.died.connect(_on_player_died)
	interaction.prompt_changed.connect(hud.set_interaction_prompt)
	equipment.equipment_changed.connect(hud.set_equipment)
	powerup_manager.buffs_changed.connect(hud.set_buffs)
	powerup_manager.pickup_announced.connect(hud.show_powerup)
	round_manager.round_changed.connect(hud.set_round)
	round_manager.zombie_counts_changed.connect(hud.set_zombie_counts)
	round_manager.boss_status_changed.connect(hud.set_boss_status)

	hud.set_health(player.health, player.max_health)
	if player.weapon != null:
		hud.set_weapon(player.weapon.display_name, player.weapon.id)
	hud.set_ammo(player.ammo, player.reserve_ammo, player.reloading)
	hud.set_stats(player.points, player.kills, player.headshots)
	hud.set_weapon_slots(player.weapon_slot_summary())
	hud.set_equipment(equipment.equipment_summary())
	hud.set_buffs("")
	hud.set_downed_status(false, 0.0, 0.0)
	hud.set_boss_status(false, "", 0.0, 0.0)
	hud.set_zombie_counts(0, 0)
	hud.set_interaction_prompt("", true)
	round_manager.start_game()

func _unhandled_input(event: InputEvent) -> void:
	if not game_over and OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		round_manager.debug_force_boss_round()
		get_viewport().set_input_as_handled()
		return
	if not game_over:
		return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_tree().reload_current_scene()

func _on_player_died() -> void:
	game_over = true
	round_manager.stop_game()
	hud.set_interaction_prompt("", true)
	hud.set_boss_status(false, "", 0.0, 0.0)
	hud.show_game_over(round_manager.round_number, player.kills)
