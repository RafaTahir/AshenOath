class_name CombatVfxCoordinator
extends RefCounted

var _beam_effects: Array[WeakRef] = []

func make_arrow_trail(parent: Node3D, origin: Vector3, endpoint: Vector3, color: Color) -> void:
	var length := origin.distance_to(endpoint)
	if not is_instance_valid(parent) or length <= 0.05:
		return
	var effect := Node3D.new()
	effect.name = "ArrowFlightEffect"
	effect.add_to_group("arrow_runtime_effect")
	parent.add_child(effect)
	effect.global_position = origin.lerp(endpoint, 0.5)
	effect.look_at(endpoint, Vector3.UP)
	var shaft := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.018
	mesh.bottom_radius = 0.022
	mesh.height = length
	mesh.radial_segments = 6
	shaft.mesh = mesh
	shaft.rotation_degrees.x = 90.0
	shaft.material_override = _material(Color(color.r, color.g, color.b, 0.88), 1.1)
	effect.add_child(shaft)
	effect.scale = Vector3(0.12, 0.12, 0.12)
	var tween := effect.create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE, 0.06)
	tween.tween_interval(0.08)
	tween.tween_property(effect, "scale", Vector3(0.08, 0.08, 0.08), 0.12)
	tween.tween_callback(effect.queue_free)

func make_oathfire_beam(parent: Node3D, origin: Vector3, endpoint: Vector3, charge_ratio: float, rich_effect: bool) -> void:
	var length := origin.distance_to(endpoint)
	if not is_instance_valid(parent) or length <= 0.05:
		return
	_prune_effects()
	var effect := Node3D.new()
	effect.name = "OathfireBeamEffect"
	effect.add_to_group("oathfire_runtime_effect")
	parent.add_child(effect)
	_beam_effects.append(weakref(effect))
	effect.global_position = origin.lerp(endpoint, 0.5)
	effect.look_at(endpoint, Vector3.UP)
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.18 + charge_ratio * 0.10
	core_mesh.bottom_radius = 0.30 + charge_ratio * 0.14
	core_mesh.height = length
	core_mesh.radial_segments = 12
	core.mesh = core_mesh
	core.rotation_degrees.x = 90.0
	core.name = "OathfireBeamCore"
	core.material_override = _material(Color(0.72, 0.96, 1.0, 0.96), 2.8)
	effect.add_child(core)
	if rich_effect:
		var aura := MeshInstance3D.new()
		var aura_mesh := CylinderMesh.new()
		aura_mesh.top_radius = 0.42 + charge_ratio * 0.16
		aura_mesh.bottom_radius = 0.58 + charge_ratio * 0.20
		aura_mesh.height = length * 0.98
		aura_mesh.radial_segments = 12
		aura.mesh = aura_mesh
		aura.rotation_degrees.x = 90.0
		aura.name = "OathfireBeamAura"
		aura.material_override = _material(Color(0.16, 0.66, 1.0, 0.30), 1.5)
		effect.add_child(aura)
		var inner := MeshInstance3D.new()
		var inner_mesh := CylinderMesh.new()
		inner_mesh.top_radius = 0.07 + charge_ratio * 0.04
		inner_mesh.bottom_radius = 0.10 + charge_ratio * 0.05
		inner_mesh.height = length * 1.01
		inner_mesh.radial_segments = 10
		inner.mesh = inner_mesh
		inner.rotation_degrees.x = 90.0
		inner.name = "OathfireBeamHotCore"
		inner.material_override = _material(Color(0.94, 1.0, 1.0, 1.0), 4.2)
		effect.add_child(inner)
	effect.scale = Vector3(0.04, 0.04, 0.08)
	# Bind the animation to its effect so zone retirement cancels it as well.
	var tween := effect.create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.16)
	tween.tween_property(effect, "scale", Vector3(0.08, 0.08, 1.0), 0.18)
	tween.tween_callback(effect.queue_free)

func clear_oathfire_effects() -> void:
	for reference in _beam_effects:
		var effect := reference.get_ref() as Node3D
		if is_instance_valid(effect) and not effect.is_queued_for_deletion():
			effect.queue_free()
	_beam_effects.clear()

func active_beam_count() -> int:
	_prune_effects()
	return _beam_effects.size()

func _prune_effects() -> void:
	for index in range(_beam_effects.size() - 1, -1, -1):
		var effect := _beam_effects[index].get_ref() as Node3D
		if not is_instance_valid(effect) or effect.is_queued_for_deletion():
			_beam_effects.remove_at(index)

func _material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = energy
	return material
