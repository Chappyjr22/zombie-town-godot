class_name ZombieTownGameplayHUD
extends ZombieTownHUD

@onready var equipment_label: Label = $Root/EquipmentLabel
@onready var buff_label: Label = $Root/BuffLabel
@onready var powerup_label: Label = $Root/PowerupLabel

var powerup_time := 0.0

func _process(delta: float) -> void:
	super._process(delta)
	if powerup_time <= 0.0:
		return
	powerup_time -= delta
	powerup_label.modulate.a = clampf(powerup_time * 2.5, 0.0, 1.0)
	if powerup_time <= 0.0:
		powerup_label.visible = false

func set_equipment(text: String) -> void:
	equipment_label.text = text

func set_buffs(text: String) -> void:
	buff_label.visible = not text.is_empty()
	buff_label.text = text

func show_powerup(text: String) -> void:
	powerup_label.visible = true
	powerup_label.text = text
	powerup_label.modulate.a = 1.0
	powerup_time = 1.8
