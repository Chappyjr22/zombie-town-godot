class_name ZombieTownExplosionEffect
extends Node3D

const FRAG_SPARKS := 18
const CLAYMORE_SPARKS := 24
const SMOKE_PUFFS := 7

func configure_frag(origin: Vector3) -> void:
	global_position = origin
	_spawn_light(13.0, 9.0)
	_spawn_fireball(Vector3(7.0, 5.5, 7.0), Vector3(0.0, 0.45, 0.0), 0.23)
	_spawn_ground_flash(Vector3(6.5, 0.10, 6.5), 0.24)
	_spawn_frag_sparks()
	_spawn_smoke(false)
	_queue_cleanup(1.25)

func configure_claymore(origin: Vector3, forward: Vector3) -> void:
	global_position = origin
	var planar_forward := Vector3(forward.x, 0.0, forward.z)
	if planar_forward.length_squared() < 0.001:
		planar_forward = Vector3.FORWARD
	look_at(origin + planar_forward.normalized(), Vector3.UP)
	_spawn_light(15.0, 10.0)
	_spawn_fireball(Vector3(4.5, 3.8, 10.5), Vector3(0.0, 0.55, -1.15), 0.20)
	_spawn_ground_flash(Vector3(4.2, 0.08, 8.0), 0.20, Vector3(0.0, 0.04, -1.4))
	_spawn_claymore_sparks()
	_spawn_smoke(true)
	_queue_cleanup(1.20)

func _spawn_light(energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.8, 0.0)
	light.light_color = Color(1.0, 0.34, 0.08, 1.0)
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	add_child(light)
	var tween: Tween = light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.34)

func _spawn_fireball(target_scale: Vector3, offset: Vector3, duration: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.30, 0.035, 0.92)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.16, 0.015, 1.0)
	material.emission_energy_multiplier = 7.5

	var mesh := SphereMesh.new()
	mesh.radius = 0.38
	mesh.height = 0.76
	mesh.radial_segments = 20
	mesh.rings = 10
	mesh.material = material

	var fireball := MeshInstance3D.new()
	fireball.position = offset
	fireball.mesh = mesh
	fireball.scale = Vector3(0.55, 0.55, 0.55)
	fireball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fireball)

	var tween: Tween = fireball.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(fireball, "scale", target_scale, duration)
	tween.tween_property(fireball, "scale", target_scale * 1.12, 0.08)
	tween.tween_callback(fireball.queue_free)

func _spawn_ground_flash(target_scale: Vector3, duration: float, offset: Vector3 = Vector3.ZERO) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.62, 0.14, 0.46)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.34, 0.05, 1.0)
	material.emission_energy_multiplier = 3.5

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.65
	mesh.bottom_radius = 0.65
	mesh.height = 0.05
	mesh.radial_segments = 24
	mesh.material = material

	var flash := MeshInstance3D.new()
	flash.position = offset + Vector3(0.0, 0.07, 0.0)
	flash.mesh = mesh
	flash.scale = Vector3(0.35, 1.0, 0.35)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)

	var tween: Tween = flash.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "scale", target_scale, duration)
	tween.tween_callback(flash.queue_free)

func _spawn_frag_sparks() -> void:
	for index: int in FRAG_SPARKS:
		var angle: float = TAU * float(index) / float(FRAG_SPARKS) + randf_range(-0.16, 0.16)
		var horizontal := Vector3(cos(angle), 0.0, sin(angle))
		var direction: Vector3 = (horizontal + Vector3.UP * randf_range(0.10, 0.58)).normalized()
		_spawn_spark(direction, randf_range(3.0, 6.0), randf_range(0.22, 0.38))

func _spawn_claymore_sparks() -> void:
	for _index: int in CLAYMORE_SPARKS:
		var direction := Vector3(
			randf_range(-0.55, 0.55),
			randf_range(0.02, 0.48),
			randf_range(-1.0, -0.30)
		).normalized()
		_spawn_spark(direction, randf_range(4.0, 8.0), randf_range(0.18, 0.34))

func _spawn_spark(direction: Vector3, distance: float, duration: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.65, 0.10, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.28, 0.025, 1.0)
	material.emission_energy_multiplier = 6.0

	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = material

	var spark := MeshInstance3D.new()
	spark.position = Vector3(0.0, 0.55, 0.0) + direction * 0.35
	spark.mesh = mesh
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spark)

	var target: Vector3 = spark.position + direction * distance + Vector3.DOWN * randf_range(0.15, 0.65)
	var tween: Tween = spark.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(spark, "position", target, duration)
	tween.tween_callback(spark.queue_free)

func _spawn_smoke(directional: bool) -> void:
	var smoke_material := StandardMaterial3D.new()
	smoke_material.albedo_color = Color(0.11, 0.105, 0.095, 0.56)
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.roughness = 1.0

	for _index: int in SMOKE_PUFFS:
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.28, 0.48)
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 12
		mesh.rings = 6
		mesh.material = smoke_material

		var puff := MeshInstance3D.new()
		var side: float = randf_range(-1.0, 1.0)
		var forward_offset: float = randf_range(0.0, 2.8) if directional else randf_range(-1.0, 1.0)
		puff.position = Vector3(side * 0.75, randf_range(0.35, 0.90), -forward_offset)
		puff.mesh = mesh
		puff.scale = Vector3(0.55, 0.55, 0.55)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)

		var drift := Vector3(
			side * randf_range(0.25, 0.70),
			randf_range(1.0, 2.0),
			-randf_range(0.4, 1.8) if directional else randf_range(-0.7, 0.7)
		)
		var target_scale := Vector3.ONE * randf_range(1.8, 3.0)
		var tween: Tween = puff.create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "position", puff.position + drift, 0.85)
		tween.parallel().tween_property(puff, "scale", target_scale, 0.85)

func _queue_cleanup(delay: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(queue_free)
