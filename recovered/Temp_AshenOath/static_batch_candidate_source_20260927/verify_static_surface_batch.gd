extends SceneTree

const Candidate = preload("res://tools/static_surface_batch_candidate.gd")
var failures: Array[String] = []

func _initialize() -> void:
	create_timer(10.0).timeout.connect(func(): push_error("Static batch contract timed out"); quit(2))
	call_deferred("_run")

func _run() -> void:
	var zone := Node3D.new()
	root.add_child(zone)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.23, 0.41, 0.18)
	var box := BoxMesh.new()
	box.material = material
	for index in range(3):
		var source := MeshInstance3D.new()
		source.mesh = box
		source.position = Vector3(index * 3, 0, -index)
		source.rotation.y = index * 0.7
		source.scale = Vector3.ONE * (1.0 + 0.2 * index)
		zone.add_child(source)
	var ranged := MeshInstance3D.new()
	ranged.mesh = box
	ranged.visibility_range_end = 32.0
	zone.add_child(ranged)
	var moving := Node3D.new()
	moving.set_meta("motion_type", "wind")
	zone.add_child(moving)
	var moving_mesh := MeshInstance3D.new()
	moving_mesh.mesh = box
	moving.add_child(moving_mesh)
	var bell := MeshInstance3D.new()
	bell.mesh = box
	bell.set_meta("world_prop_kind", "bell")
	zone.add_child(bell)
	var night := MeshInstance3D.new()
	night.name = "LanternGlow"
	night.mesh = box
	zone.add_child(night)
	var lod_mesh := ArrayMesh.new()
	lod_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.surface_get_arrays(0), [], {10.0: PackedInt32Array([0, 1, 2])})
	lod_mesh.surface_set_material(0, material)
	var lod_node := MeshInstance3D.new()
	lod_node.mesh = lod_mesh
	zone.add_child(lod_node)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	zone.add_child(body)
	var collision_id := shape.get_instance_id()
	var candidate = Candidate.new()
	var eligibility: Dictionary = candidate.prepare(zone)
	_check(eligibility.eligible_nodes == 3, "Eligibility must exclude range, motion, world props, night state and embedded LOD")
	_check(eligibility.source_surfaces == 3 and eligibility.batch_surfaces == 1, "Three identical material surfaces must batch into one")
	var result: Dictionary = candidate.build(zone)
	_check(result.equivalence_failures.is_empty(), "Transformed geometry/attributes changed: " + str(result.equivalence_failures))
	_check(shape.get_instance_id() == collision_id and body.get_child_count() == 1, "Collision ownership changed")
	_check(ranged.layers == 1 and moving_mesh.layers == 1 and lod_node.layers == 1 and bell.layers == 1 and night.layers == 1, "Excluded geometry was changed")
	_check(candidate.batch_root.get_child(0).mesh.surface_get_material(0) == material, "Exact material ownership changed")
	candidate.restore()
	_check(zone.get_child(0).layers == 1 and zone.get_child(1).layers == 1 and zone.get_child(2).layers == 1, "Diagnostic restoration failed")
	zone.free()
	print("STATIC SURFACE BATCH CONTRACT: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
