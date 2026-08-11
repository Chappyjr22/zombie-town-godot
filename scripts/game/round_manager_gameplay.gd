class_name ZombieTownGameplayRoundManager
extends ZombieTownRoundManager

signal zombie_killed(zombie: ZombieTownZombie)
signal boss_status_changed(active: bool, boss_name: String, current: float, maximum: float)

const BOSS_INTERVAL := 10
const BOSS_ESCORT_COUNT := 10
const BOSS_NAME := "THE BRUTE"
const BOSS_SCENE: PackedScene = preload("res://scenes/zombies/brute_boss.tscn")

var active_boss: ZombieTownBruteBoss

func _begin_round() -> void:
	round_number += 1
	var boss_round: bool = round_number % BOSS_INTERVAL == 0
	to_spawn = BOSS_ESCORT_COUNT if boss_round else first_round_count + (round_number - 1) * 3
	spawn_remaining = 0.15
	waiting_for_next_round = false
	round_changed.emit(round_number)
	if boss_round:
		_spawn_boss()
	else:
		active_boss = null
		boss_status_changed.emit(false, "", 0.0, 0.0)
	zombie_counts_changed.emit(alive_count, to_spawn)

func _spawn_boss() -> void:
	if BOSS_SCENE == null or spawn_points.is_empty():
		return
	var spawn_point: Node3D = _choose_spawn_point()
	var boss: ZombieTownBruteBoss = BOSS_SCENE.instantiate() as ZombieTownBruteBoss
	if boss == null:
		return

	var boss_tier: int = maxi(0, int(round_number / BOSS_INTERVAL) - 1)
	boss.max_health = 5200.0 + float(boss_tier) * 3800.0
	boss.move_speed = minf(3.0, 2.35 + float(boss_tier) * 0.10)
	boss.attack_damage = 38.0 + float(boss_tier) * 5.0
	boss.attack_range = 1.55
	boss.attack_cooldown = 1.1
	boss.slam_damage = 46.0 + float(boss_tier) * 6.0
	boss.slam_cooldown = maxf(4.8, 6.0 - float(boss_tier) * 0.2)
	boss.boss_health_changed.connect(_on_boss_health_changed)
	boss.died.connect(_on_zombie_died)
	active_boss = boss
	spawn_parent.add_child(boss)
	boss.global_position = spawn_point.global_position
	boss.set_target(player)
	alive_count += 1
	boss_status_changed.emit(true, BOSS_NAME, boss.health, boss.max_health)

func _on_boss_health_changed(current: float, maximum: float) -> void:
	if active_boss == null:
		return
	boss_status_changed.emit(true, BOSS_NAME, current, maximum)

func _on_zombie_died(zombie: ZombieTownZombie) -> void:
	var was_boss: bool = zombie == active_boss
	zombie_killed.emit(zombie)
	if was_boss:
		active_boss = null
		boss_status_changed.emit(false, "", 0.0, 0.0)
	super._on_zombie_died(zombie)

func debug_force_boss_round() -> void:
	if not OS.is_debug_build() or spawn_parent == null:
		return
	for child: Node in spawn_parent.get_children():
		if child is ZombieTownZombie:
			child.queue_free()
	to_spawn = 0
	alive_count = 0
	waiting_for_next_round = false
	active_boss = null
	boss_status_changed.emit(false, "", 0.0, 0.0)
	round_number = BOSS_INTERVAL - 1
	spawn_remaining = 0.0
	_begin_round()
