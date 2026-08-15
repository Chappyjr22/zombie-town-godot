class_name ZombieTownViewmodelTuner
extends CanvasLayer

const STATE_HIP: StringName = &"hip"
const STATE_ADS: StringName = &"ads"
const STATE_SPRINT: StringName = &"sprint"
const FIELDS: Array[StringName] = [&"x", &"y", &"z", &"pitch", &"yaw", &"roll", &"fov"]
const POSITION_STEPS: Array[float] = [0.001, 0.01, 0.10]
const ROTATION_STEPS: Array[float] = [0.10, 1.0, 5.0]
const FOV_STEPS: Array[float] = [0.10, 1.0, 5.0]

var player: ZombieTownPresentationTunedPlayer
var panel: ColorRect
var readout: Label
var active := false
var tuning_state: StringName = STATE_HIP
var selected_field := 0
var increment_index := 1
var previous_mouse_mode := Input.MOUSE_MODE_CAPTURED
var status_message := ""
var saved_profiles: Dictionary = {}


static func available_in_this_build() -> bool:
	if not OS.is_debug_build():
		return false
	if OS.has_feature("editor"):
		return true
	return "--viewmodel-tuner" in OS.get_cmdline_user_args()


func _ready() -> void:
	layer = 100
	_build_panel()
	set_process_input(true)


func configure(owner_player: ZombieTownPresentationTunedPlayer) -> void:
	player = owner_player
	_refresh_panel()


func is_active() -> bool:
	return active


func _process(_delta: float) -> void:
	if active and (player == null or not player.can_open_viewmodel_tuner()):
		close()


func close() -> void:
	if not active:
		return
	active = false
	panel.visible = false
	Input.mouse_mode = previous_mouse_mode
	if player != null:
		player.on_viewmodel_tuner_closed()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and _is_toggle_key(key_event):
			_toggle()
			get_viewport().set_input_as_handled()
			return
		if not active:
			return
		if key_event.pressed and not key_event.echo:
			_handle_active_key(key_event)
		get_viewport().set_input_as_handled()
		return
	if active and (event is InputEventMouse or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if active:
		close()
		return
	if player == null or not player.can_open_viewmodel_tuner():
		return
	var profile := player.ensure_viewmodel_profile_for_tuning()
	if profile == null:
		status_message = "No tunable profile could be created for this weapon."
		return
	var weapon_key := String(player.weapon.id)
	if not saved_profiles.has(weapon_key):
		saved_profiles[weapon_key] = profile.duplicate(true)
	previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	active = true
	panel.visible = true
	status_message = "Live preview active; gameplay input is paused."
	player.on_viewmodel_tuner_opened()
	_refresh_panel()


func _handle_active_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		close()
		return
	match event.keycode:
		KEY_1:
			_set_state(STATE_HIP)
		KEY_2:
			_set_state(STATE_ADS)
		KEY_3:
			_set_state(STATE_SPRINT)
		KEY_TAB, KEY_DOWN:
			selected_field = (selected_field + 1) % FIELDS.size()
		KEY_UP:
			selected_field = (selected_field - 1 + FIELDS.size()) % FIELDS.size()
		KEY_LEFT:
			_adjust_selected(-1.0, event)
		KEY_RIGHT:
			_adjust_selected(1.0, event)
		KEY_COMMA:
			increment_index = maxi(0, increment_index - 1)
			status_message = "Finer increment selected."
		KEY_PERIOD:
			increment_index = mini(POSITION_STEPS.size() - 1, increment_index + 1)
			status_message = "Coarser increment selected."
		KEY_HOME:
			_reset_current_state()
		KEY_PAGEUP:
			_select_relative_weapon(-1)
		KEY_PAGEDOWN:
			_select_relative_weapon(1)
		KEY_P:
			_copy_configuration(false)
		KEY_C:
			if event.ctrl_pressed:
				_copy_configuration(true)
		KEY_S:
			if event.ctrl_pressed:
				_save_configuration()
	_refresh_panel()


func _set_state(state: StringName) -> void:
	tuning_state = state
	status_message = "%s preview selected." % String(state).to_upper()
	if player != null:
		player.refresh_viewmodel_tuning_preview()
	_refresh_panel()


func _adjust_selected(direction: float, event: InputEventKey) -> void:
	var profile := _profile()
	if profile == null:
		return
	var multiplier := 10.0 if event.shift_pressed else 1.0
	if event.alt_pressed:
		multiplier *= 0.1
	var field := FIELDS[selected_field]
	if field in [&"x", &"y", &"z"]:
		var position := profile.state_position(tuning_state)
		var delta := POSITION_STEPS[increment_index] * multiplier * direction
		match field:
			&"x":
				position.x += delta
			&"y":
				position.y += delta
			&"z":
				position.z += delta
		profile.set_state_position(tuning_state, position)
	elif field in [&"pitch", &"yaw", &"roll"]:
		var rotation := profile.state_rotation_degrees(tuning_state)
		var delta := ROTATION_STEPS[increment_index] * multiplier * direction
		match field:
			&"pitch":
				rotation.x += delta
			&"yaw":
				rotation.y += delta
			&"roll":
				rotation.z += delta
		profile.set_state_rotation_degrees(tuning_state, rotation)
	else:
		var delta := FOV_STEPS[increment_index] * multiplier * direction
		profile.set_state_viewmodel_fov(
			tuning_state,
			profile.state_viewmodel_fov(tuning_state) + delta
		)
	status_message = "Unsaved live adjustment."
	player.refresh_viewmodel_tuning_preview()


func _reset_current_state() -> void:
	var profile := _profile()
	if profile == null or player == null or player.weapon == null:
		return
	var saved_variant: Variant = saved_profiles.get(String(player.weapon.id))
	if not saved_variant is WeaponViewmodelProfile:
		return
	profile.copy_state_from(saved_variant as WeaponViewmodelProfile, tuning_state)
	status_message = "%s reset to saved/default values." % String(tuning_state).to_upper()
	player.refresh_viewmodel_tuning_preview()


func _copy_configuration(copy_to_clipboard: bool) -> void:
	var profile := _profile()
	if profile == null or player == null or player.weapon == null:
		return
	var text := "# %s (%s)\n%s" % [
		player.weapon.display_name,
		String(player.weapon.id),
		profile.reusable_configuration_text()
	]
	print("\nVIEWMODEL CONFIGURATION\n%s\n" % text)
	if copy_to_clipboard:
		DisplayServer.clipboard_set(text)
		status_message = "Configuration copied to clipboard and printed."
	else:
		status_message = "Configuration printed to the debug console."


func _save_configuration() -> void:
	var profile := _profile()
	if profile == null or player == null or player.weapon == null:
		return
	var result := player.save_active_viewmodel_profile()
	if result == OK:
		saved_profiles[String(player.weapon.id)] = profile.duplicate(true)
		status_message = "Saved: %s" % player.active_viewmodel_profile_path
	else:
		status_message = "Save failed with error %d." % result


func _select_relative_weapon(direction: int) -> void:
	if player == null or player.weapon == null:
		return
	var weapon_ids := ZombieTownWeaponCatalog.developer_weapon_ids()
	if weapon_ids.is_empty():
		return
	var current_index := weapon_ids.find(player.weapon.id)
	if current_index < 0:
		current_index = 0
	var step := 1 if direction >= 0 else -1
	var next_index := (current_index + step + weapon_ids.size()) % weapon_ids.size()
	var next_weapon := ZombieTownWeaponCatalog.load_developer_weapon(weapon_ids[next_index])
	if next_weapon == null or not player.equip_weapon(next_weapon):
		status_message = "Could not equip developer-selected weapon."
		return
	var profile := player.ensure_viewmodel_profile_for_tuning()
	if profile == null:
		status_message = "Weapon equipped, but no tunable profile is available."
		return
	var weapon_key := String(player.weapon.id)
	if not saved_profiles.has(weapon_key):
		saved_profiles[weapon_key] = profile.duplicate(true)
	tuning_state = STATE_HIP
	status_message = "Selected %s. Save with Ctrl+S before changing weapons." % player.weapon.display_name
	player.refresh_viewmodel_tuning_preview()


func _profile() -> WeaponViewmodelProfile:
	if player == null:
		return null
	return player.active_viewmodel_profile


func _build_panel() -> void:
	panel = ColorRect.new()
	panel.name = "ViewmodelTunerPanel"
	panel.position = Vector2(16.0, 16.0)
	panel.size = Vector2(520.0, 525.0)
	panel.color = Color(0.025, 0.03, 0.04, 0.92)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	add_child(panel)

	readout = Label.new()
	readout.name = "Readout"
	readout.position = Vector2(16.0, 14.0)
	readout.size = Vector2(490.0, 495.0)
	readout.add_theme_font_size_override("font_size", 16)
	readout.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	readout.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	readout.add_theme_constant_override("shadow_offset_x", 1)
	readout.add_theme_constant_override("shadow_offset_y", 1)
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(readout)


func _refresh_panel() -> void:
	if readout == null:
		return
	var profile := _profile()
	var weapon_name := "NONE"
	var weapon_id := "none"
	var position := Vector3.ZERO
	var rotation := Vector3.ZERO
	var fov := 0.0
	var sight_mode := ""
	if player != null and player.weapon != null:
		weapon_name = player.weapon.display_name
		weapon_id = String(player.weapon.id)
	if profile != null:
		position = profile.state_position(tuning_state)
		rotation = profile.state_rotation_degrees(tuning_state)
		fov = profile.state_viewmodel_fov(tuning_state)
		if tuning_state == STATE_ADS and profile.align_ads_to_sight:
			sight_mode = "  [AUTO SIGHT CENTER]"
	var lines: Array[String] = [
		"VIEWMODEL TUNER  [DEVELOPER ONLY]",
		"Weapon: %s  (%s)" % [weapon_name, weapon_id],
		"State:  %s%s" % [String(tuning_state).to_upper(), sight_mode],
		"",
		_field_line(0, "X", position.x),
		_field_line(1, "Y", position.y),
		_field_line(2, "Z", position.z),
		_field_line(3, "PITCH", rotation.x),
		_field_line(4, "YAW", rotation.y),
		_field_line(5, "ROLL", rotation.z),
		_field_line(6, "VIEWMODEL FOV", fov),
		"",
		"Increment: %s  position %.4f m / rotation %.2f deg / FOV %.2f" % [
			_increment_name(),
			POSITION_STEPS[increment_index],
			ROTATION_STEPS[increment_index],
			FOV_STEPS[increment_index]
		],
		"",
		"1 HIP   2 ADS   3 SPRINT   ` CLOSE",
		"PAGE UP/DOWN     Previous / next weapon",
		"UP/DOWN or TAB  Select field",
		"LEFT/RIGHT       Adjust selected field",
		"SHIFT x10   ALT x0.1   , finer   . coarser",
		"HOME Reset state   Ctrl+C Copy   P Print",
		"Ctrl+S Save per-weapon profile",
		"",
		status_message
	]
	readout.text = "\n".join(lines)


func _field_line(index: int, label: String, value: float) -> String:
	var marker := ">" if selected_field == index else " "
	return "%s %s %s" % [marker, label.rpad(14), String.num(value, 6)]


func _increment_name() -> String:
	match increment_index:
		0:
			return "FINE"
		2:
			return "COARSE"
		_:
			return "NORMAL"


func _is_toggle_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_QUOTELEFT or event.physical_keycode == KEY_QUOTELEFT
