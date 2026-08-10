class_name ZombieTownRoundManager
extends Node

signal round_changed(round_number: int)
signal zombie_counts_changed(alive: int, remaining_to_spawn: int)

@export var zombie_scene: PackedScene
@export var player_path: NodePath = NodePath("../Player")
@export var spawn_parent_path: NodePath = NodePath("../Zombies")
@export var first_round_count := 6
@export var spawn_interval := 0.75
@export var between_round_delay := 3.0

var round_number := 0
var to_spawn := 0
var alive_count := 0
var running := false
var waiting_for_next_round := false
var spawn_remaining := 0.0

var player: ZombieTownPlayer
var spawn_parent: Node3D
var spawn_points: Array[Node3D] = []

func _ready() -> void:
	player = get_node(player_path) as ZombieTownPlayer
	spawn_parent = get_node(spawn_parent_path) as Node3D
	_refresh_spawn_points()

func start_game() -> void:
	if running:
		return
	_refresh_spawn_points()
	if spawn_points.is_empty():
		push_error("No nodes in the zombie_spawn group were found for this map.")
		return
	running = true
	_begin_round()

func stop_game() -> void:
	running = false

func _refresh_spawn_points() -> void:
	spawn_points.clear()
	for node: Node in get_tree().get_nodes_in_group(&"zombie_spawn"):
		if node is Node3D:
			spawn_points.append(node as Node3D)

func _process(delta: float) -> void:
	if not running or waiting_for_next_round or player == null or not player.alive:
		return

	if to_spawn > 0:
		spawn_remaining -= delta
		if spawn_remaining <= 0.0:
			_spawn_one()
			spawn_remaining = spawn_interval
	elif alive_count == 0:
		waiting_for_next_round = true
		_queue_next_round()

func _begin_round() -> void:
	round_number += 1
	to_spawn = first_round_count + (round_number - 1) * 3
	spawn_remaining = 0.15
	waiting_for_next_round = false
	round_changed.emit(round_number)
	zombie_counts_changed.emit(alive_count, to_spawn)

func _spawn_one() -> void:
	if zombie_scene == null or spawn_points.is_empty():
		return
	var spawn_point := _choose_spawn_point()
	var zombie := zombie_scene.instantiate() as ZombieTownZombie
	if zombie == null:
		return

	zombie.max_health = 105.0 + float(round_number - 1) * 18.0
	zombie.move_speed = minf(3.8, 2.05 + float(round_number - 1) * 0.07)
	zombie.attack_damage = 18.0 + float(round_number - 1) * 0.75
	zombie.died.connect(_on_zombie_died)
	spawn_parent.add_child(zombie)
	zombie.global_position = spawn_point.global_position
	zombie.set_target(player)

	to_spawn -= 1
	alive_count += 1
	zombie_counts_changed.emit(alive_count, to_spawn)

func _choose_spawn_point() -> Node3D:
	var best := spawn_points[0]
	var best_score := -INF
	for point: Node3D in spawn_points:
		var distance := point.global_position.distance_squared_to(player.global_position)
		var jitter := randf_range(0.0, 20.0)
		var score := distance + jitter
		if score > best_score:
			best_score = score
			best = point
	return best

func _on_zombie_died(_zombie: ZombieTownZombie) -> void:
	alive_count = maxi(0, alive_count - 1)
	zombie_counts_changed.emit(alive_count, to_spawn)

func _queue_next_round() -> void:
	await get_tree().create_timer(between_round_delay).timeout
	if not is_inside_tree() or not running or player == null or not player.alive:
		return
	_begin_round()
