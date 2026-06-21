extends RefCounted

static func impact_burst(parent: Node3D, pos: Vector3, heavy: bool, color: Color = Color(1.0, 0.66, 0.24)) -> void:
	if parent == null:
		return
	var root = Node3D.new()
	root.name = "CombatImpactBurst"
	root.position = parent.to_local(pos)
	parent.add_child(root)
	var count = 7 if heavy else 5
	for i in range(count):
		var shard = MeshInstance3D.new()
		shard.name = "ImpactShard"
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.055, 0.055, 0.30 if heavy else 0.22)
		shard.mesh = mesh
		shard.position = Vector3(randf_range(-0.08, 0.08), randf_range(-0.04, 0.08), randf_range(-0.08, 0.08))
		shard.rotation_degrees = Vector3(randf_range(-35, 35), float(i) * (360.0 / float(count)), randf_range(-45, 45))
		shard.material_override = _emissive(color, 1.15 if heavy else 0.9)
		root.add_child(shard)
	var tween = root.create_tween()
	tween.tween_property(root, "scale", Vector3.ONE * (1.7 if heavy else 1.25), 0.14)
	tween.parallel().tween_property(root, "position:y", root.position.y + 0.12, 0.14)
	tween.tween_callback(root.queue_free)

static func ground_ring(parent: Node3D, pos: Vector3, color: Color, radius: float = 1.0, life: float = 0.22) -> void:
	if parent == null:
		return
	var ring = MeshInstance3D.new()
	ring.name = "CombatGroundRing"
	ring.set_meta("visual_name", "CombatGroundRing")
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 0.018
	mesh.radial_segments = 28
	ring.mesh = mesh
	ring.position = parent.to_local(Vector3(pos.x, 0.052, pos.z))
	ring.scale = Vector3(radius, 0.014, radius)
	ring.material_override = _mat(color, 0.84)
	parent.add_child(ring)
	var tween = ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(radius * 1.6, 0.014, radius * 1.6), life)
	tween.parallel().tween_property(ring, "position:y", ring.position.y + 0.01, life)
	tween.tween_callback(ring.queue_free)

static func block_flash(parent: Node3D, pos: Vector3, parry: bool) -> void:
	if parent == null:
		return
	var flash = MeshInstance3D.new()
	flash.name = "ParryFlash" if parry else "BlockFlash"
	flash.set_meta("visual_name", flash.name)
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.70 if parry else 0.52, 0.06, 0.08)
	flash.mesh = mesh
	flash.position = parent.to_local(pos + Vector3(0, 1.1, -0.42))
	flash.rotation_degrees = Vector3(0, 0, 12 if parry else -8)
	flash.material_override = _emissive(Color(0.75, 0.88, 1.0) if parry else Color(0.95, 0.68, 0.24), 1.35 if parry else 0.85)
	parent.add_child(flash)
	var tween = flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * (1.45 if parry else 1.18), 0.11)
	tween.tween_callback(flash.queue_free)

static func warning_marker(parent: Node3D, target: Node3D) -> MeshInstance3D:
	if parent == null or target == null:
		return null
	var marker = MeshInstance3D.new()
	marker.name = "EnemyWindupWarning"
	marker.set_meta("visual_name", "EnemyWindupWarning")
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 0.020
	mesh.radial_segments = 24
	marker.mesh = mesh
	marker.position = Vector3(0, 0.045, 0)
	marker.scale = Vector3(0.85, 0.012, 0.85)
	marker.material_override = _mat(Color(0.58, 0.09, 0.045), 0.80)
	target.add_child(marker)
	return marker

static func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.7
	return material

static func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
