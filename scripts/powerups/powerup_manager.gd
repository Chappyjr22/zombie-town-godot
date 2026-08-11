class_name ZombieTownPowerupManager
extends Node

signal buffs_changed(text: String)
signal pickup_announced(text: String)

const DROP_CHANCE := 0.08
const DOUBLE_POINTS_DURATION := 30.0
const INSTA_KILL_DURATION := 30.0

var player: ZombieTownInventoryPlayer
var round_manager: ZombieTownGameplayRoundManager
var double_points_remaining := 0.0
var insta_kill_remaining := 0.0
var suppress_drops := false
var last_buff_text := ""

func _ready() -> void:
	player = get_node("../Player") as ZombieTownInventoryPlayer
	round_manager = get_node("../RoundManager") as ZombieTownGameplayRoundManager
	if round_manager != null:
		round_manager.zombie_killed.connect(_on_zombie_killed)
	_emit_buffs_if_changed()

func _process(delta: float) -> void:
	var state_changed := false
	if double_points_remaining > 0.0:
		double_points_remaining = maxf(0.0, double_points_remaining - delta)
		if double_points_remaining <= 0.0:
			player.set_double_points_active(false)
			state_changed = true
	if insta_kill_remaining > 0.0:
		insta_kill_remaining = maxf(0.0, insta_kill_remaining - delta)
		if insta_kill_remaining <= 0.0:
			player.set_insta_kill_active(false)
			state_changed = true
	if state_changed or double_points_remaining > 0.0 or insta_kill_remaining > 0.0:
		_emit_buffs_if_changed()

func activate_powerup(powerup_id: StringName) -> void:
	if player == null or not player.alive:
		return
	match powerup_id:
		&"max_ammo":
			_activate_max_ammo()
		&"double_points":
			double_points_remaining = DOUBLE_POINTS_DURATION
			player.set_double_points_active(true)
			pickup_announced.emit("DOUBLE POINTS")
		&"insta_kill":
			insta_kill_remaining = INSTA_KILL_DURATION
			player.set_insta_kill_active(true)
			pickup_announced.emit("INSTA-KILL")
		&"nuke":
			_activate_nuke()
	_emit_buffs_if_changed()

func _on_zombie_killed(zombie: ZombieTownZombie) -> void:
	if suppress_drops or zombie == null or randf() > DROP_CHANCE:
		return
	var active_drops: int = get_tree().get_nodes_in_group(&"powerup_drop").size()
	if active_drops >= 3:
		return
	var drop := ZombieTownPowerupDrop.new()
	drop.add_to_group(&"powerup_drop")
	get_tree().current_scene.add_child(drop)
	drop.configure(self, _choose_powerup(), zombie.global_position)

func _choose_powerup() -> StringName:
	var roll: float = randf()
	if roll < 0.30:
		return &"max_ammo"
	if roll < 0.55:
		return &"double_points"
	if roll < 0.80:
		return &"insta_kill"
	return &"nuke"

func _activate_max_ammo() -> void:
	player.refill_all_weapon_ammo()
	var equipment := player.get_node_or_null("Equipment") as ZombieTownPlayerEquipment
	if equipment != null:
		equipment.refill_from_max_ammo()
	pickup_announced.emit("MAX AMMO")

func _activate_nuke() -> void:
	suppress_drops = true
	var killed_count := 0
	for node: Node in get_tree().get_nodes_in_group(&"zombie"):
		if not node is ZombieTownZombie:
			continue
		var zombie := node as ZombieTownZombie
		if not zombie.alive:
			continue
		var outcome: Dictionary = zombie.take_damage(maxf(zombie.max_health * 20.0, 50000.0), false, player)
		if bool(outcome.get("killed", false)):
			killed_count += 1
	suppress_drops = false
	if killed_count > 0:
		player.kills += killed_count
	player.award_points(400)
	pickup_announced.emit("NUKE")

func _emit_buffs_if_changed() -> void:
	var parts: Array[String] = []
	if double_points_remaining > 0.0:
		parts.append("DOUBLE POINTS %ds" % ceili(double_points_remaining))
	if insta_kill_remaining > 0.0:
		parts.append("INSTA-KILL %ds" % ceili(insta_kill_remaining))
	var text: String = "   ".join(parts)
	if text == last_buff_text:
		return
	last_buff_text = text
	buffs_changed.emit(text)
