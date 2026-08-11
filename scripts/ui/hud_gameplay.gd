class_name ZombieTownGameplayHUD
extends ZombieTownHUD

@onready var equipment_label: Label = $Root/EquipmentLabel
@onready var buff_label: Label = $Root/BuffLabel
@onready var powerup_label: Label = $Root/PowerupLabel

var powerup_time := 0.0
var downed_overlay: ColorRect
var downed_label: Label

func _ready() -> void:
	_build_downed_overlay()

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

func set_downed_status(active: bool, bleedout_remaining: float, self_revive_remaining: float) -> void:
	if downed_overlay == null or downed_label == null:
		return
	downed_overlay.visible = active
	downed_label.visible = active
	if not active:
		return
	if self_revive_remaining > 0.0:
		downed_label.text = "DOWNED\nQUICK REVIVE IN %.1fs\nBLEED OUT %.1fs" % [self_revive_remaining, bleedout_remaining]
	else:
		downed_label.text = "DOWNED\nBLEED OUT %.1fs" % bleedout_remaining

func show_revived(method: StringName) -> void:
	if method == &"quick_revive":
		show_powerup("QUICK REVIVE")
	else:
		show_powerup("REVIVED")

func _build_downed_overlay() -> void:
	var root := $Root as Control
	if root == null:
		return
	downed_overlay = ColorRect.new()
	downed_overlay.name = "DownedOverlay"
	downed_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	downed_overlay.color = Color(0.22, 0.0, 0.0, 0.34)
	downed_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	downed_overlay.visible = false
	root.add_child(downed_overlay)

	downed_label = Label.new()
	downed_label.name = "DownedLabel"
	downed_label.set_anchors_preset(Control.PRESET_CENTER)
	downed_label.offset_left = -260.0
	downed_label.offset_top = -90.0
	downed_label.offset_right = 260.0
	downed_label.offset_bottom = 90.0
	downed_label.add_theme_color_override("font_color", Color(0.96, 0.22, 0.16, 1.0))
	downed_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	downed_label.add_theme_constant_override("shadow_offset_x", 3)
	downed_label.add_theme_constant_override("shadow_offset_y", 3)
	downed_label.add_theme_font_size_override("font_size", 30)
	downed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	downed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	downed_label.visible = false
	root.add_child(downed_label)
