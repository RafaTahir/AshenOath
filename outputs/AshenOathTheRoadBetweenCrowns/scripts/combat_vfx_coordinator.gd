class_name CombatVfxCoordinator
extends RefCounted

var _beam_effects: Array[WeakRef] = []
var _contact_effects: Array[WeakRef] = []

func surface_contact(parent: Node3D, result: Dictionary, blood: bool, reduce_flashes: bool) -> void:
	var surface := str(result.get("surface", "stone"))
	if surface == "spirit" or surface == "flesh" and not blood: return
	var free_effect: Node3D
	var live: Array[WeakRef] = []
	for ref: WeakRef in _contact_effects:
		var effect := ref.get_ref() as Node3D
		if not is_instance_valid(effect) or effect.get_parent() != parent: continue
		live.append(ref)
		if not effect.visible: free_effect = effect
	_contact_effects = live
	if free_effect == null:
		if live.size() >= 3: return
		free_effect = preload("res://scripts/impact_particles.gd").new()
		free_effect.name = "SurfaceContactBurst"
		parent.add_child(free_effect)
		_contact_effects.append(weakref(free_effect))
	var direction: Vector3 = result.get("direction",Vector3.FORWARD)
	free_effect.restart(result.get("point",Vector3.ZERO),result.get("normal",-direction),direction,surface,reduce_flashes)

func launch_arrow(parent: Node3D, origin: Vector3, direction: Vector3, distance: float, enemies: Array, combat: Node, excluded: Array[RID], shot: Dictionary, completed: Callable) -> void:
	var arrow := preload("res://scripts/arrow_projectile.gd").new()
	arrow.name = "ArrowInFlight"
	arrow.direction = direction.normalized()
	arrow.remaining = distance
	arrow.combat = weakref(combat)
	arrow.excluded = excluded
	arrow.shot = shot
	arrow.completed = completed
	for actor in enemies:
		if is_instance_valid(actor): arrow.enemies.append(weakref(actor))
	parent.add_child(arrow)
	arrow.global_position = origin
	arrow.look_at(origin + direction, Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP)
	_add_arrow_mesh(arrow)

func _add_arrow_mesh(parent: Node3D) -> void:
	var model: PackedScene = load("res://assets_external/characters/Ranger_Arrow.fbx")
	if model == null: return
	var visual := model.instantiate() as Node3D
	preload("res://scripts/arrow_visual.gd").attach(parent, visual, true)
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func make_arrow_trail(parent: Node3D, origin: Vector3, endpoint: Vector3, _color: Color) -> void:
	var length := origin.distance_to(endpoint)
	if not is_instance_valid(parent) or length <= 0.05:
		return
	var effect := Node3D.new()
	effect.name = "ArrowFlightEffect"
	effect.add_to_group("arrow_runtime_effect")
	parent.add_child(effect)
	effect.global_position = origin
	effect.look_at(endpoint, Vector3.RIGHT if absf((endpoint-origin).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP)
	_add_arrow_mesh(effect)
	var tween := effect.create_tween()
	tween.tween_property(effect, "global_position", endpoint, length / 48.0)
	tween.tween_callback(effect.queue_free)

func make_oathfire_beam(parent: Node3D, origin: Vector3, endpoint: Vector3, charge_ratio: float, rich_effect: bool, reduce_flashes: bool = false) -> void:
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
	var beam_material := _material(Color(0.18, 0.42, 0.50, 0.0), 0.0) if reduce_flashes else _material(Color(0.72, 0.96, 1.0, 0.96), 2.8)
	core.material_override = beam_material
	effect.add_child(core)
	if rich_effect and not reduce_flashes:
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
	if reduce_flashes:
		# A steady coloured volume communicates the same cast direction/range.
		# It does not expand from a bright flash or contain a white-hot core.
		effect.scale = Vector3.ONE
		var steady_tween := effect.create_tween()
		steady_tween.tween_property(beam_material, "albedo_color:a", 0.70, 0.14)
		steady_tween.tween_interval(0.16)
		steady_tween.tween_property(beam_material, "albedo_color:a", 0.0, 0.24)
		steady_tween.tween_callback(effect.queue_free)
		return
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
	material.emission_enabled = energy > 0.0
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = energy
	return material
