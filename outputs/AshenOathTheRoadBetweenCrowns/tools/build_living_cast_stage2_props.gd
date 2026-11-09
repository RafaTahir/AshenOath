extends SceneTree

## Compile reviewed, compact Stage2 props with actual triangle-surface contacts.
const IDENTITIES := ["nessa", "elna", "toma", "nera", "vale", "merrow", "edric"]
const OUTPUT := "res://assets_external/environment_prepared/living_cast/"
var _resources: Array[Dictionary] = []
var _error := ""

func _initialize() -> void:
	call_deferred("_compile")

func _find(node: Node, target: String) -> Node3D:
	if str(node.name) == target:
		return node as Node3D
	for child: Node in node.get_children():
		var result := _find(child, target)
		if result != null:
			return result
	return null

func _meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_meshes(child, result)

func _relative_transform(node: Node3D, base: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != base and parent is Node3D:
		result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result

func _assign_owner(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_assign_owner(child, owner_node)

func _surface_error(scene: Node3D, point: Vector3) -> float:
	var items: Array[MeshInstance3D] = []
	_meshes(scene, items)
	var best := INF
	for item: MeshInstance3D in items:
		var transform := _relative_transform(item, scene)
		var faces := item.mesh.get_faces()
		for index in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(point + Vector3.UP * 0.006, Vector3.DOWN,
				transform * faces[index], transform * faces[index + 1], transform * faces[index + 2])
			if hit is Vector3:
				best = minf(best, point.distance_to(hit as Vector3))
	return best

func _save_meshes(scene: Node3D, identity: String) -> void:
	var meshes: Array[MeshInstance3D] = []
	_meshes(scene, meshes)
	for index in meshes.size():
		var item := meshes[index]
		if not item.mesh is ArrayMesh:
			_error = "Stage2 prop contains an unprepared mesh: " + str(item.name)
			return
		var path := OUTPUT + "station_%s_%02d.res" % [identity, index]
		if ResourceSaver.save(item.mesh, path, ResourceSaver.FLAG_COMPRESS) != OK:
			_error = "Cannot save Stage2 prop mesh: " + path
			return
		item.mesh = load(path) as ArrayMesh
		_resources.append({"path": path, "sha256": FileAccess.get_sha256(path)})

func _validate_contact_shape(part: MeshInstance3D, scene: Node3D, receipt: Dictionary) -> Dictionary:
	var contract: Dictionary = receipt.get("contact_shape", {})
	if str(receipt.contact_response) != "morph":
		return {}
	var shape := part.find_blend_shape_by_name(str(contract.get("name", "")))
	var source_mesh := part.mesh as ArrayMesh
	if source_mesh == null or shape < 0 or str(contract.get("name", "")) != "TaskPress" or float(contract.get("neutral_weight", -1.0)) != 0.0:
		_error = "Stage2 contact morph is absent or has invalid neutral state"
		return {}
	var target_mesh := ArrayMesh.new()
	for surface in source_mesh.get_surface_count():
		var arrays := source_mesh.surface_get_arrays(surface)
		var shapes := source_mesh.surface_get_blend_shape_arrays(surface)
		if shape >= shapes.size():
			_error = "Stage2 contact morph has an unresolved surface"
			return {}
		var base: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var vertices: PackedVector3Array = shapes[shape][Mesh.ARRAY_VERTEX]
		if vertices.size() != base.size():
			_error = "Stage2 contact morph changes vertex topology"
			return {}
		for index in vertices.size():
			if source_mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE:
				vertices[index] += base[index]
			var point := _relative_transform(part, scene) * vertices[index]
			if not point.is_finite() or point.y < -0.001 or point.z > 0.041 or absf(point.x) > 0.55 or point.z < -0.76:
				_error = "Stage2 contact morph escapes the supported table"
				return {}
		arrays[Mesh.ARRAY_VERTEX] = vertices
		target_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var target := MeshInstance3D.new()
	target.mesh = target_mesh
	target.transform = _relative_transform(part, scene)
	var holder := Node3D.new()
	holder.add_child(target)
	var errors: Dictionary = {}
	for label: String in ["GripLeft", "GripRight"]:
		var coordinates: Array = receipt.grips_godot[label]
		var point := Vector3(float(coordinates[0]),float(coordinates[1]),float(coordinates[2]))
		var residual := _surface_error(holder, point)
		if not is_finite(residual) or residual > 0.001:
			_error = "Stage2 contact morph moved its physical grip patch: " + label
			holder.free()
			return {}
		errors[label] = residual
	holder.free()
	part.set_meta("contact_shape", "TaskPress")
	part.set_meta("contact_neutral_weight", 0.0)
	part.set_meta("contact_target_weight", 1.0)
	part.set_blend_shape_value(shape, 0.0)
	return {"name":"TaskPress", "neutral_weight":0.0, "contact_weight":1.0, "target_surface_errors":errors, "support_bounds_verified":true}

func _compile_one(folder: String, identity: String) -> Dictionary:
	var carrier := folder.path_join("station_" + identity + ".glb")
	var receipt_path := folder.path_join("station_" + identity + "_authoring.json")
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
	if not receipt is Dictionary or str(receipt.get("carrier_sha256", "")) != FileAccess.get_sha256(carrier):
		_error = "Missing or stale authored Stage2 prop: " + identity
		return {}
	for source: Dictionary in receipt.sources:
		if FileAccess.get_sha256(str(source.resource)) != str(source.sha256):
			_error = "Retained prop source changed or is absent: " + str(source.resource)
			return {}
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(carrier, state) != OK:
		_error = "Cannot import Stage2 prop: " + identity
		return {}
	var imported := document.generate_scene(state)
	var source_root := _find(imported, "Station_" + identity.capitalize())
	if source_root == null:
		_error = "Stage2 prop root missing: " + identity
		return {}
	var scene := source_root.duplicate() as Node3D
	scene.transform = Transform3D.IDENTITY
	_assign_owner(scene, scene)
	var part := _find(scene, "WorkContactPart")
	if part == null or not part is MeshInstance3D:
		_error = "Actual Stage2 contact part is missing: " + identity
		return {}
	part.set_meta("contact_response", str(receipt.contact_response))
	part.set_meta("contact_amount", clampf(float(receipt.contact_amount), 0.0, 0.08))
	var shape_proof := _validate_contact_shape(part as MeshInstance3D, scene, receipt)
	if not _error.is_empty():
		return {}
	var contact_errors: Dictionary = {}
	for label: String in ["GripLeft", "GripRight"]:
		var grip := _find(scene, label)
		var coordinates: Array = receipt.grips_godot[label]
		var expected := Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
		if grip == null or _relative_transform(grip, scene).origin.distance_to(expected) > 0.0001:
			_error = "Stage2 prop marker no longer matches source: " + identity + "/" + label
			return {}
		var residual := _surface_error(scene, expected)
		if not is_finite(residual) or residual > 0.001:
			_error = "Stage2 grip is not on actual supported material: %s/%s residual=%f" % [identity, label, residual]
			return {}
		contact_errors[label] = residual
	var meshes: Array[MeshInstance3D] = []
	_meshes(scene, meshes)
	for item: MeshInstance3D in meshes:
		var transform := _relative_transform(item, scene)
		for vertex: Vector3 in item.mesh.get_faces():
			var point := transform * vertex
			if not point.is_finite() or point.y < -0.001 or point.z > 0.041 or absf(point.x) > 0.55 or point.z < -0.76:
				_error = "Stage2 work prop overhangs its supported table: " + identity + "/" + str(item.name)
				return {}
	_resources.clear()
	_save_meshes(scene, identity)
	if not _error.is_empty():
		return {}
	scene.set_meta("actor_identity", identity)
	scene.set_meta("source_sha256", FileAccess.get_sha256(carrier))
	scene.set_meta("stationary_supported_prop", true)
	scene.set_meta("surface_height", float(receipt.surface_height))
	scene.set_meta("grip_geometry_verified", true)
	var packed := PackedScene.new()
	if packed.pack(scene) != OK:
		_error = "Cannot pack Stage2 station: " + identity
		return {}
	var path := str(receipt.runtime_resource)
	if path != OUTPUT + "station_" + identity + ".scn" or ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS) != OK:
		_error = "Cannot save Stage2 station: " + identity
		return {}
	var report := {"identity": identity, "path": path, "sha256": FileAccess.get_sha256(path),
		"source_sha256": FileAccess.get_sha256(carrier), "surface_contact_errors": contact_errors,
		"resources": _resources.duplicate(true), "geometry_contact_verified": true,
		"contact_shape":shape_proof,
		"support_bounds_verified": true, "native_grips_verified": false, "user_accepted": false}
	scene.free()
	imported.free()
	return report

func _compile() -> void:
	var repository := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var folder := repository.path_join("art_source/art_recovery_v2/models/living_cast_stage2_20261107/props")
	var selected: Array[String] = []
	var args := OS.get_cmdline_user_args()
	var index := args.find("--identity")
	if index >= 0 and index + 1 < args.size():
		selected.append(args[index + 1])
	else:
		selected.assign(IDENTITIES)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for identity: String in selected:
		if identity not in IDENTITIES:
			push_error("Unknown Stage2 prop identity: " + identity)
			quit(1)
			return
		var report := _compile_one(folder, identity)
		if not _error.is_empty():
			push_error(_error)
			quit(1)
			return
		var file := FileAccess.open(folder.path_join("station_" + identity + "_compile.json"), FileAccess.WRITE)
		if file == null:
			push_error("Cannot write Stage2 prop verification: " + identity)
			quit(1)
			return
		file.store_string(JSON.stringify(report, "\t") + "\n")
		print("STAGE2_STATION_COMPILED ", identity)
	quit(0)
