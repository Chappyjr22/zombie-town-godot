class_name ZombieTownHUD
extends CanvasLayer

@onready var health_bar: ProgressBar = $Root/HealthBar
@onready var health_label: Label = $Root/HealthLabel
@onready var weapon_label: Label = $Root/WeaponLabel
@onready var slot_label: Label = $Root/SlotLabel
@onready var ammo_label: Label = $Root/AmmoLabel
@onready var reload_label: Label = $Root/ReloadLabel
@onready var points_label: Label = $Root/PointsLabel
@onready var round_label: Label = $Root/RoundLabel
@onready var count_label: Label = $Root/CountLabel
@onready var stats_label: Label = $Root/StatsLabel
@onready var hit_marker: Label = $Root/HitMarker
@onready var interaction_prompt: Label = $Root/InteractionPrompt
@onready var game_over: Label = $Root/GameOver

var hit_marker_time := 0.0

func _process(delta: float) -> void:
	if hit_marker_time <= 0.0:
		return
	hit_marker_time -= delta
	hit_marker.modulate.a = clampf(hit_marker_time * 7.0, 0.0, 1.0)
	if hit_marker_time <= 0.0:
		hit_marker.visible = false

func set_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]

func set_weapon(display_name: String, _weapon_id: StringName = &"") -> void:
	weapon_label.text = display_name.to_upper()

func set_weapon_slots(summary: String) -> void:
	slot_label.text = summary

func set_ammo(current: int, reserve: int, reloading: bool) -> void:
	ammo_label.text = "%02d / %03d" % [current, reserve]
	reload_label.visible = reloading
	reload_label.text = "RELOADING"

func set_stats(points: int, kills: int, headshots: int) -> void:
	points_label.text = "%d PTS" % points
	stats_label.text = "%d KILLS   %d HEADSHOTS" % [kills, headshots]

func set_round(round_number: int) -> void:
	round_label.text = "ROUND %02d" % round_number

func set_zombie_counts(alive: int, remaining_to_spawn: int) -> void:
	count_label.text = "%d ACTIVE   %d INCOMING" % [alive, remaining_to_spawn]

func set_interaction_prompt(text: String, affordable: bool) -> void:
	interaction_prompt.visible = not text.is_empty()
	interaction_prompt.text = text
	interaction_prompt.add_theme_color_override("font_color", Color(0.92, 0.72, 0.26, 1.0) if affordable else Color(0.88, 0.22, 0.16, 1.0))

func show_hit(killed: bool, headshot: bool) -> void:
	hit_marker.visible = true
	hit_marker.text = "X" if not killed else "+"
	hit_marker.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2) if headshot else Color(0.95, 0.92, 0.8))
	hit_marker.modulate.a = 1.0
	hit_marker_time = 0.16 if not killed else 0.24

func show_game_over(round_number: int, kills: int) -> void:
	game_over.text = "YOU DIED\nROUND %02d   %d KILLS\n\nPress Enter to restart" % [round_number, kills]
	game_over.visible = true
