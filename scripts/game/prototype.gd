extends Node3D

@onready var player: ZombieTownPlayer = $Player
@onready var interaction: ZombieTownPlayerInteraction = $Player/Interaction
@onready var round_manager: ZombieTownRoundManager = $RoundManager
@onready var hud: ZombieTownHUD = $HUD

var game_over := false

func _ready() -> void:
	player.health_changed.connect(hud.set_health)
	player.weapon_changed.connect(hud.set_weapon)
	player.ammo_changed.connect(hud.set_ammo)
	player.stats_changed.connect(hud.set_stats)
	player.hit_confirmed.connect(hud.show_hit)
	player.died.connect(_on_player_died)
	interaction.prompt_changed.connect(hud.set_interaction_prompt)
	round_manager.round_changed.connect(hud.set_round)
	round_manager.zombie_counts_changed.connect(hud.set_zombie_counts)

	hud.set_health(player.health, player.max_health)
	if player.weapon != null:
		hud.set_weapon(player.weapon.display_name, player.weapon.id)
	hud.set_ammo(player.ammo, player.reserve_ammo, player.reloading)
	hud.set_stats(player.points, player.kills, player.headshots)
	hud.set_zombie_counts(0, 0)
	hud.set_interaction_prompt("", true)
	round_manager.start_game()

func _unhandled_input(event: InputEvent) -> void:
	if not game_over:
		return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_tree().reload_current_scene()

func _on_player_died() -> void:
	game_over = true
	round_manager.stop_game()
	hud.set_interaction_prompt("", true)
	hud.show_game_over(round_manager.round_number, player.kills)
