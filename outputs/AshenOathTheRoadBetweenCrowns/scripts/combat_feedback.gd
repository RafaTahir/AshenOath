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

static func beam_endpoint(parent: Node3D, pos: Vector3, direction: Vector3, rich: bool = true) -> void:
	if parent == null:
		return
	var root := Node3D.new()
	root.name = "OathfireImpactEndpoint"
	root.set_meta("visual_name", "OathfireImpactEndpoint")
	root.position = parent.to_local(pos)
	parent.add_child(root)
	var flare := MeshInstance3D.new()
	flare.name = "OathfireEndpointFlare"
	var flare_mesh := SphereMesh.new()
	flare_mesh.radius = 0.16 if rich else 0.10
	flare_mesh.height = flare_mesh.radius * 2.0
	flare.mesh = flare_mesh
	flare.material_override = _emissive(Color(0.70, 0.96, 1.0), 2.2)
	root.add_child(flare)
	var ring := MeshInstance3D.new()
	ring.name = "OathfireEndpointRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.15 if rich else 0.10
	ring_mesh.outer_radius = 0.23 if rich else 0.16
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 18
	ring.mesh = ring_mesh
	ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	ring.material_override = _emissive(Color(0.24, 0.74, 1.0), 1.4)
	root.add_child(ring)
	if direction.length_squared() > 0.01:
		root.look_at(root.global_position + direction.normalized(), Vector3.UP)
	var tween := root.create_tween()
	tween.tween_property(root, "scale", Vector3.ONE * (1.65 if rich else 1.30), 0.16)
	tween.tween_callback(root.queue_free)

static func block_flash(parent: Node3D, pos: Vector3, parry: bool, contact_override: Vector3 = Vector3.ZERO) -> void:
	if parent == null:
		return
	var flash = MeshInstance3D.new()
	flash.name = "ParryFlash" if parry else "BlockFlash"
	flash.set_meta("visual_name", flash.name)
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.70 if parry else 0.52, 0.06, 0.08)
	flash.mesh = mesh
	var flash_world_position := contact_override if contact_override.length_squared() > 0.0001 else pos + Vector3(0, 1.1, -0.42)
	flash.position = parent.to_local(flash_world_position)
	flash.rotation_degrees = Vector3(0, 0, 12 if parry else -8)
	flash.material_override = _emissive(Color(0.75, 0.88, 1.0) if parry else Color(0.95, 0.68, 0.24), 1.35 if parry else 0.85)
	parent.add_child(flash)
	var tween = flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * (1.45 if parry else 1.18), 0.11)
	tween.tween_callback(flash.queue_free)

static func weapon_contact(parent: Node3D, base: Vector3, tip: Vector3, point: Vector3, heavy: bool, color: Color = Color(0.96, 0.78, 0.36), previous_base: Vector3 = Vector3.ZERO, previous_tip: Vector3 = Vector3.ZERO) -> void:
	if parent == null:
		return
	var root := Node3D.new()
	root.name = "BladeContactFlash"
	root.set_meta("visual_name", "BladeContactFlash")
	root.position = parent.to_local(point)
	parent.add_child(root)
	var direction := tip - base
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var flash := MeshInstance3D.new()
	flash.name = "BladeContactArc"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.07 if heavy else 0.045, 0.07 if heavy else 0.045, 0.64 if heavy else 0.42)
	flash.mesh = mesh
	flash.material_override = _emissive(color, 1.65 if heavy else 1.15)
	root.add_child(flash)
	flash.look_at(root.global_position + direction, Vector3.UP)
	var has_sweep := previous_tip.length_squared() > 0.0001 and previous_tip.distance_to(tip) > 0.015
	if has_sweep:
		var sweep := MeshInstance3D.new()
		sweep.name = "BladeSweepRibbon"
		var sweep_mesh := ImmediateMesh.new()
		var camera := parent.get_viewport().get_camera_3d()
		var width_axis := Vector3.UP
		if camera != null:
			width_axis = camera.global_transform.basis.x.normalized()
		var width: Vector3 = width_axis * (0.040 if heavy else 0.026)
		var old_base_local := root.to_local(previous_base)
		var old_tip_local := root.to_local(previous_tip)
		var new_base_local := root.to_local(base)
		var new_tip_local := root.to_local(tip)
		sweep_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0, 1.0]:
			var offset: Vector3 = width * side
			sweep_mesh.surface_add_vertex(old_base_local + offset)
			sweep_mesh.surface_add_vertex(old_tip_local + offset)
			sweep_mesh.surface_add_vertex(new_tip_local + offset)
			sweep_mesh.surface_add_vertex(old_base_local + offset)
			sweep_mesh.surface_add_vertex(new_tip_local + offset)
			sweep_mesh.surface_add_vertex(new_base_local + offset)
		sweep_mesh.surface_end()
		sweep.mesh = sweep_mesh
		sweep.material_override = _emissive(color.lightened(0.12), 0.72 if heavy else 0.48)
		root.add_child(sweep)
	var ring := MeshInstance3D.new()
	ring.name = "ContactRing"
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.12 if heavy else 0.08
	ring_mesh.bottom_radius = ring_mesh.top_radius
	ring_mesh.height = 0.025
	ring_mesh.radial_segments = 16
	ring.mesh = ring_mesh
	ring.material_override = _emissive(color.lightened(0.18), 1.2)
	root.add_child(ring)
	var tween := root.create_tween()
	tween.tween_property(root, "scale", Vector3.ONE * (1.42 if heavy else 1.18), 0.12)
	tween.tween_callback(root.queue_free)

static func warning_marker(parent: Node3D, target: Node3D) -> MeshInstance3D:
	if parent == null or target == null:
		return null
	var marker = MeshInstance3D.new()
	marker.name = "EnemyWindupWarning"
	marker.set_meta("visual_name", "EnemyWindupWarning")
	var mesh = PrismMesh.new()
	mesh.size = Vector3(0.26, 0.018, 0.72)
	marker.mesh = mesh
	marker.position = Vector3(0, 0.055, -0.58)
	marker.scale = Vector3(1.0, 1.0, 1.0)
	marker.material_override = _emissive(Color(0.52, 0.07, 0.035), 0.34)
	target.add_child(marker)
	return marker

static func boss_telegraph(parent: Node3D, pos: Vector3, boss_id: String) -> void:
	if parent == null:
		return
	var color: Color = {
		"bell_eater": Color(0.78, 0.36, 0.16),
		"rootbound_colossus": Color(0.38, 0.68, 0.30),
		"ashwing": Color(0.88, 0.30, 0.12),
		"halvern_boss": Color(0.66, 0.74, 0.92),
		"white_hart_avatar": Color(0.62, 0.86, 0.74),
	}.get(boss_id, Color(0.82, 0.24, 0.16)) as Color
	var root := Node3D.new()
	root.name = "BossTelegraph_%s" % boss_id
	root.set_meta("visual_name", "BossTelegraph")
	root.position = parent.to_local(Vector3(pos.x, 0.055, pos.z))
	parent.add_child(root)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.38 if boss_id in ["bell_eater", "rootbound_colossus"] else 0.26
	ring_mesh.outer_radius = 0.46 if boss_id in ["bell_eater", "rootbound_colossus"] else 0.34
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 24
	ring.mesh = ring_mesh
	ring.rotation.x = PI * 0.5
	ring.material_override = _emissive(color, 1.0)
	root.add_child(ring)
	var wedge := MeshInstance3D.new()
	wedge.name = "BossTelegraphWedge"
	var wedge_mesh := PrismMesh.new()
	wedge_mesh.size = Vector3(0.12, 0.025, 1.15 if boss_id == "halvern_boss" else 0.82)
	wedge.mesh = wedge_mesh
	wedge.position = Vector3(0, 0.02, -0.42)
	wedge.material_override = _emissive(color.lightened(0.12), 0.72)
	root.add_child(wedge)
	var tween := root.create_tween()
	tween.tween_property(root, "scale", Vector3.ONE * 1.55, 0.22)
	tween.tween_callback(root.queue_free)

static func boss_attack_release(parent: Node3D, pos: Vector3, direction: Vector3, attack_id: String, radius: float, parried: bool) -> void:
	if parent == null:
		return
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
	root.set_meta("visual_name", "BossAttackRelease")
	root.position = parent.to_local(Vector3(pos.x, 0.06, pos.z))
	parent.add_child(root)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = maxf(0.12, radius * 0.72)
	ring_mesh.outer_radius = maxf(0.18, radius * 0.78)
	ring_mesh.rings = 10
	ring_mesh.ring_segments = 32
	ring.mesh = ring_mesh
	ring.rotation.x = PI * 0.5
	ring.material_override = _emissive(color, 1.1 if not parried else 1.6)
	root.add_child(ring)
	if direction.length_squared() > 0.01 and attack_id in ["ash_breath", "wing_blast", "swoop", "counter_lunge", "antler_sweep"]:
		var wedge := MeshInstance3D.new()
		var wedge_mesh := PrismMesh.new()
		wedge_mesh.size = Vector3(maxf(0.12, radius * 0.24), 0.035, radius * 0.82)
		wedge.mesh = wedge_mesh
		wedge.position = Vector3(0, 0.03, -radius * 0.36)
		wedge.material_override = _emissive(color, 0.90)
		root.add_child(wedge)
		wedge.look_at(wedge.global_position + direction.normalized(), Vector3.UP)
	var tween := root.create_tween()
	tween.tween_property(root, "scale", Vector3.ONE * (1.18 if parried else 1.45), 0.20)
	tween.tween_callback(root.queue_free)

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
