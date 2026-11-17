extends RefCounted
## Boss attack presentation shares the model's unchanged special-hit geometry.
const AttackShape = preload("res://scripts/models/enemy_attack_shape_model.gd")
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

static func clear_runtime_caches() -> void:
	_meshes.clear()
	_materials.clear()

static func configure_boss_warning(marker: MeshInstance3D, attack_id: String, radius: float, reduced_flashes: bool) -> void:
	# EnemyAI owns visibility for the complete windup and every cancellation.
	# As its child, the footprint follows the same early tracking/late commitment
	# orientation as the authoritative hit query, without another update loop.
	marker.mesh = _attack_footprint_mesh(attack_id, radius)
	marker.position = Vector3(0.0, 0.055, 0.0)
	marker.material_override = _attack_footprint_material(attack_id, true, false, reduced_flashes)

static func _attack_footprint_mesh(attack_id: String, radius: float) -> ArrayMesh:
	var key := "attack_footprint:%s:%.6f" % [attack_id, radius]
	var cached = _meshes.get(key)
	if cached is ArrayMesh:
		return cached as ArrayMesh
	var vertices := AttackShape.footprint_triangles(attack_id, radius)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.resource_name = key
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = mesh
	return mesh

static func _attack_footprint_material(attack_id: String, warning: bool, parried: bool, reduced_flashes: bool) -> StandardMaterial3D:
	var color: Color = {
		"bell_shockwave": Color(0.92, 0.50, 0.22), "grave_slam": Color(0.70, 0.40, 0.24),
		"ghoulkin_call": Color(0.64, 0.22, 0.16), "root_lanes": Color(0.38, 0.74, 0.28),
		"ground_rupture": Color(0.52, 0.64, 0.26), "heart_stagger": Color(0.36, 0.92, 0.54),
		"wing_blast": Color(0.94, 0.42, 0.18), "ash_breath": Color(0.72, 0.32, 0.20),
		"swoop": Color(0.86, 0.52, 0.20), "parry_test": Color(0.72, 0.82, 1.0),
		"counter_lunge": Color(0.64, 0.74, 0.96), "memory_echo": Color(0.46, 0.86, 0.72),
		"antler_sweep": Color(0.66, 0.92, 0.78), "road_reopening": Color(0.80, 0.88, 0.68),
	}.get(attack_id, Color(0.86, 0.34, 0.18)) as Color
	var key := "attack_footprint:%s:%s:%s:%s" % [attack_id, warning, parried, reduced_flashes]
	var cached = _materials.get(key)
	if cached is StandardMaterial3D:
		return cached as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, 0.24 if warning else 0.36)
	material.emission_enabled = not reduced_flashes
	material.emission = color
	material.emission_energy_multiplier = 0.20 if warning else (0.65 if parried else 0.38)
	material.roughness = 1.0
	_materials[key] = material
	return material

static func create_release(parent: Node3D, pos: Vector3, direction: Vector3, attack_id: String, radius: float, parried: bool, reduced_flashes: bool) -> Node3D:
	if parent == null:
		return null
	var color: Color = {
		"bell_shockwave": Color(0.92, 0.50, 0.22),
		"grave_slam": Color(0.70, 0.40, 0.24),
		"ghoulkin_call": Color(0.64, 0.22, 0.16),
		"root_lanes": Color(0.38, 0.74, 0.28),
		"ground_rupture": Color(0.52, 0.64, 0.26),
		"heart_stagger": Color(0.36, 0.92, 0.54),
		"wing_blast": Color(0.94, 0.42, 0.18),
		"ash_breath": Color(0.72, 0.32, 0.20),
		"swoop": Color(0.86, 0.52, 0.20),
		"parry_test": Color(0.72, 0.82, 1.0),
		"counter_lunge": Color(0.64, 0.74, 0.96),
		"memory_echo": Color(0.46, 0.86, 0.72),
		"antler_sweep": Color(0.66, 0.92, 0.78),
		"road_reopening": Color(0.80, 0.88, 0.68),
	}.get(attack_id, Color(0.86, 0.34, 0.18)) as Color
	var root := Node3D.new()
	root.name = "BossAttackRelease_%s" % attack_id
	root.position = parent.to_local(pos + Vector3(0.0, 0.06, 0.0))
	parent.add_child(root)
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() > 0.01:
		root.look_at(root.global_position + flat_direction.normalized(), Vector3.UP)
	var footprint := MeshInstance3D.new()
	footprint.name = "AttackFootprint"
	footprint.mesh = _attack_footprint_mesh(attack_id, radius)
	footprint.material_override = _attack_footprint_material(attack_id, false, parried, reduced_flashes)
	root.add_child(footprint)
	if attack_id == "ground_rupture":
		for ring_index in range(2):
			var crack := MeshInstance3D.new()
			var crack_mesh := BoxMesh.new()
			crack_mesh.size = Vector3(radius * (0.20 + ring_index * 0.14), 0.035, 0.08)
			crack.mesh = crack_mesh
			crack.position = Vector3(0.0, 0.04, -radius * (0.25 + ring_index * 0.22))
			crack.rotation.y = -0.34 if ring_index == 0 else 0.46
			crack.material_override = _accent_material(color, 0.74, reduced_flashes)
			root.add_child(crack)
	elif attack_id == "heart_stagger":
		var heart := MeshInstance3D.new()
		var heart_mesh := SphereMesh.new()
		heart_mesh.radius = 0.22
		heart_mesh.height = 0.44
		heart.mesh = heart_mesh
		heart.position = Vector3(0.0, 0.34, 0.0)
		heart.material_override = _accent_material(color, 1.25, reduced_flashes)
		root.add_child(heart)
	var tween := root.create_tween()
	if reduced_flashes:
		tween.tween_interval(0.35)
	else:
		# This marks the resolved footprint, not an expanding second damage wave.
		tween.tween_interval(0.20)
	tween.tween_callback(root.queue_free)
	return root

static func _accent_material(color: Color, energy: float, reduced_flashes: bool) -> StandardMaterial3D:
	var key: String = "accent:%s:%.3f:%s" % [color.to_html(false), energy, reduced_flashes]
	if _materials.has(key):
		return _materials[key]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = not reduced_flashes
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.7
	if reduced_flashes:
		var peak: float = maxf(color.r, maxf(color.g, color.b))
		material.albedo_color = color * (minf(peak, 0.5) / maxf(peak, 0.001))
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = material
	return material
