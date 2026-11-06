extends SceneTree

## Compile only the reviewed, retained stationary satchel. No world is built.
const OUTPUT := "res://assets_external/environment_prepared/living_cast/"

func _initialize() -> void:
	call_deferred("_compile")

func _find(node: Node, target: String) -> Node:
	if str(node.name) == target:
		return node
	for child: Node in node.get_children():
		var found := _find(child, target)
		if found != null:
			return found
	return null

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _compile() -> void:
	var repository := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var folder := repository.path_join("art_source/art_recovery_v2/models/living_cast_20261107/props")
	var source := folder.path_join("rook_station_satchel.glb")
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("satchel_authoring.json")))
	if not receipt is Dictionary or str(receipt.get("carrier_sha256", "")) != FileAccess.get_sha256(source):
		_fail("Station satchel source no longer matches its authored receipt")
		return
	if FileAccess.get_sha256(str(receipt.source)) != str(receipt.source_sha256):
		_fail("Station satchel retained Bag source changed")
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(source, state)
	if error != OK:
		_fail("Cannot import station satchel carrier")
		return
	var imported := document.generate_scene(state)
	var scene := Node3D.new()
	scene.name = "RookStationSatchel"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var resources: Array[Dictionary] = []
	for item: String in ["SatchelBody", "SatchelStrap", "SatchelKnot", "GripLeft", "GripRight"]:
		var original := _find(imported, item) as Node3D
		if original == null:
			_fail("Station satchel lost required attached part: " + item)
			return
		var retained := original.duplicate() as Node3D
		scene.add_child(retained)
		retained.owner = scene
		if retained is MeshInstance3D:
			var mesh_instance := retained as MeshInstance3D
			if not mesh_instance.mesh is ArrayMesh:
				_fail("Station satchel requires prepared ArrayMesh parts: " + item)
				return
			var mesh_path := OUTPUT + "rook_station_" + item.to_snake_case() + ".res"
			error = ResourceSaver.save(mesh_instance.mesh, mesh_path, ResourceSaver.FLAG_COMPRESS)
			if error != OK:
				_fail("Cannot save station satchel mesh: " + item)
				return
			mesh_instance.mesh = load(mesh_path) as ArrayMesh
			resources.append({"path": mesh_path, "sha256": FileAccess.get_sha256(mesh_path)})
	var body := scene.get_node("SatchelBody") as MeshInstance3D
	var bounds := body.transform * body.get_aabb()
	if bounds.position.distance_to(Vector3(-0.09, 0.0, -0.16)) > 0.0001 or bounds.size.distance_to(Vector3(0.18, 0.16, 0.32)) > 0.0001:
		_fail("Station satchel body no longer fits the supported workstation footprint")
		return
	for side: String in ["Left", "Right"]:
		var grip := scene.get_node("Grip" + side) as Node3D
		var expected := Vector3(-0.08, 0.18, -0.10 if side == "Left" else 0.10)
		if grip.position.distance_to(expected) > 0.0001:
			_fail("Station satchel grip marker no longer matches authored strap: " + side)
			return
	scene.set_meta("source_sha256", FileAccess.get_sha256(source))
	scene.set_meta("stationary_supported_prop", true)
	scene.set_meta("hand_height_above_surface", 0.18)
	var packed := PackedScene.new()
	error = packed.pack(scene)
	if error != OK:
		_fail("Cannot pack station satchel")
		return
	var output := OUTPUT + "rook_station_satchel.scn"
	error = ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		_fail("Cannot save station satchel scene")
		return
	var report := {"status": "compiled", "path": output, "sha256": FileAccess.get_sha256(output),
		"source_sha256": FileAccess.get_sha256(source), "resources": resources,
		"body_bounds_verified": true, "attached_grips_verified": true, "runtime_verified": false, "user_accepted": false}
	var report_file := FileAccess.open(folder.path_join("satchel_compile.json"), FileAccess.WRITE)
	if report_file == null:
		_fail("Cannot save satchel compile evidence")
		return
	report_file.store_string(JSON.stringify(report, "\t") + "\n")
	imported.free()
	scene.free()
	print("ROOK_STATION_SATCHEL_COMPILED ", output)
	quit(0)
